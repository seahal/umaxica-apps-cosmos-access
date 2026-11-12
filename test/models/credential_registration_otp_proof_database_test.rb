# frozen_string_literal: true

require "test_helper"

# Boolean snapshots keep keyed digests and original Root references out of failure output.
class CredentialRegistrationOtpProofDatabaseTest < ActiveSupport::TestCase
  [
    [ClientEmailCeremonyTransaction, :app, :email],
    [ClientTelephoneCeremonyTransaction, :app, :telephone],
    [OperatorEmailCeremonyTransaction, :org, :email],
    [OperatorTelephoneCeremonyTransaction, :org, :telephone],
  ].each do |model, surface, channel|
    test "#{surface} #{channel} registration proof rejects malformed direct writes and protects verified facts" do
      candidate_key = (channel == :email) ? :email_candidate_ref : :telephone_candidate_ref
      digest_key = (channel == :email) ? :normalized_email_digest : :normalized_number_digest
      flow = model.create_transaction!(
        :actor_ref => "original-actor", :session_ref => "original-browser", :operation => "registration",
        candidate_key => "original-candidate", digest_key => "a" * 64,
      )
      code =
        if channel == :email
          flow.issue_email_otp!(purpose: "credential_registration")
        else
          flow.issue_telephone_otp!(purpose: "credential_registration")
        end
      original = flow.reload.attributes
      digest_field = (channel == :email) ? :normalized_email_digest : :normalized_number_digest
      candidate_field = (channel == :email) ? :email_candidate_ref : :telephone_candidate_ref
      malformed = [
        { purpose: "unsupported" }, { otp_generation: nil }, { otp_generation: "not-a-uuid" },
        { otp_verifier: "" }, { otp_verifier: "a" * 63 }, { otp_verifier: "a" * 65 },
        { otp_verifier: "G" * 64 }, { otp_verifier: nil },
        { actor_ref: "" }, { session_ref: "" }, { candidate_field => nil },
        { digest_field => "a" * 63 }, { digest_field => "a" * 65 },
        { otp_expires_at: Float::INFINITY }, { expires_at: -Float::INFINITY },
        { otp_consumed_at: flow.class.database_now },
        { otp_receipt_verifier: "a" * 64 }, { otp_result_expires_at: flow.class.database_now + 60.seconds },
      ]
      malformed.each_with_index do |replacement, index|
        flow.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid, "malformed proof partition #{index}") do
            flow.update_columns(replacement)
          end
          raise ActiveRecord::Rollback
        end
        unchanged = original == flow.reload.attributes

        assert unchanged, "Rejected SQL must preserve the original challenge without revealing its facts"
      end

      # Generation is an opaque UUID, not the retired unsigned-decimal HOTP counter.
      flow.class.transaction(requires_new: true) do
        assert flow.update_columns(otp_generation: SecureRandom.uuid, otp_verifier: "a" * 64)
        raise ActiveRecord::Rollback
      end

      assert_withheld { original == flow.reload.attributes }

      now = flow.class.database_now
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000),
       60.seconds - Rational(1, 1_000_000), 60.seconds,
       60.seconds + Rational(1, 1_000_000),].each do |ttl|
        flow.class.transaction(requires_new: true) do
          replacement = {
            otp_consumed_at: now,
            otp_verifier: nil,
            otp_receipt_verifier: "a" * 64,
            otp_result_expires_at: now + ttl,
          }
          if ttl.positive? && ttl <= 60.seconds
            assert flow.update_columns(replacement)
          else
            assert_raises(ActiveRecord::StatementInvalid) { flow.update_columns(replacement) }
          end
          raise ActiveRecord::Rollback
        end

        assert_withheld("Rolled-back bounds must not manufacture a result") { original == flow.reload.attributes }
      end

      binding = {
        code: code,
        purpose: "credential_registration",
        actor_ref: "original-actor",
        session_ref: "original-browser",
        operation: "registration",
        candidate_ref: "original-candidate",
      }
      verified =
        if channel == :email
          flow.verify_email_otp!(**binding)
        else
          flow.verify_telephone_otp!(**binding)
        end

      assert verified
      committed = flow.reload.attributes
      [
        { otp_consumed_at: nil, otp_receipt_verifier: nil, otp_result_expires_at: nil },
        { otp_verifier: original.fetch("otp_verifier") }, { otp_generation: SecureRandom.uuid },
      ].each do |replacement|
        flow.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid) { flow.update_columns(replacement) }
          raise ActiveRecord::Rollback
        end

        assert_withheld("SQL cannot erase or replace committed proof") { committed == flow.reload.attributes }
      end
      assert_nil flow.otp_verifier
      assert_not_nil flow.otp_consumed_at
      assert_not flow.consumed?
    end
  end
end
