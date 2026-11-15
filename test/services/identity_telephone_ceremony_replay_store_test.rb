# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityTelephoneCeremonyReplayStoreTest < ActiveSupport::TestCase
  test "for returns a store for each known surface" do
    assert_kind_of IdentityTelephoneCeremonyReplayStore, IdentityTelephoneCeremonyReplayStore.for(:app)
    assert_kind_of IdentityTelephoneCeremonyReplayStore, IdentityTelephoneCeremonyReplayStore.for(:org)
  end

  test "for raises when the surface is invalid" do
    assert_raises(IdentityTelephoneCeremony::Error) do
      IdentityTelephoneCeremonyReplayStore.for(:invalid)
    end
  end

  test "creates, finds, and checks an app transaction by its result reference" do
    store = IdentityTelephoneCeremonyReplayStore.for(:app)
    transaction = store.create_transaction!(
      actor_ref: "actor-telephone-store",
      session_ref: "session-telephone-store",
      operation: "registration",
    )

    assert_equal transaction, store.find_transaction!(transaction.transaction_id)
    assert_not store.consumed?("not-yet-issued-result")
  end
end
