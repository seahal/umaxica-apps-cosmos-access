# frozen_string_literal: true

require "test_helper"

class SecurityConsumedJtiUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "replay identity is unique only within its purpose and issuer" do
    jti = SecureRandom.uuid
    attributes = {
      purpose: "oidc_logout_request",
      issuer: "issuer-a",
      jti_digest: SecurityConsumedJti.digest_jti(jti),
      expires_at: 2.minutes.from_now,
    }
    SecurityConsumedJti.create!(attributes)
    duplicate = SecurityConsumedJti.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:jti_digest, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      SecurityConsumedJti.transaction(requires_new: true) { SecurityConsumedJti.insert_all!([attributes]) }
    end
    assert_not SecurityConsumedJti.consume!(
      purpose: attributes.fetch(:purpose), issuer: attributes.fetch(:issuer), jti: jti,
      expires_at: attributes.fetch(:expires_at),
    )
    assert SecurityConsumedJti.consume!(
      purpose: "sign_out_notice", issuer: attributes.fetch(:issuer), jti: jti,
      expires_at: attributes.fetch(:expires_at),
    )
    assert SecurityConsumedJti.consume!(
      purpose: attributes.fetch(:purpose), issuer: "issuer-b", jti: jti, expires_at: attributes.fetch(:expires_at),
    )
    assert_raises(ActiveRecord::RecordInvalid) do
      SecurityConsumedJti.consume!(
        purpose: attributes.fetch(:purpose), issuer: attributes.fetch(:issuer), jti: jti,
        expires_at: nil,
      )
    end
  end
end
