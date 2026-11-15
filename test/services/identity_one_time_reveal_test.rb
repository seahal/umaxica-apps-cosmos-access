# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityOneTimeRevealTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    client_tokens client_device_sessions client_token_kinds client_token_statuses
    client_token_binding_methods client_token_dbsc_statuses
  )

  setup do
    @actor = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    @session_nonce = "one-time-reveal-session-nonce"
    @operation_ref = "credential-operation-#{SecureRandom.uuid}"
  end

  test "issue and resume return the exact delivery token only for its bound operation" do
    issued = IdentityOneTimeReveal.issue!(
      actor: @actor,
      session_nonce: @session_nonce,
      value: "recovery-code",
      purpose: "client.recovery_code",
      metadata: { "delivery_operation_ref" => @operation_ref, "channel" => "email" },
    )

    resumed = IdentityOneTimeReveal.resume_for_operation!(
      actor: @actor,
      session_nonce: @session_nonce,
      purpose: "client.recovery_code",
      operation_ref: @operation_ref,
    )

    assert_equal issued.token, resumed.token
    assert_equal issued.expires_at, resumed.expires_at
    assert_nil IdentityOneTimeReveal.resume_for_operation!(
      actor: @actor,
      session_nonce: @session_nonce,
      purpose: "client.recovery_code",
      operation_ref: "another-operation",
    )
  end

  test "consume returns the protected value once and never releases server-owned delivery metadata" do
    issued = IdentityOneTimeReveal.issue!(
      actor: @actor,
      session_nonce: @session_nonce,
      value: "one-time-secret",
      purpose: "client.recovery_code",
      metadata: {
        "delivery_operation_ref" => @operation_ref,
        "channel" => "email",
        "delivery_address" => "owner@example.test",
      },
    )

    payload = IdentityOneTimeReveal.consume!(
      actor: @actor,
      session_nonce: @session_nonce,
      token: issued.token,
      purpose: "client.recovery_code",
    )

    assert_equal "one-time-secret", payload.value
    assert_equal({ "channel" => "email", "delivery_address" => "owner@example.test" }, payload.metadata)
    assert_nil IdentityOneTimeReveal.consume!(
      actor: @actor,
      session_nonce: @session_nonce,
      token: issued.token,
      purpose: "client.recovery_code",
    )
  end

  test "issue rejects missing identity context and consume refuses a different session nonce" do
    assert_raises(ArgumentError) do
      IdentityOneTimeReveal.issue!(
        actor: @actor,
        session_nonce: "",
        value: "secret",
        purpose: "client.recovery_code",
      )
    end

    issued = IdentityOneTimeReveal.issue!(
      actor: @actor,
      session_nonce: @session_nonce,
      value: "bound-secret",
      purpose: "client.recovery_code",
    )

    assert_nil IdentityOneTimeReveal.consume!(
      actor: @actor,
      session_nonce: "another-session-nonce",
      token: issued.token,
      purpose: "client.recovery_code",
    )
  end
end
