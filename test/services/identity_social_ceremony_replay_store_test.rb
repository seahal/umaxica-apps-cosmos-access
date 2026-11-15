# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySocialCeremonyReplayStoreTest < ActiveSupport::TestCase
  test "creates and finds an app social transaction" do
    store = IdentitySocialCeremonyReplayStore.for(:app)
    transaction = store.create_transaction!(
      actor_ref: "actor-social-store",
      session_ref: "session-social-store",
      operation: "link",
      provider: "google",
    )

    assert_equal transaction, store.find_transaction!(transaction.transaction_id)
  end

  test "rejects an unsupported surface and translates a missing transaction" do
    assert_raises(IdentitySocialCeremonyContract::Error) do
      IdentitySocialCeremonyReplayStore.for(:org)
    end

    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyReplayStore.for(:app).find_transaction!("missing-social-transaction")
      end
    assert_equal "transaction is not found", error.message
  end
end
