# frozen_string_literal: true

require "test_helper"

class GovernanceRevocationCommandTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a historical grant whose original root was purged is revoked through its stable device parent" do
    [
      ["app", ClientDeviceSession, ClientToken, OpAppGrant, :subject_public_id, :client_token_id, "core-app-jp"],
      ["org", OperatorDeviceSession, OperatorToken, OpOrgGrant, :subject_public_id, :operator_token_id, "core-org-jp"],
    ].each do |realm, device_class, root_class, grant_class, actor_key, root_key, client_id|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      principal = PublicId.generate
      device_id = device_class.insert_all!(
        [{ :public_id => PublicId.generate,
           :subject_public_id => principal,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      historical_root_id = root_class.insert_all!(
        [{ actor_key => 9_600_001,
           kind_key => kind_id,
           :public_id => PublicId.generate,
           :device_session_id => device_id,
           :authentication_epoch => 0,
           :discard_at => 2.days.from_now,
           :last_used_at => Time.current,
           :rotated_at => Time.current,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      root_id = root_class.insert_all!(
        [{ actor_key => 9_600_001,
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
        [{ root_key => historical_root_id,
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
      # D3 permits this physical deletion of the old rotating token, retaining its grant.
      root_class.where(id: historical_root_id).delete_all

      assert_not root_class.exists?(id: historical_root_id)
      assert_predicate grant_class.find(grant_id), :active?
      persisted_grant = grant_class.find(grant_id)
      persisted_grant.valid?

      assert_empty persisted_grant.errors.details

      prefix = (realm == "app") ? "cli" : "opr"
      payload = {
        "iss" => "https://governance.example",
        "aud" => "https://visa.example",
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => SecureRandom.uuid,
        "realm" => realm,
        "sub" => "#{prefix}_#{principal}",
        "scope" => "all_sessions",
        "actor" => "opr_operator",
        "reason" => "account_disabled",
      }
      command = GovernanceRevocationCommandValue.new(
        payload:, realm:, issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.current,
      )
      GovernanceRevocationCommand.call(command:)

      assert_predicate root_class.find(root_id), :revoked?
      assert_predicate device_class.find(device_id), :revoked?
      revoked_grant = grant_class.find(grant_id)

      assert_not_nil revoked_grant.revoked_at
      assert_equal historical_root_id, revoked_grant[root_key]
      assert_equal device_id, revoked_grant.device_session_id
    end
  end

  test "one-session scope ends the named device session while another device of the same subject stays usable" do
    [
      ["app", ClientDeviceSession, ClientToken, :subject_public_id],
      ["org", OperatorDeviceSession, OperatorToken, :subject_public_id],
    ].each do |realm, device_class, root_class, actor_key|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      principal = PublicId.generate
      devices = []
      roots = []
      2.times do
        device_id = device_class.insert_all!(
          [{ :public_id => PublicId.generate,
             :subject_public_id => principal,
             :created_at => Time.current,
             :updated_at => Time.current, }],
        ).rows.first.first
        devices << device_class.find(device_id)
        root_id = root_class.insert_all!(
          [{ actor_key => 9_400_001,
             kind_key => kind_id,
             :public_id => PublicId.generate,
             :device_session_id => device_id,
             :authentication_epoch => 0,
             :created_at => Time.current,
             :updated_at => Time.current, }],
        ).rows.first.first
        roots << root_class.find(root_id)
      end
      prefix = (realm == "app") ? "cli" : "opr"
      payload = {
        "iss" => "https://governance.example",
        "aud" => "https://visa.example",
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => SecureRandom.uuid,
        "realm" => realm,
        "sub" => "#{prefix}_#{principal}",
        "scope" => "session",
        "session_public_id" => roots.first.public_id,
        "actor" => "opr_operator",
        "reason" => "session_ended",
      }
      command = GovernanceRevocationCommandValue.new(
        payload:, realm:, issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.current,
      )
      GovernanceRevocationCommand.call(command:)

      assert_predicate roots.first.reload, :revoked?
      assert_predicate devices.first.reload, :revoked?
      assert_not_predicate roots.last.reload, :revoked?
      assert_predicate devices.last.reload, :usable?
    end
  end

  test "a signed principal command revokes all current device authority only in its realm and subject" do
    [
      ["app", OpAppGovernanceRevocationReceipt, ClientDeviceSession, ClientToken, OpAppGrant,
       OpAppAuthorityStopParticipant, :user_id, :client_token_id, "core-app-jp",],
      ["org", OpOrgGovernanceRevocationReceipt, OperatorDeviceSession, OperatorToken, OpOrgGrant,
       OpOrgAuthorityStopParticipant, :staff_id, :operator_token_id, "core-org-jp",],
    ].each do |realm, receipt_class, device_class, root_class, grant_class, bcl_class, actor_key, root_key, client_id|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      principal = PublicId.generate
      devices = []
      roots = []
      grants = []
      [principal, principal, "unrelated-principal"].each_with_index do |subject, index|
        device_id = device_class.insert_all!(
          [{ :public_id => PublicId.generate,
             :subject_public_id => subject,
             :created_at => Time.current,
             :updated_at => Time.current, }],
        ).rows.first.first
        devices << device_class.find(device_id)
        root_id = root_class.insert_all!(
          [{ actor_key => subject,
             kind_key => kind_id,
             :public_id => PublicId.generate,
             :device_session_id => device_id,
             :authentication_epoch => 0,
             :created_at => Time.current,
             :updated_at => Time.current, }],
        ).rows.first.first
        roots << root_class.find(root_id)
        grant_id = grant_class.insert_all!(
          [{ root_key => root_id,
             :subject_public_id => subject,
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
        grants << grant_class.find(grant_id)
      end
      prefix = (realm == "app") ? "cli" : "opr"
      payload = {
        "iss" => "https://governance.example",
        "aud" => "https://visa.example",
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => SecureRandom.uuid,
        "realm" => realm,
        "sub" => "#{prefix}_#{principal}",
        "scope" => "all_sessions",
        "actor" => "opr_operator",
        "reason" => "account_disabled",
      }
      command = GovernanceRevocationCommandValue.new(
        payload:, realm:, issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.current,
      )
      receipt = GovernanceRevocationCommand.call(command:)

      assert receipt_class.exists?(command_id: receipt.command_id)
      devices.first(2).each { |device| assert_predicate device.reload, :revoked? }
      roots.first(2).each { |root| assert_predicate root.reload, :revoked? }
      grants.first(2).each { |grant| assert_not_nil grant.reload.revoked_at }
      assert_predicate devices.last.reload, :usable?
      assert_not_predicate roots.last.reload, :revoked?
      assert_nil grants.last.reload.revoked_at
      assert_equal 2, bcl_class.where(grant_id: grants.first(2).map(&:id)).count
    end
  end

  test "failed back-channel participant construction rolls the command and all revocations back" do
    [
      ["app", OpAppGovernanceRevocationReceipt, ClientDeviceSession, ClientToken, OpAppGrant,
       :user_id, :client_token_id,],
      ["org", OpOrgGovernanceRevocationReceipt, OperatorDeviceSession, OperatorToken, OpOrgGrant,
       :staff_id, :operator_token_id,],
    ].each do |realm, receipt_class, device_class, root_class, grant_class, actor_key, root_key|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      principal = PublicId.generate
      device_id = device_class.insert_all!(
        [{ :public_id => PublicId.generate,
           :subject_public_id => principal,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      root_id = root_class.insert_all!(
        [{ actor_key => 9_300_001,
           kind_key => kind_id,
           :public_id => PublicId.generate,
           :device_session_id => device_id,
           :authentication_epoch => 0,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      grant_id = grant_class.insert_all!(
        [{ root_key => root_id,
           :subject_public_id => principal,
           :device_session_id => device_id,
           :public_id => PublicId.generate,
           :authentication_epoch => 0,
           :oidc_client_id => "unknown-client",
           :oidc_scope => "openid",
           :oidc_jti => SecureRandom.uuid,
           :refresh_token_expires_at => 1.day.from_now,
           :last_used_at => Time.current,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      prefix = (realm == "app") ? "cli" : "opr"
      payload = {
        "iss" => "https://governance.example",
        "aud" => "https://visa.example",
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => SecureRandom.uuid,
        "realm" => realm,
        "sub" => "#{prefix}_#{principal}",
        "scope" => "all_sessions",
        "actor" => "opr_operator",
        "reason" => "account_disabled",
      }
      command = GovernanceRevocationCommandValue.new(
        payload:, realm:, issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.current,
      )

      assert_raises(KeyError) { GovernanceRevocationCommand.call(command:) }
      assert_not receipt_class.exists?(command_id: command.command_id)
      assert_predicate device_class.find(device_id), :usable?
      assert_not_predicate root_class.find(root_id), :revoked?
      assert_nil grant_class.find(grant_id).revoked_at

      grant_class.where(id: grant_id).update_all(oidc_client_id: (realm == "app") ? "core-app-jp" : "core-org-jp")
      receipt = GovernanceRevocationCommand.call(command:)

      assert_equal command.command_id, receipt.command_id
      assert_equal 1, receipt_class.where(command_id: command.command_id).count
      assert_predicate device_class.find(device_id), :revoked?
      assert_predicate root_class.find(root_id), :revoked?
      assert_predicate grant_class.find(grant_id), :revoked?
    end
  end

  test "an empty principal command records its authority once and a renewed retry cannot select later sessions" do
    [
      ["app", OpAppGovernanceRevocationReceipt, ClientDeviceSession, ClientToken],
      ["org", OpOrgGovernanceRevocationReceipt, OperatorDeviceSession, OperatorToken],
    ].each do |realm, receipt_class, device_class, root_class|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      prefix = (realm == "app") ? "cli" : "opr"
      command_id = SecureRandom.uuid
      principal = PublicId.generate
      payload = {
        "iss" => "https://governance.example",
        "aud" => "https://visa.example",
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => command_id,
        "realm" => realm,
        "sub" => "#{prefix}_#{principal}",
        "scope" => "all_sessions",
        "actor" => "opr_authorizing-operator",
        "reason" => "account_disabled",
      }
      command = GovernanceRevocationCommandValue.new(
        payload:, realm:, issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.current,
      )
      receipt = GovernanceRevocationCommand.call(command:)

      assert_equal command_id, receipt.command_id
      assert_equal command.snapshot, receipt.command
      assert_equal command.digest, receipt.command_digest

      actor_key = :subject_public_id
      device_id = device_class.insert_all!(
        [{ :public_id => PublicId.generate,
           :subject_public_id => principal,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      later_root_id = root_class.insert_all!(
        [{ actor_key => principal,
           kind_key => kind_id,
           :public_id => PublicId.generate,
           :device_session_id => device_id,
           :authentication_epoch => 0,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      renewed = GovernanceRevocationCommandValue.new(
        payload: payload.merge("iat" => 10.seconds.from_now.to_i, "exp" => 70.seconds.from_now.to_i),
        realm:, issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: 10.seconds.from_now,
      )
      replay = GovernanceRevocationCommand.call(command: renewed)

      assert_equal receipt.command_id, replay.command_id
      assert_equal receipt.committed_at, replay.committed_at
      assert_predicate device_class.find(device_id), :usable?
      assert_not_predicate root_class.find(later_root_id), :revoked?
      assert_equal 1, receipt_class.where(command_id:).count

      conflicting = GovernanceRevocationCommandValue.new(
        payload: payload.merge("reason" => "account_deleted"), realm:,
        issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.current,
      )

      assert_raises(GovernanceRevocationCommand::Conflict) { GovernanceRevocationCommand.call(command: conflicting) }
      assert_predicate device_class.find(device_id), :usable?
    end
  end

  test "unknown or foreign single-session targets commit neither a receipt nor a stop" do
    [
      ["app", OpAppGovernanceRevocationReceipt, ClientDeviceSession, ClientToken, :subject_public_id],
      ["org", OpOrgGovernanceRevocationReceipt, OperatorDeviceSession, OperatorToken, :subject_public_id],
    ].each do |realm, receipt_class, device_class, root_class, actor_key|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      prefix = (realm == "app") ? "cli" : "opr"
      principal = PublicId.generate
      root_public_id = PublicId.generate
      payload = {
        "iss" => "https://governance.example",
        "aud" => "https://visa.example",
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => SecureRandom.uuid,
        "realm" => realm,
        "sub" => "#{prefix}_#{principal}",
        "scope" => "session",
        "session_public_id" => root_public_id,
        "actor" => "opr_authorizing-operator",
        "reason" => "session_ended",
      }
      command = GovernanceRevocationCommandValue.new(
        payload:, realm:, issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.current,
      )

      assert_raises(GovernanceRevocationCommand::NotFound) { GovernanceRevocationCommand.call(command:) }
      assert_not receipt_class.exists?(command_id: command.command_id)

      device_id = device_class.insert_all!(
        [{ :public_id => PublicId.generate,
           :subject_public_id => "different-principal",
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      root_id = root_class.insert_all!(
        [{ actor_key => "different-principal",
           kind_key => kind_id,
           :public_id => root_public_id,
           :device_session_id => device_id,
           :authentication_epoch => 0,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first

      assert_raises(GovernanceRevocationCommand::Forbidden) { GovernanceRevocationCommand.call(command:) }
      assert_not receipt_class.exists?(command_id: command.command_id)
      assert_not_predicate root_class.find(root_id), :revoked?
      assert_predicate device_class.find(device_id), :usable?
    end
  end

  test "PostgreSQL refuses invalid receipt shapes missing facts and duplicate command identifiers" do
    [
      ["app", OpAppGovernanceRevocationReceipt],
      ["org", OpOrgGovernanceRevocationReceipt],
    ].each do |realm, receipt_class|
      prefix = (realm == "app") ? "cli" : "opr"
      row = {
        command_id: SecureRandom.uuid,
        issuer: "https://governance.example",
        command_digest: "x" * 32,
        command: { realm:,
                   sub: "#{prefix}_principal",
                   scope: "all_sessions",
                   actor: "opr_operator",
                   reason: "disabled", },
        committed_at: Time.current,
      }
      receipt_class.insert_all!([row])

      assert_raises(ActiveRecord::ReadOnlyRecord) do
        receipt_class.find(row.fetch(:command_id)).update!(issuer: "https://changed.example")
      end

      assert_raises(ActiveRecord::RecordNotUnique) do
        receipt_class.transaction(requires_new: true) { receipt_class.insert_all!([row]) }
      end
      [31, 33].each do |length|
        assert_raises(ActiveRecord::StatementInvalid) do
          receipt_class.transaction(requires_new: true) do
            receipt_class.insert_all!([row.merge(command_id: SecureRandom.uuid, command_digest: "x" * length)])
          end
        end
      end
      row.each_key do |key|
        assert_raises(ActiveRecord::StatementInvalid) do
          receipt_class.transaction(requires_new: true) do
            receipt_class.insert_all!([row.merge(:command_id => SecureRandom.uuid, key => nil)])
          end
        end
      end
      [
        {}, [], row.fetch(:command).merge(realm: "other"), row.fetch(:command).merge(sub: nil),
        row.fetch(:command).merge(scope: "session"), row.fetch(:command).merge(session_public_id: "x" * 21),
        row.fetch(:command).merge(unexpected: true), row.fetch(:command).merge(reason: "a" * 65),
      ].each do |snapshot|
        assert_raises(ActiveRecord::StatementInvalid) do
          receipt_class.transaction(requires_new: true) do
            receipt_class.insert_all!([row.merge(command_id: SecureRandom.uuid, command: snapshot)])
          end
        end
      end
    end
  end
end
