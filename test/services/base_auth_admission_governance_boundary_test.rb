# frozen_string_literal: true

require "test_helper"

class BaseAuthAdmissionGovernanceBoundaryTest < ActiveSupport::TestCase
  test "step-up continuations reject retired actor lookup in both realms without changing the binding" do
    ["app", "org"].each do |surface|
      if surface == "app"
        device = ClientDeviceSession.create!(subject_public_id: PublicId.generate)
        token = ClientToken.create!(authentication_epoch: 0, device_session: device, subject_public_id: device.subject_public_id)
        transaction_class = ClientStepUpCeremonyTransaction
        binding_class = ClientAuthAdmissionBinding
      else
        device = OperatorDeviceSession.create!(subject_public_id: PublicId.generate)
        token = OperatorToken.create!(authentication_epoch: 0, device_session: device, subject_public_id: device.subject_public_id)
        transaction_class = OperatorStepUpCeremonyTransaction
        binding_class = OperatorAuthAdmissionBinding
      end
      transaction = transaction_class.create_transaction!(
        actor_ref: device.subject_public_id, session_ref: token.public_id, token_binding: token.public_id,
        required_scope: "settings_passkey", allowed_methods: ["passkey"],
      )
      binding_id = binding_class.insert_all!(
        [{
          entry_ref: SecureRandom.uuid,
          purpose: "step_up_handoff",
          entry_intent: "not_applicable",
          step_up_ceremony_transaction_id: transaction.id,
          base_token_id: token.id,
          base_browser_digest: "a" * 64,
          expires_at: 5.minutes.from_now,
          curfew_at: 5.minutes.from_now,
        }], returning: %w(id),
      ).rows.first.first
      binding = binding_class.find(binding_id)
      original = binding.attributes

      assert_raises(GovernanceLookupUnavailableError, surface) do
        BaseAuthAdmissionCoordinator.validate_admission_continuation!(
          binding: binding, surface: surface, expected_intent: "step_up",
        )
      end
      assert_equal original, binding.reload.attributes
    end
  end
end
