# frozen_string_literal: true

require "test_helper"

class SignInFlowAuthenticationEvidenceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [ClientSignInFlow, OperatorSignInFlow].each do |model|
    test "#{model.name} refuses evidence in every state while Governance is unavailable" do
      now = model.database_now
      model::STATES.each do |state_name, state_id|
        flow = model.create!(
          state_id: state_id,
          nonce_digest: model.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: now,
          expires_at: now + 300,
          completed_at: (state_name == "COMPLETED") ? now : nil,
        )
        original = flow.reload.attributes

        assert_raises(GovernanceLookupUnavailableError, "#{model} #{state_name}") do
          flow.record_authentication_evidence!(method: "passkey")
        end
        assert_equal original, flow.reload.attributes
        assert_equal state_name, model.state_name_for(flow.state_id)
      end
    end

    test "#{model.name} refuses replacement of historical evidence for every context" do
      now = model.database_now
      flow = model.create!(
        state_id: model.state_id_for("PRIMARY_PENDING"),
        nonce_digest: model.digest_nonce(SecureRandom.urlsafe_base64(32)),
        issued_at: now,
        expires_at: now + 300,
      )
      # These scalar facts represent an existing OP row after the source actor moved to Governance.
      flow.update_columns(
        principal_id: 9_117_000_000_000, authentication_method: "passkey",
        authentication_event_at: now, authentication_context: "normal",
      )
      original = flow.reload.attributes
      [nil, "", "unknown", "normal\0", 0, "standby", "normal"].each do |context|
        assert_raises(GovernanceLookupUnavailableError) do
          flow.record_authentication_evidence!(method: "email", authentication_context: context)
        end
        assert_equal original, flow.reload.attributes
      end
    end
  end
end
