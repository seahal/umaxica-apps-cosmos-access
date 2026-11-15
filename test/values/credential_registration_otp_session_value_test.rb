# frozen_string_literal: true

require "test_helper"

class CredentialRegistrationOtpSessionValueTest < ActiveSupport::TestCase
  test "serialized registration proof reloads without exposing its root or browser digest" do
    session = CredentialRegistrationOtpSessionValue.for(
      surface: "app",
      channel: :email,
      transaction_ref: SecureRandom.uuid,
      root_ref: PublicId.generate,
      browser_nonce: SecureRandom.urlsafe_base64(32),
    )

    loaded = CredentialRegistrationOtpSessionValue.load(session_ref: session.dump)

    assert_equal session, loaded
    assert_equal session.root_ref, loaded.root_ref
    assert_equal session.browser_digest, loaded.browser_digest
    assert_includes loaded.inspect, "root_ref=[FILTERED]"
    assert_includes loaded.inspect, "browser_digest=[FILTERED]"
    assert_not_includes loaded.inspect, loaded.root_ref
    assert_not_includes loaded.inspect, loaded.browser_digest
  end

  test "session loading rejects malformed tuples and unsupported tuple versions" do
    ["not-json", "[]", JSON.generate([2, "root", "a" * 64]), JSON.generate([1, "root", "short"])].each do |value|
      assert_raises(ArgumentError, value) { CredentialRegistrationOtpSessionValue.load(session_ref: value) }
    end

    malformed_encoding = String.new([0xff].pack("C"), encoding: Encoding::UTF_8)

    assert_raises(ArgumentError) { CredentialRegistrationOtpSessionValue.load(session_ref: malformed_encoding) }
  end
end
