# frozen_string_literal: true

require "test_helper"

class SignUpOtpCodeDigestTest < ActiveSupport::TestCase
  CONTEXT = {
    "surface" => "app",
    "purpose" => "registration",
    "flow_ref" => "flow-ref",
    "nonce_digest" => "nonce-digest",
    "owner_ref" => "owner-ref",
    "contact_ref" => "contact-ref",
    "destination_digest" => "destination-digest",
    "counter" => 1,
    "issued_at" => 1_800_000_000,
    "expires_at" => 1_800_000_300,
  }.freeze

  test "digests a six-digit ASCII code deterministically and binds its channel" do
    email_digest = SignUpOtpCodeDigest.for(context: CONTEXT, channel: :email, code: "000042")

    assert_equal email_digest, SignUpOtpCodeDigest.for(context: CONTEXT, channel: "email", code: "000042")
    assert_equal 64, email_digest.length
    assert_match(/\A[0-9a-f]{64}\z/, email_digest)
    assert_not_equal email_digest, SignUpOtpCodeDigest.for(context: CONTEXT, channel: :sms, code: "000042")
  end

  test "rejects codes outside the six ASCII digit format" do
    [nil, "", "12345", "1234567", "１２３４５６", "12a456"].each do |code|
      assert_raises(ArgumentError, "#{code.inspect} must be refused") do
        SignUpOtpCodeDigest.for(context: CONTEXT, channel: :email, code:)
      end
    end
  end
end
