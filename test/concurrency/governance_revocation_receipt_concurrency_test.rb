# frozen_string_literal: true

require "test_helper"
require "timeout"

class GovernanceRevocationReceiptConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_token_binding_methods client_token_dbsc_statuses client_token_kinds client_token_statuses
    operator_token_binding_methods operator_token_dbsc_statuses operator_token_kinds operator_token_statuses
  )

  setup do
    @command_ids = []
    @principals = []
  end

  teardown do
    # Cleanup is limited to this test's isolated, generated command UUIDs.
    OpAppGovernanceRevocationReceipt.where(command_id: @command_ids).delete_all
    OpOrgGovernanceRevocationReceipt.where(command_id: @command_ids).delete_all
    # Other rows are selected exclusively through this test's fresh principal IDs.
    ["app", "org"].each do |realm|
      config = OpAuthorityStopCommitter::REALMS.fetch(realm)
      stop_ids = config.fetch(:stop).where(principal_public_id: @principals).pluck(:id)
      %i(participant epoch_cutoff grant_target root_target).each do |child|
        config.fetch(child).where(stop_id: stop_ids).delete_all
      end
      config.fetch(:stop).where(id: stop_ids).delete_all
      device_ids = config.fetch(:device).where(principal_public_id: @principals).pluck(:id)
      config.fetch(:device).where(id: device_ids).update_all(current_refresh_token_id: nil)
      config.fetch(:grant).where(device_session_id: device_ids).delete_all
      config.fetch(:root).where(device_session_id: device_ids).delete_all
      config.fetch(:device).where(id: device_ids).delete_all
    end
  end

  test "refresh waiting on a command's device lock cannot rotate after the authority stop commits" do
    [
      ["app", "client", ClientDeviceSession, ClientToken, OpAppGrant, :subject_public_id, :client_token_id, "core-app-jp"],
      ["org", "operator", OperatorDeviceSession, OperatorToken, OpOrgGrant, :subject_public_id, :operator_token_id,
       "core-org-jp",],
    ].each do |realm, resource_type, device_class, root_class, grant_class, actor_key, root_key, client_id|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      principal = PublicId.generate
      @principals << principal
      device_id = device_class.insert_all!(
        [{ :public_id => PublicId.generate,
           :subject_public_id => principal,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      root_id = root_class.insert_all!(
        [{ actor_key => 9_500_001,
           kind_key => kind_id,
           :public_id => PublicId.generate,
           :device_session_id => device_id,
           :authentication_epoch => 0,
           :discard_at => 2.days.from_now,
           :last_used_at => Time.current,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      device_class.where(id: device_id).update_all(current_refresh_token_id: root_id)
      grant_id = grant_class.insert_all!(
        [{ root_key => root_id,
           :subject_public_id => principal,
           :device_session_id => device_id,
           :public_id => PublicId.generate,
           :authentication_epoch => 0,
           :oidc_client_id => client_id,
           :oidc_scope => "openid",
           :oidc_jti => SecureRandom.uuid,
           :refresh_token_expires_at => 1.day.from_now,
           :last_used_at => Time.current,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      grant = grant_class.find(grant_id)
      refresh_token = grant.issue_refresh_token!
      original_digest = grant.reload.refresh_token_digest
      prefix = (realm == "app") ? "cli" : "opr"
      command_id = SecureRandom.uuid
      @command_ids << command_id
      payload = {
        "iss" => "https://governance.example",
        "aud" => "https://visa.example",
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => command_id,
        "realm" => realm,
        "sub" => "#{prefix}_#{principal}",
        "scope" => "all_sessions",
        "actor" => "opr_operator",
        "reason" => "account_disabled",
      }
      command = GovernanceRevocationCommandValue.new(
        payload:, realm:, issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.current,
      )
      locked = Queue.new
      release = Queue.new
      seen = false
      mutex = Mutex.new
      subscriber =
        ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          sql = event.payload.fetch(:sql)
          next unless sql.start_with?("SELECT") && sql.include?("FROM \"#{device_class.table_name}\"") &&
            sql.include?("FOR UPDATE")

          first_lock =
            mutex.synchronize do
              next false if seen

              seen = true
            end
          next unless first_lock

          locked << true
          release.pop
        end
      revoker =
        Thread.new {
          device_class.connection_pool.with_connection {
            GovernanceRevocationCommand.call(command:)
          }
        }
      Timeout.timeout(10) { locked.pop }
      refresher =
        Thread.new do
          grant_class.connection_pool.with_connection do
            OidcRefreshTokenIssuer.call(refresh_token:, client_id:, resource_type:)
          end
        end
      Timeout.timeout(10) do
        loop do
          waiting =
            device_class.uncached do
              device_class.lease_connection.select_value(<<~SQL.squish)
                SELECT EXISTS (
                  SELECT 1 FROM pg_stat_activity
                  WHERE datname = current_database() AND wait_event_type = 'Lock'
                    AND query LIKE '%#{device_class.table_name}%' AND pid <> pg_backend_pid()
                )
              SQL
            end
          break if waiting

          sleep 0.01
        end
      end
      release << true
      receipt, refresh = Timeout.timeout(10) { [revoker.value, refresher.value] }

      assert_equal command_id, receipt.command_id
      assert_not_predicate refresh, :success?
      assert_equal :inactive_token, refresh.reason
      assert_equal original_digest, grant.reload.refresh_token_digest
      assert_not_nil grant.revoked_at
      assert_predicate root_class.find(root_id), :revoked?
      assert_predicate device_class.find(device_id), :revoked?
    ensure
      release << true if release
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      [revoker, refresher].compact.each do |thread|
        thread.join(10)
        next unless thread.alive?

        thread.kill
        thread.join
      end
    end
  end

  test "browser root rotation and Governance stop serialize in either order on the stable device" do
    [
      ["app", "client", ClientDeviceSession, ClientToken, OpAppGrant, :subject_public_id, :client_token_id, "core-app-jp"],
      ["org", "operator", OperatorDeviceSession, OperatorToken, OpOrgGrant, :subject_public_id, :operator_token_id,
       "core-org-jp",],
    ].each do |realm, resource_type, devices, roots, grants, actor_key, root_key, client_id|
      %i(rotation command).each do |first_action|
        principal = PublicId.generate
        @principals << principal
        device = devices.create!(:subject_public_id => principal)
        root = roots.create!(
          :subject_public_id => device.subject_public_id, :device_session => device, :authentication_epoch => 0,
          :discard_at => 2.days.from_now,
        )
        grant = grants.create!(
          root_key => root.id, :device_session_id => device.id, :authentication_epoch => 0,
          :oidc_client_id => client_id, :refresh_token_expires_at => 1.day.from_now,
        )
        refresh_token = root.rotate_refresh_token!
        initial_root_count = roots.where(device_session_id: device.id).count
        command_id = SecureRandom.uuid
        @command_ids << command_id
        prefix = (realm == "app") ? "cli" : "opr"
        payload = {
          "iss" => "https://governance.example",
          "aud" => "https://visa.example",
          "iat" => Time.current.to_i,
          "exp" => 60.seconds.from_now.to_i,
          "jti" => command_id,
          "realm" => realm,
          "sub" => "#{prefix}_#{principal}",
          "scope" => "all_sessions",
          "actor" => "opr_operator",
          "reason" => "account_disabled",
        }
        signing_key = OpenSSL::PKey::EC.generate("secp384r1")
        jwk = JSON.parse(
          JSON.generate(
            JWT::JWK.new(signing_key, "governance-race").export.merge(
              alg: "ES384",
              use: "sig",
            ),
          ),
        )
        signed_command = JWT.encode(
          payload, signing_key, "ES384", { kid: "governance-race", typ: "governance-revocation+jwt" },
        )
        verifier = GovernanceRevocationCommandVerifier.new(
          issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm:,
          jwks_url: "https://governance.example/keys", fetcher: -> { { "keys" => [jwk] } }, now: Time.current,
        )
        locked = Queue.new
        release = Queue.new
        seen = false
        mutex = Mutex.new
        subscriber =
          ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
            sql = event.payload.fetch(:sql)
            next unless sql.start_with?("SELECT") && sql.include?("FROM \"#{devices.table_name}\"") &&
              sql.include?("FOR UPDATE")

            first_lock =
              mutex.synchronize do
                next false if seen

                seen = true
              end
            next unless first_lock

            locked << true
            release.pop
          end
        actions = {
          rotation: -> { AuthRefreshTokenIssuer.call(refresh_token:, resource_type:) },
          command: -> { GovernanceRevocationCommand.call(command: verifier.verify(signed_command)) },
        }
        first = Thread.new { devices.connection_pool.with_connection { actions.fetch(first_action).call } }
        Timeout.timeout(10) { locked.pop }
        second_action = (first_action == :rotation) ? :command : :rotation
        second = Thread.new { devices.connection_pool.with_connection { actions.fetch(second_action).call } }
        Timeout.timeout(10) do
          loop do
            waiting =
              devices.uncached do
                devices.lease_connection.select_value(<<~SQL.squish)
                  SELECT EXISTS (
                    SELECT 1 FROM pg_stat_activity
                    WHERE datname = current_database() AND wait_event_type = 'Lock'
                      AND query LIKE '%#{devices.table_name}%' AND pid <> pg_backend_pid()
                  )
                SQL
              end
            break if waiting

            Thread.pass
          end
        end
        release << true
        results = Timeout.timeout(10) { { first_action => first.value, second_action => second.value } }
        rotation = results.fetch(:rotation)
        receipt = results.fetch(:command)

        assert_equal command_id, receipt.command_id
        assert_predicate device.reload, :revoked?
        assert_predicate grant.reload, :revoked?
        assert roots.where(device_session_id: device.id).all?(&:revoked?)
        if first_action == :rotation
          assert_predicate rotation, :success?
          assert_not_equal root.id, rotation.token.id
          assert_predicate rotation.token.reload, :revoked?
          assert_equal initial_root_count + 1, roots.where(device_session_id: device.id).count
        else
          assert_not_predicate rotation, :success?
          assert_equal :inactive_token, rotation.reason
          assert_equal initial_root_count, roots.where(device_session_id: device.id).count
          assert_nil root.reload.rotated_at
        end
      ensure
        release << true if release
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
        [first, second].compact.each do |thread|
          thread.join(10)
          next unless thread.alive?

          thread.kill
          thread.join
        end
      end
    end
  end

  test "browser refresh refuses a root reparented while it waits for its initially selected device" do
    [
      ["client", ClientDeviceSession, ClientToken, :subject_public_id],
      ["operator", OperatorDeviceSession, OperatorToken, :subject_public_id],
    ].each do |resource_type, devices, roots, actor_key|
      principal = PublicId.generate
      @principals << principal
      original_device = devices.create!(:subject_public_id => principal)
      replacement_device = devices.create!(:subject_public_id => principal)
      root = roots.create!(
        :subject_public_id => original_device.subject_public_id, :device_session => original_device, :authentication_epoch => 0,
        :discard_at => 2.days.from_now,
      )
      refresh_token = root.rotate_refresh_token!
      read = Queue.new
      seen = false
      mutex = Mutex.new
      subscriber =
        ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          sql = event.payload.fetch(:sql)
          next unless sql.start_with?("SELECT") && sql.include?("FROM \"#{roots.table_name}\"") &&
            sql.exclude?("FOR UPDATE")

          first_read =
            mutex.synchronize do
              next false if seen

              seen = true
            end
          read << true if first_read
        end
      refresher = nil
      devices.transaction do
        devices.lock.find(original_device.id)
        refresher =
          Thread.new do
            devices.connection_pool.with_connection do
              begin
                AuthRefreshTokenIssuer.call(refresh_token:, resource_type:)
              rescue FlowConfigurationError => e
                e
              end
            end
          end
        Timeout.timeout(10) { read.pop }
        Timeout.timeout(10) do
          loop do
            waiting =
              devices.uncached do
                devices.lease_connection.select_value(<<~SQL.squish)
                  SELECT EXISTS (
                    SELECT 1 FROM pg_stat_activity
                    WHERE datname = current_database() AND wait_event_type = 'Lock'
                      AND query LIKE '%#{devices.table_name}%' AND pid <> pg_backend_pid()
                  )
                SQL
              end
            break if waiting

            Thread.pass
          end
        end
        original_device.reload.update!(current_refresh_token_id: nil)
        roots.where(id: root.id).update_all(device_session_id: replacement_device.id)
        replacement_device.update!(current_refresh_token_id: root.id)
      end
      result = Timeout.timeout(10) { refresher.value }

      # Comparing only class names keeps an unexpected successful result from printing raw credentials.
      assert_equal "FlowConfigurationError", result.class.name
      assert_equal "browser refresh root device changed", result.message
      assert_nil root.reload.rotated_at
      assert_equal root.id, replacement_device.reload.current_refresh_token_id
      assert_nil original_device.reload.current_refresh_token_id
      assert_equal 1, roots.where(device_session_id: replacement_device.id).count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      if refresher
        refresher.join(10)
        if refresher.alive?
          refresher.kill
          refresher.join
        end
      end
    end
  end

  test "concurrent copies wait for the first receipt transaction and observe one committed command" do
    [
      ["app", OpAppGovernanceRevocationReceipt],
      ["org", OpOrgGovernanceRevocationReceipt],
    ].each do |realm, receipt_class|
      prefix = (realm == "app") ? "cli" : "opr"
      command_id = SecureRandom.uuid
      @command_ids << command_id
      payload = {
        "iss" => "https://governance.example",
        "aud" => "https://visa.example",
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => command_id,
        "realm" => realm,
        "sub" => "#{prefix}_#{PublicId.generate}",
        "scope" => "all_sessions",
        "actor" => "opr_operator",
        "reason" => "account_disabled",
      }
      command = GovernanceRevocationCommandValue.new(
        payload:, realm:, issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.current,
      )
      inserted = Queue.new
      release = Queue.new
      seen = false
      mutex = Mutex.new
      subscriber =
        ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          next unless event.payload.fetch(:sql).start_with?("INSERT INTO \"#{receipt_class.table_name}\"")

          first_insert =
            mutex.synchronize do
              next false if seen

              seen = true
            end
          next unless first_insert

          inserted << true
          release.pop
        end
      first =
        Thread.new {
          receipt_class.connection_pool.with_connection {
            GovernanceRevocationCommand.call(command:)
          }
        }
      Timeout.timeout(10) { inserted.pop }
      second =
        Thread.new {
          receipt_class.connection_pool.with_connection {
            GovernanceRevocationCommand.call(command:)
          }
        }
      waited =
        Timeout.timeout(10) do
          loop do
            blocked =
              receipt_class.uncached do
                receipt_class.lease_connection.select_value(<<~SQL.squish)
                  SELECT EXISTS (
                    SELECT 1 FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND query LIKE '%#{receipt_class.table_name}%'
                      AND pid <> pg_backend_pid()
                  )
                SQL
              end
            break true if blocked

            sleep 0.01
          end
        end

      assert waited
      release << true
      receipts = Timeout.timeout(10) { [first.value, second.value] }

      assert_equal [command_id], receipts.map(&:command_id).uniq
      assert_equal 1, receipts.map(&:committed_at).uniq.size
      assert_equal 1, receipt_class.where(command_id:).count
    ensure
      release << true if release
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      [first, second].compact.each do |thread|
        thread.join(10)
        next unless thread.alive?

        thread.kill
        thread.join
      end
    end
  end
end
