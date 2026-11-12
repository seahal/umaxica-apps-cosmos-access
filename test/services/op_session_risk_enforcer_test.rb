# frozen_string_literal: true

require "test_helper"

class OpSessionRiskEnforcerTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  setup do
    @risk_enabled = ENV["RISK_ENFORCEMENT_ENABLED"]
    @risk_disabled = ENV["RISK_ENFORCEMENT_DISABLED"]
    ENV["RISK_ENFORCEMENT_ENABLED"] = "true"
    ENV.delete("RISK_ENFORCEMENT_DISABLED")
  end

  teardown do
    @risk_enabled.nil? ? ENV.delete("RISK_ENFORCEMENT_ENABLED") : ENV["RISK_ENFORCEMENT_ENABLED"] = @risk_enabled
    @risk_disabled.nil? ? ENV.delete("RISK_ENFORCEMENT_DISABLED") : ENV["RISK_ENFORCEMENT_DISABLED"] = @risk_disabled
  end

  test "five failed authentications revoke proof on OP roots without loading an actor" do
    root = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    unrelated = ClientToken.find(ActiveRecord::FixtureSet.identify(:two))
    [root, unrelated].each do |token|
      token.update!(evidence_state_id: IdentityStepUpCeremonyContract::EVIDENCE_RECORDED)
    end
    4.times do
      ClientOccurrence.create!(
        body: SecureRandom.uuid, event_type: "risk.auth_failed",
        context: { user_id: root.user_id }, status_id: ClientOccurrence::ACTIVE_STATUS_ID,
        discard_at: 1.hour.from_now, purge_eligible_at: 2.hours.from_now,
      )
    end

    SignRiskEnforcer.call(root)

    assert_equal IdentityStepUpCeremonyContract::EVIDENCE_RECORDED, root.reload.evidence_state_id
    ClientOccurrence.create!(
      body: SecureRandom.uuid, event_type: "risk.auth_failed",
      context: { user_id: root.user_id }, status_id: ClientOccurrence::ACTIVE_STATUS_ID,
      discard_at: 1.hour.from_now, purge_eligible_at: 2.hours.from_now,
    )

    SignRiskEnforcer.call(root)

    assert_equal IdentityStepUpCeremonyContract::EVIDENCE_ABSENT, root.reload.evidence_state_id
    assert_predicate root, :active_status?
    assert_equal IdentityStepUpCeremonyContract::EVIDENCE_RECORDED, unrelated.reload.evidence_state_id
  end

  test "refresh reuse stops the principal's OP roots while preserving other principals in both realms" do
    [
      [ClientToken, ClientOccurrence, :user_id],
      [OperatorToken, OperatorOccurrence, :staff_id],
    ].each do |root_class, occurrence_class, actor_key|
      root = root_class.find(ActiveRecord::FixtureSet.identify(:one))
      unrelated = root_class.find(ActiveRecord::FixtureSet.identify(:two))
      occurrence_class.create!(
        body: SecureRandom.uuid, event_type: "risk.refresh_reuse_detected",
        context: { actor_key => root[actor_key] }, status_id: occurrence_class::ACTIVE_STATUS_ID,
        discard_at: 1.hour.from_now, purge_eligible_at: 2.hours.from_now,
      )

      SignRiskEnforcer.call(root)

      assert_predicate root.reload, :revoked?
      assert_predicate root.device_session_record!, :revoked?
      assert_predicate unrelated.reload, :active_status?
      assert_not unrelated.device_session_record!.revoked?
      realm = OpAuthorityStopCommitter.realm_for_root(root)
      stop = OpAuthorityStopCommitter.stop_class(realm).where(principal_public_id: root.principal_public_id).last!

      assert_equal OpAuthorityStopReference.cause_id("risk"), stop.cause_id
    end
  end
end
