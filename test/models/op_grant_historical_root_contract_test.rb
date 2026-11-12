# frozen_string_literal: true

require "test_helper"

class OpGrantHistoricalRootContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "creation requires an existing historical root and its matching stable device" do
    [
      ["app", ClientDeviceSession, ClientToken, OpAppGrant, :user_id, :client_token_id, "core-app-jp"],
      ["org", OperatorDeviceSession, OperatorToken, OpOrgGrant, :staff_id, :operator_token_id, "core-org-jp"],
    ].each do |realm, device_class, root_class, grant_class, actor_key, root_key, client_id|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      device_ids =
        2.times.map do
          device_class.insert_all!(
            [{ actor_key => 9_700_001,
               :public_id => PublicId.generate,
               :principal_public_id => "creation-contract-principal",
               :created_at => Time.current,
               :updated_at => Time.current, }],
          ).rows.first.first
        end
      root_id = root_class.insert_all!(
        [{ actor_key => 9_700_001,
           kind_key => kind_id,
           :public_id => PublicId.generate,
           :device_session_id => device_ids.first,
           :authentication_epoch => 0,
           :discard_at => 2.days.from_now,
           :last_used_at => Time.current,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      attributes = {
        root_key => root_id,
        :device_session_id => device_ids.first,
        :public_id => PublicId.generate,
        :authentication_epoch => 0,
        :oidc_client_id => client_id,
        :oidc_scope => "openid",
        :oidc_jti => SecureRandom.uuid,
        :refresh_token_expires_at => 1.day.from_now,
        :last_used_at => Time.current,
      }
      valid = grant_class.new(attributes)
      valid.valid?

      assert_empty valid.errors.details

      derived_device = grant_class.new(attributes.except(:device_session_id))
      derived_device.valid?

      assert_empty derived_device.errors.details
      assert_equal device_ids.first, derived_device.device_session_id

      unsaved_root = root_class.new(
        actor_key => 9_700_001, kind_key => kind_id, :id => root_id + 2_000_000,
        :public_id => PublicId.generate, :device_session_id => device_ids.first, :authentication_epoch => 0,
      )
      unsaved_parent = grant_class.new(attributes.merge(root_key => unsaved_root.id))
      unsaved_parent.valid?

      assert_includes unsaved_parent.errors.attribute_names, root_key
      assert_predicate unsaved_root, :new_record?
      assert_not root_class.exists?(id: unsaved_root.id)

      missing = grant_class.new(attributes.merge(root_key => root_id + 1_000_000))
      missing.valid?

      assert_includes missing.errors.attribute_names, root_key

      absent = grant_class.new(attributes.merge(root_key => nil))
      absent.valid?

      assert_includes absent.errors.attribute_names, root_key

      mismatched = grant_class.new(attributes.merge(device_session_id: device_ids.last))
      mismatched.valid?

      assert_includes mismatched.errors.attribute_names, :device_session_id
    end
  end

  test "a saved grant cannot change its historical root or its device owner" do
    [
      ["app", ClientDeviceSession, ClientToken, OpAppGrant, :user_id, :client_token_id, "core-app-jp"],
      ["org", OperatorDeviceSession, OperatorToken, OpOrgGrant, :staff_id, :operator_token_id, "core-org-jp"],
    ].each do |realm, device_class, root_class, grant_class, actor_key, root_key, client_id|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      device_ids = []
      root_ids =
        2.times.map do
          device_id = device_class.insert_all!(
            [{ actor_key => 9_700_002,
               :public_id => PublicId.generate,
               :principal_public_id => "immutable-contract-principal",
               :created_at => Time.current,
               :updated_at => Time.current, }],
          ).rows.first.first
          device_ids << device_id
          root_class.insert_all!(
            [{ actor_key => 9_700_002,
               kind_key => kind_id,
               :public_id => PublicId.generate,
               :device_session_id => device_id,
               :authentication_epoch => 0,
               :discard_at => 2.days.from_now,
               :last_used_at => Time.current,
               :created_at => Time.current,
               :updated_at => Time.current, }],
          ).rows.first.first
        end
      grant = grant_class.create!(
        root_key => root_ids.first, :device_session_id => device_ids.first, :public_id => PublicId.generate,
        :authentication_epoch => 0, :oidc_client_id => client_id, :oidc_scope => "openid",
        :oidc_jti => SecureRandom.uuid,
        :refresh_token_expires_at => 1.day.from_now, :last_used_at => Time.current,
      )

      [root_ids.last, nil].each do |candidate|
        assert_raises(ActiveRecord::ReadonlyAttributeError) { grant.update!(root_key => candidate) }
        assert_equal root_ids.first, grant.reload[root_key]
        assert_equal device_ids.first, grant.device_session_id
      end
      [device_ids.last, nil].each do |candidate|
        assert_raises(ActiveRecord::ReadonlyAttributeError) { grant.update!(device_session_id: candidate) }
        assert_equal root_ids.first, grant.reload[root_key]
        assert_equal device_ids.first, grant.device_session_id
      end
    end
  end

  test "direct SQL still requires nonnull historical IDs and an existing nonnull device parent" do
    [
      ["app", ClientDeviceSession, ClientToken, OpAppGrant, :user_id, :client_token_id, "core-app-jp"],
      ["org", OperatorDeviceSession, OperatorToken, OpOrgGrant, :staff_id, :operator_token_id, "core-org-jp"],
    ].each do |realm, device_class, root_class, grant_class, actor_key, root_key, client_id|
      kind_key, kind_id = {
        "app" => [:user_token_kind_id, ClientTokenKind::BROWSER_WEB],
        "org" => [:staff_token_kind_id, OperatorTokenKind::BROWSER_WEB],
      }.fetch(realm)
      device_id = device_class.insert_all!(
        [{ actor_key => 9_700_003,
           :public_id => PublicId.generate,
           :principal_public_id => "sql-contract-principal",
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      root_id = root_class.insert_all!(
        [{ actor_key => 9_700_003,
           kind_key => kind_id,
           :public_id => PublicId.generate,
           :device_session_id => device_id,
           :authentication_epoch => 0,
           :created_at => Time.current,
           :updated_at => Time.current, }],
      ).rows.first.first
      row = {
        root_key => root_id,
        :device_session_id => device_id,
        :public_id => PublicId.generate,
        :authentication_epoch => 0,
        :oidc_client_id => client_id,
        :oidc_scope => "openid",
        :oidc_jti => SecureRandom.uuid,
        :refresh_token_expires_at => 1.day.from_now,
        :last_used_at => Time.current,
        :created_at => Time.current,
        :updated_at => Time.current,
      }

      assert_raises(ActiveRecord::NotNullViolation) do
        grant_class.transaction(requires_new: true) { grant_class.insert_all!([row.merge(root_key => nil)]) }
      end
      assert_raises(ActiveRecord::NotNullViolation) do
        grant_class.transaction(requires_new: true) { grant_class.insert_all!([row.merge(device_session_id: nil)]) }
      end
      assert_raises(ActiveRecord::InvalidForeignKey) do
        grant_class.transaction(requires_new: true) do
          grant_class.insert_all!([row.merge(device_session_id: device_id + 1_000_000)])
        end
      end
    end
  end

  test "grant-only authority stop survives physical purge of its historical issuing root" do
    [
      ["app", ClientDeviceSession, ClientToken, OpAppGrant, :user_id, :client_token_id, "core-app-jp"],
      ["org", OperatorDeviceSession, OperatorToken, OpOrgGrant, :staff_id, :operator_token_id, "core-org-jp"],
    ].each do |realm, devices, roots, grants, actor_key, root_key, client_id|
      device = devices.create!(actor_key => 9_700_004, :principal_public_id => "purged-history-principal")
      root = roots.create!(
        actor_key => 9_700_004, :device_session => device, :authentication_epoch => 0,
        :discard_at => 1.day.from_now,
      )
      grant = grants.create!(
        root_key => root.id,
        :device_session_id => device.id, :authentication_epoch => 0,
        :oidc_client_id => client_id, :refresh_token_expires_at => 1.hour.from_now,
      )
      refresh = root.rotate_refresh_token!
      rotation = AuthRefreshTokenIssuer.call(
        refresh_token: refresh, resource_type: (realm == "app") ? "client" : "operator",
      )

      assert_predicate rotation, :success?
      assert_equal 1, roots.where(id: root.id).delete_all
      assert_not_predicate grant.reload, :revoked?
      foreign_device = devices.create!(actor_key => 9_700_005, :principal_public_id => "foreign-principal")
      foreign_root = roots.create!(
        actor_key => 9_700_005, :device_session => foreign_device, :authentication_epoch => 0,
        :discard_at => 1.day.from_now,
      )
      device.update!(current_refresh_token_id: foreign_root.id)

      assert_raises(ActiveRecord::RecordNotFound) do
        OpAuthorityStopCommitter.stop_grant(
          grant:, cause: "token_revocation", principal_public_id: device.principal_public_id,
          authority_evidence_ref: "historical-grant-contract",
        )
      end

      assert_not_predicate grant.reload, :revoked?
      device.update!(current_refresh_token_id: rotation.token.id)
      result = OpAuthorityStopCommitter.stop_grant(
        grant:, cause: "token_revocation", principal_public_id: device.principal_public_id,
        authority_evidence_ref: "historical-grant-contract",
      )

      assert_predicate result, :stopped?
      assert_predicate grant.reload, :revoked?
      assert_not_predicate rotation.token.reload, :revoked?
      assert_predicate device.reload, :usable?
    end
  end
end
