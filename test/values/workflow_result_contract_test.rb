# frozen_string_literal: true

require "test_helper"

class WorkflowResultContractTest < ActiveSupport::TestCase
  test "email and telephone OTP results distinguish verified evidence from rejected evidence" do
    result_shapes = [
      [AuthEmailOtpVerificationResult, :contact, "person@example.test"],
      [EmailCredentialRegistrationOtpVerificationResult, :email, "person@example.test"],
      [EmailSignUpOtpVerificationResult, :email, "person@example.test"],
      [TelephoneCredentialRegistrationOtpVerificationResult, :telephone, "+14155550100"],
      [TelephoneSignUpOtpVerificationResult, :telephone, "+14155550100"],
    ]

    result_shapes.each do |result_class, contact_field, contact_value|
      { verified: [true, true], already_verified: [false, true], rejected: [false, false] }.each do |status, expected|
        result = result_class.new(status:, **{ contact_field => contact_value })

        assert_equal expected.first, result.success?, "#{result_class} #{status} success"
        assert_equal expected.last, result.verified_evidence?, "#{result_class} #{status} evidence"
      end
    end
  end

  test "credential registration OTP issue results never expose codes or transaction details in inspection" do
    code = "one-time-secret-code"
    transaction = Object.new
    results = [
      EmailCredentialRegistrationOtpIssueResult.new(status: :issued, transaction:, code:),
      TelephoneCredentialRegistrationOtpIssueResult.new(status: :issued, transaction:, code:),
    ]

    results.each do |result|
      assert_predicate result, :success?
      assert_not_includes result.inspect, code
      assert_not_includes result.inspect, transaction.inspect
    end

    email_refusal = EmailCredentialRegistrationOtpIssueResult.new(status: :unavailable, transaction: nil, code: nil)
    telephone_refusal =
      TelephoneCredentialRegistrationOtpIssueResult.new(status: :unavailable, transaction: nil, code: nil)

    assert_not email_refusal.success?
    assert_not telephone_refusal.success?
  end

  test "flow transition results distinguish durable expiry refusals from invalid result states" do
    expired = FlowTransitionResult.new(status: :expired)

    assert_predicate expired, :expired?
    assert_raises(FlowInvalidTransition) { expired.value! }

    blocked = FlowTransitionResult.new(status: :blocked)

    assert_not_predicate blocked, :expired?
    assert_raises(FlowConfigurationError) { blocked.value! }
  end

  test "sign-in participants require strict boolean lifecycle evidence" do
    item = SignInParticipantItem.new(key: "mfa", blocking: true, cleared: true, message: "Complete MFA")

    assert_predicate item, :blocking?
    assert_predicate item, :cleared?
    assert_equal :mfa, item.key
    assert_equal "Complete MFA", item.message

    malformed = SignInParticipantItem.new(key: "guardrail", blocking: "true", cleared: 1)

    assert_not_predicate malformed, :blocking?
    assert_not_predicate malformed, :cleared?
  end

  test "sign-up results classify outcomes and normalize cleanup requirements" do
    ticket = Struct.new(:step).new("checkpoint")
    success = SignUpResult.build(status: "advanced", ticket:, cleanup_required: "required", errors: "notice")

    assert_predicate success, :success?
    assert_not_predicate success, :failure?
    assert_predicate success, :cleanup_required?
    assert_equal :advanced, success.status
    assert_equal "checkpoint", success.step
    assert_equal ["notice"], success.errors

    failure = SignUpResult.build(status: :blocked)

    assert_not_predicate failure, :success?
    assert_predicate failure, :failure?
    assert_not_predicate failure, :cleanup_required?
    assert_raises(ArgumentError) { SignUpResult.build(status: :unknown) }
  end
end
