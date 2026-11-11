# frozen_string_literal: true

require "test_helper"

class PublicMethodContractValuesTest < ActiveSupport::TestCase
  test "a blank public identifier error names its record without substituting an internal id" do
    error = BlankPublicIdentifierError.new(record_class: Client)

    assert_equal "Client", error.record_class
    assert_equal "Client has a blank public_id and cannot be exposed to a client", error.message
  end

  test "resource lifecycle predicates distinguish active and inactive state in every family" do
    active = AuthorityResourceLifecycleStateValue::ACTIVE
    inactive = AuthorityResourceLifecycleStateValue::INACTIVE
    lifecycles = [AgentLifecycle, BureauLifecycle, EnterpriseLifecycle]

    lifecycles.each do |lifecycle_class|
      assert_predicate lifecycle_class.new(state: active), :active?
      assert_not_predicate lifecycle_class.new(state: inactive), :active?
    end
  end

  test "persisted owner cutover markers are readonly in each owner family" do
    [AgentAuthorityCutover, BureauAuthorityCutover, EnterpriseAuthorityCutover].each do |cutover_class|
      cutover = cutover_class.establish!

      assert_predicate cutover, :readonly?, cutover_class.name
    end
  end



  test "passkey result candidate initializes metadata as an empty object by default" do
    candidate = IdentityPasskeyCeremonyResultIssuer::Candidate.new(
      webauthn_id: "credential-id",
      public_key: "public-key",
      sign_count: 0,
      description: "Security key",
      transports: ["internal"],
    )

    assert_equal({}, candidate.metadata)
  end

  test "social ceremony grant exposes its validated expiry as UTC time" do
    now = Time.current.change(usec: 0)
    expires_at = now + 5.minutes
    issuer_id = IdentitySocialCeremonyContract.acme_issuer_id("app")
    attributes = {
      surface: "app",
      actor_ref: "actor-reference",
      session_ref: "session-reference",
      transaction_id: "transaction-reference",
      jti: SecureRandom.uuid,
      operation: "link",
      provider: "google",
      exp: expires_at.to_i,
    }
    payload = attributes.merge(
      IdentitySocialCeremonyGrant.default_claims(attributes, issuer_id:, now:),
    )
    grant = IdentitySocialCeremonyGrant.new(payload, issuer_id:, now:)

    assert_equal Time.zone.at(expires_at.to_i), grant.expires_at
  end

  test "identifier inventory result serializes its stable public shape" do
    connections = [{ name: "primary", tables: [] }]
    result = IdentifierContractInventoryQuery::Result.new(
      version: IdentifierContractInventoryQuery::VERSION,
      generated_at: "2026-11-06T00:00:00Z",
      connections: connections,
    )

    assert_equal(
      { version: IdentifierContractInventoryQuery::VERSION, generated_at: "2026-11-06T00:00:00Z", connections: },
      result.to_h,
    )
    assert_equal result.to_h, JSON.parse(result.to_json, symbolize_names: true)
  end


end
