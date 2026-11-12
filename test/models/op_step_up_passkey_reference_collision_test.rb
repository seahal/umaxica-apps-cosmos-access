# frozen_string_literal: true

require "test_helper"

class OpStepUpPasskeyReferenceCollisionTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  [
    [ClientStepUpSession, ClientStepUpCeremonyTransaction, "app", :user_token],
    [OperatorStepUpSession, OperatorStepUpCeremonyTransaction, "org", :staff_token],
  ].each do |session_model, transaction_model, realm, token_key|
    test "#{realm} challenge reference retries only the bounded named index collision" do
      tokens =
        (realm == "app") ? [client_tokens(:one), client_tokens(:two)] :
               [operator_tokens(:one), operator_tokens(:two)]
      pairs =
        tokens.map do |token|
          transaction = transaction_model.create_transaction!(
            actor_ref: "historical-actor", session_ref: token.public_id, required_scope: "settings_passkey",
            required_aal: "none", allowed_methods: ["passkey"], return_to: "/visa",
          )
          session = session_model.create!(
            token_key => token, :step_up_ceremony_transaction_ref => transaction.transaction_id,
            :scope => transaction.required_scope, :return_to => transaction.return_to,
            :status => "PENDING", :discard_at => transaction.expires_at,
          )
          [session, transaction]
        end
      first, first_transaction = pairs.first
      second, second_transaction = pairs.last
      collision = first.issue_bound_passkey_challenge!(
        transaction: first_transaction, challenge: "first", rp_id: "app.example", origin: "https://app.example",
      )
      attributes = first.reload.attributes.slice(
        "passkey_challenge", "passkey_challenge_ref", "passkey_rp_id", "passkey_origin",
        "passkey_challenge_expires_at", "passkey_challenge_consumed_at",
      )
      assert_raises(ActiveRecord::RecordNotUnique) do
        session_model.transaction(requires_new: true) { session_model.where(id: second.id).update_all(attributes) }
      end
      second.assign_attributes(attributes)

      assert_not second.valid?
      assert second.errors.of_kind?(:passkey_challenge_ref, :taken)
      second.reload
      generated = Array.new(StepUpSessionConsumable::MAX_CHALLENGE_REF_COLLISION_RETRIES + 1, collision)

      error =
        assert_raises(StepUpSessionConsumable::ChallengeReferenceCollision) do
          PublicId.stub(:generate, -> { generated.shift }) do
            second.issue_bound_passkey_challenge!(
              transaction: second_transaction, challenge: "second", rp_id: "app.example", origin: "https://app.example",
            )
          end
        end

      assert_kind_of ActiveRecord::RecordInvalid, error.cause
      assert error.cause.record.errors.of_kind?(:passkey_challenge_ref, :taken)
      assert_empty generated
      assert_nil second.reload.passkey_challenge_ref
      assert_equal collision, first.reload.passkey_challenge_ref

      replacement = PublicId.generate
      generated = [collision, replacement]
      result =
        PublicId.stub(:generate, -> { generated.shift }) do
          second.issue_bound_passkey_challenge!(
            transaction: second_transaction, challenge: "second", rp_id: "app.example", origin: "https://app.example",
          )
        end

      assert_equal replacement, result
      assert_equal replacement, second.reload.passkey_challenge_ref
      assert_equal collision, first.reload.passkey_challenge_ref
    end
  end
end
