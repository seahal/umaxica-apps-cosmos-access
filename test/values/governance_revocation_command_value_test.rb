# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../app/values/governance_revocation_command_value"

class GovernanceRevocationCommandValueTest < Minitest::Test
  def test_realm_and_scope_are_exact_and_snapshot_excludes_transport_expiry
    payload = {
      "iss" => "https://governance.example",
      "aud" => "https://visa.example",
      "iat" => 1_000,
      "exp" => 1_060,
      "jti" => "11111111-1111-4111-8111-111111111111",
      "realm" => "app",
      "sub" => "cli_existing-principal",
      "scope" => "all_sessions",
      "actor" => "opr_authorizing-operator",
      "reason" => "account_disabled",
    }
    command = GovernanceRevocationCommandValue.new(
      payload:, realm: "app", issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.at(1_000).utc,
    )

    assert_equal "existing-principal", command.principal_public_id
    assert_equal "all_sessions", command.scope
    assert_equal 32, command.digest.bytesize
    assert_equal %w(actor realm reason scope sub), command.snapshot.keys.sort

    retry_payload = payload.merge("iat" => 1_030, "exp" => 1_090)
    retry_command = GovernanceRevocationCommandValue.new(
      payload: retry_payload, realm: "app", issuer: payload.fetch("iss"),
      audience: payload.fetch("aud"), now: Time.at(1_030).utc,
    )

    assert_equal command.digest, retry_command.digest
    assert_predicate command.snapshot, :frozen?
  end

  def test_missing_empty_wrong_realm_unknown_fields_and_scope_target_conflicts_are_refused
    payload = {
      "iss" => "https://governance.example",
      "aud" => "https://visa.example",
      "iat" => 1_000,
      "exp" => 1_060,
      "jti" => "11111111-1111-4111-8111-111111111111",
      "realm" => "app",
      "sub" => "cli_existing-principal",
      "scope" => "all_sessions",
      "actor" => "opr_authorizing-operator",
      "reason" => "account_disabled",
    }
    invalid = [
      nil, {}, payload.merge("iss" => ""), payload.merge("aud" => "https://other.example"),
      payload.merge("realm" => "org"), payload.merge("sub" => "opr_existing-principal"),
      payload.merge("sub" => "cli_"), payload.merge("sub" => "cli_bad principal"),
      payload.merge("actor" => ""), payload.merge("actor" => "invented_actor"),
      payload.merge("reason" => ""), payload.merge("reason" => "free form reason"),
      payload.merge("scope" => "unknown"), payload.merge("scope" => "session"),
      payload.merge("session_public_id" => "x" * 21), payload.merge("unexpected" => true),
      payload.merge("jti" => ""), payload.merge("jti" => "not-a-uuid"),
      payload.merge("iat" => "1000"), payload.merge("exp" => nil),
    ]

    invalid.each do |candidate|
      assert_raises(GovernanceRevocationCommandValue::Invalid) do
        GovernanceRevocationCommandValue.new(
          payload: candidate, realm: "app", issuer: payload.fetch("iss"),
          audience: payload.fetch("aud"), now: Time.at(1_000).utc,
        )
      end
    end
  end

  def test_lifetime_clock_skew_identifier_and_reason_boundaries
    payload = {
      "iss" => "https://governance.example",
      "aud" => "https://visa.example",
      "iat" => 1_000,
      "exp" => 1_060,
      "jti" => "11111111-1111-4111-8111-111111111111",
      "realm" => "org",
      "sub" => "opr_existing-principal",
      "scope" => "session",
      "session_public_id" => "x" * 21,
      "actor" => "opr_authorizing-operator",
      "reason" => "account_disabled",
    }
    [
      ["exp", 999, false], ["exp", 1_000, false], ["exp", 1_001, true],
      ["exp", 1_059, true], ["exp", 1_060, true], ["exp", 1_061, false],
      ["iat", 1_004, true], ["iat", 1_005, true], ["iat", 1_006, false],
      ["session_public_id", "x" * 20, false], ["session_public_id", "x" * 21, true],
      ["session_public_id", "x" * 22, false],
      ["reason", "a" * 63, true], ["reason", "a" * 64, true], ["reason", "a" * 65, false],
      ["sub", "opr_#{"x" * 254}", true], ["sub", "opr_#{"x" * 255}", true],
      ["sub", "opr_#{"x" * 256}", false],
      ["actor", "cli_#{"x" * 254}", true], ["actor", "opr_#{"x" * 255}", true],
      ["actor", "opr_#{"x" * 256}", false],
    ].each do |key, value, accepted|
      candidate = payload.merge(key => value)
      if accepted
        command = GovernanceRevocationCommandValue.new(
          payload: candidate, realm: "org", issuer: payload.fetch("iss"),
          audience: payload.fetch("aud"), now: Time.at(1_000).utc,
        )

        assert_equal candidate.fetch(key), command.payload.fetch(key)
      else
        assert_raises(GovernanceRevocationCommandValue::Invalid) do
          GovernanceRevocationCommandValue.new(
            payload: candidate, realm: "org", issuer: payload.fetch("iss"),
            audience: payload.fetch("aud"), now: Time.at(1_000).utc,
          )
        end
      end
    end
  end

  def test_expiry_accepts_the_last_clock_skew_second_and_refuses_the_next_second
    payload = {
      "iss" => "https://governance.example",
      "aud" => "https://visa.example",
      "iat" => 1_000,
      "exp" => 1_060,
      "jti" => "11111111-1111-4111-8111-111111111111",
      "realm" => "org",
      "sub" => "opr_existing-principal",
      "scope" => "session",
      "session_public_id" => "x" * 21,
      "actor" => "opr_authorizing-operator",
      "reason" => "account_disabled",
    }
    [1_063, 1_064, 1_065].zip([true, true, false]).each do |now, accepted|
      if accepted
        command = GovernanceRevocationCommandValue.new(
          payload:, realm: "org", issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.at(now).utc,
        )

        assert_equal "session", command.scope
      else
        assert_raises(GovernanceRevocationCommandValue::Invalid) do
          GovernanceRevocationCommandValue.new(
            payload:, realm: "org", issuer: payload.fetch("iss"), audience: payload.fetch("aud"), now: Time.at(now).utc,
          )
        end
      end
    end
  end
end
