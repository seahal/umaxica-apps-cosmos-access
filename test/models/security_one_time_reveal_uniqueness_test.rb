# frozen_string_literal: true

require "test_helper"

class SecurityOneTimeRevealUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a reveal identifier cannot be reused for a different actor or payload" do
    attributes = {
      jti_digest: SecureRandom.hex(32),
      actor_type: "Client",
      actor_id: 123,
      session_nonce_digest: SecureRandom.hex(32),
      purpose: "client.recovery_secret_credential",
      encrypted_payload: "sealed-payload",
      expires_at: 15.minutes.from_now,
    }
    SecurityOneTimeReveal.create!(attributes)
    replacement = attributes.merge(actor_id: 456, encrypted_payload: "other-sealed-payload")
    duplicate = SecurityOneTimeReveal.new(replacement)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:jti_digest, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      SecurityOneTimeReveal.transaction(requires_new: true) do
        SecurityOneTimeReveal.insert_all!([replacement])
      end
    end

    separate = SecurityOneTimeReveal.create!(replacement.merge(jti_digest: SecureRandom.hex(32)))

    assert_predicate separate, :persisted?
  end
end
