# frozen_string_literal: true

require "test_helper"

class SignupOtpProofDatabaseTest < ActiveSupport::TestCase
  [
    [ClientEmailCeremonyTransaction, :email],
    [ClientTelephoneCeremonyTransaction, :telephone],
  ].each do |model, channel|
    test "app #{channel} signup proof database shape and immutable committed result" do
      candidate_key = (channel == :email) ? :email_candidate_ref : :telephone_candidate_ref
      digest_key = (channel == :email) ? :normalized_email_digest : :normalized_number_digest
      transaction = model.create_transaction!(
        :actor_ref => "original-actor", :session_ref => "original-browser", :operation => "sign_up",
        candidate_key => "original-candidate", digest_key => "a" * 64,
      )
      code =
        if channel == :email
          transaction.issue_email_otp!(purpose: "sign_up")
        else
          transaction.issue_telephone_otp!(purpose: "sign_up")
        end
      now = model.database_now
      original = transaction.reload.attributes

      invalid_contexts = [
        { purpose: "unsupported" }, { otp_generation: nil }, { otp_generation: "not-a-uuid" },
        { otp_verifier: "a" * 63 }, { otp_verifier: "a" * 65 },
        { otp_verifier: "G" * 64 }, { otp_verifier: "" },
        { otp_expires_at: Float::INFINITY }, { expires_at: -Float::INFINITY },
        { otp_consumed_at: now }, { otp_receipt_verifier: "a" * 64 },
      ]
      invalid_contexts.each do |invalid|
        transaction.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid) do
            transaction.update_columns(invalid)
          end
          raise ActiveRecord::Rollback
        end

        assert_withheld("rejected direct writes must preserve challenge facts") {
          original == transaction.reload.attributes
        }
      end

      binding = {
        code: code,
        purpose: "sign_up",
        actor_ref: "original-actor",
        session_ref: "original-browser",
        operation: "sign_up",
        candidate_ref: "original-candidate",
      }
      verified =
        if channel == :email
          transaction.verify_email_otp!(**binding)
        else
          transaction.verify_telephone_otp!(**binding)
        end

      assert verified, "ceremony verification must establish the immutable result"
      committed = transaction.reload.attributes
      [
        { otp_consumed_at: nil, otp_receipt_verifier: nil, otp_result_expires_at: nil },
        { otp_verifier: original.fetch("otp_verifier") }, { otp_generation: SecureRandom.uuid },
      ].each do |replacement|
        transaction.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid) do
            transaction.update_columns(replacement)
          end
          raise ActiveRecord::Rollback
        end

        assert_withheld("direct SQL cannot erase or replace committed proof") {
          committed == transaction.reload.attributes
        }
      end
    end
  end
end
