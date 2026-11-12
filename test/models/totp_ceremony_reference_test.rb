# frozen_string_literal: true

require "test_helper"

class IdentityTotpCeremonyReferenceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "TOTP ceremony transaction factory issues separate NanoID references" do
    generated = ["a" * 21, "b" * 21]
    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        ClientTotpCeremonyTransaction.create_transaction!(
          actor_ref: "historical-subject", session_ref: "historical-session", operation: "registration",
        )
      end

    assert_equal "a" * 21, transaction.transaction_id
    assert_equal "b" * 21, transaction.grant_jti
    assert_not_equal transaction.transaction_id, transaction.grant_jti
  end
end
