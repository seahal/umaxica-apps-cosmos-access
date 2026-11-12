# frozen_string_literal: true

require "test_helper"

# D-172 S-2: stop records go with their roots, children first, never before every participant is final.
class OpAuthorityStopPurgerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @principal_public_id = PublicId.generate
    @device = ClientDeviceSession.create!(user_id: 9_300_011, principal_public_id: @principal_public_id)
    @root = ClientToken.create!(authentication_epoch: 0, device_session: @device, user_id: @device.user_id)
    @grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token_id: @root.id, device_session_id: @root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid, last_used_at: Time.current,
      refresh_token_expires_at: 1.day.from_now,
    )
    @stop = OpAuthorityStopCommitter.stop_root(
      root: @root, cause: "browser_logout", principal_public_id: @principal_public_id, authority_evidence_ref: "test",
    ).stop
  end

  test "a stop with a pending participant holds its root" do
    assert_equal [@root.id], OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [@root.id])
    assert OpAppAuthorityStop.exists?(@stop.id)
  end

  test "a stop whose participants are final is deleted with its children and releases the root" do
    @root.reload.update_columns(purge_eligible_at: @root.discard_at)
    OpAppAuthorityStopParticipant.where(stop_id: @stop.id).find_each do |participant|
      participant.record_delivery_result!(outcome: :acknowledged)
    end

    assert_equal [OpAuthorityStopReference.participant_status_id("acknowledged")],
                 OpAppAuthorityStopParticipant.where(stop_id: @stop.id).pluck(:status_id).uniq
    assert_operator ClientToken.database_now, :>=, @root.purge_eligible_at

    assert_empty OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [@root.id])
    assert_not OpAppAuthorityStop.exists?(@stop.id)
    assert_not OpAppAuthorityStopRootTarget.exists?(stop_id: @stop.id)
  end

  test "an all-roots stop stays until every target root reaches its own retention deadline" do
    first_device = ClientDeviceSession.create!(user_id: @device.user_id, principal_public_id: @principal_public_id)
    second_device = ClientDeviceSession.create!(user_id: @device.user_id, principal_public_id: @principal_public_id)
    first_root = ClientToken.create!(authentication_epoch: 0, device_session: first_device, user_id: first_device.user_id)
    second_root = ClientToken.create!(authentication_epoch: 0, device_session: second_device, user_id: second_device.user_id)
    first_grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token_id: first_root.id, device_session_id: first_root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid,
      last_used_at: Time.current, refresh_token_expires_at: 1.day.from_now,
    )
    second_grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token_id: second_root.id, device_session_id: second_root.device_session_id,
      oidc_client_id: "warp-app-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, last_used_at: Time.current, refresh_token_expires_at: 1.day.from_now,
    )
    stop = OpAuthorityStopCommitter.stop_principal(
      realm: "app", roots: [first_root, second_root], cause: "identity_stop",
      principal_public_id: @principal_public_id, authority_evidence_ref: "multi-root", cutoff_epoch: 1,
    ).stop
    first_root.reload.update_columns(purge_eligible_at: first_root.discard_at)
    second_root.reload.update_columns(purge_eligible_at: second_root.discard_at + 1.hour)
    OpAppAuthorityStopParticipant.where(stop_id: stop.id).find_each do |participant|
      participant.record_delivery_result!(outcome: :acknowledged)
    end

    assert_equal [OpAuthorityStopReference.participant_status_id("acknowledged")],
                 OpAppAuthorityStopParticipant.where(stop_id: stop.id).pluck(:status_id).uniq
    assert_operator ClientToken.database_now, :>=, first_root.purge_eligible_at
    assert_operator second_root.purge_eligible_at, :>, ClientToken.database_now

    assert_equal [first_root.id], OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [first_root.id])
    assert OpAppAuthorityStop.exists?(stop.id)

    second_root.reload.update_columns(purge_eligible_at: second_root.discard_at)

    assert_operator ClientToken.database_now, :>=, second_root.purge_eligible_at

    assert_empty OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [first_root.id])
    assert_not OpAppAuthorityStop.exists?(stop.id)
    assert_not OpAppAuthorityStopGrantTarget.exists?(stop_id: stop.id, grant_id: first_grant.id)
    assert_not OpAppAuthorityStopGrantTarget.exists?(stop_id: stop.id, grant_id: second_grant.id)
  end

  test "no root ids release nothing" do
    assert_empty OpAuthorityStopPurger.release_roots!(realm: "app", root_ids: [])
    assert OpAppAuthorityStop.exists?(@stop.id)
  end
end
