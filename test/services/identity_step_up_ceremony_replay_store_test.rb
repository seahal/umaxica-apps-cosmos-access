# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityStepUpCeremonyReplayStoreTest < ActiveSupport::TestCase
  test "for returns a store for each known surface" do
    assert_kind_of IdentityStepUpCeremonyReplayStore, IdentityStepUpCeremonyReplayStore.for(:app)
    assert_kind_of IdentityStepUpCeremonyReplayStore, IdentityStepUpCeremonyReplayStore.for(:org)
  end

  test "for raises when the surface is invalid" do
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyReplayStore.for(:invalid)
    end
  end

  test "creates, finds, and selects a pending app transaction by actor session and scope" do
    now = Time.current
    store = IdentityStepUpCeremonyReplayStore.for(:app)
    transaction = store.create_transaction!(
      actor_ref: "actor-step-up-store",
      session_ref: "session-step-up-store",
      required_scope: "profile.write",
      allowed_methods: %w(totp passkey),
      now: now,
    )

    assert_equal transaction, store.find_transaction!(transaction.transaction_id)
    assert_equal transaction, store.latest_pending_for(
      actor_ref: "actor-step-up-store",
      session_ref: "session-step-up-store",
      required_scope: "profile.write",
      now: now,
    )
    assert_not store.consumed?("not-yet-issued-result")
  end
end
