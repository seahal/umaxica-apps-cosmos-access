# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationTransactionPurgeJobTest < ActiveJob::TestCase
  self.fixture_table_names = []
  test "uses the isolated retention queue" do
    assert_equal "retention", OidcAuthorizationTransactionPurgeJob.queue_name
  end

  test "removes an authorization transaction past its retention and keeps a live one" do
    client = OidcClientRegistry.find!("core-app-jp")
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      nonce: "nonce",
      scope: "openid",
    }
    expired = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: params.merge(state: "expired"),
    ).transaction
    expired.update_columns(expires_at: 1.hour.ago)
    live = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: params.merge(state: "live"),
    ).transaction

    OidcAuthorizationTransactionPurgeJob.perform_now

    assert_not ClientOidcAuthorizationTransaction.exists?(expired.id)
    assert ClientOidcAuthorizationTransaction.exists?(live.id)
  end

  test "the scheduled job exposes a Governance hold and preserves retained authorization history" do
    now = Time.current.change(usec: 0)
    flow_id = ClientSignInFlow.insert_all!(
      [{ public_id: PublicId.generate,
         principal_id: 9_600_002,
         nonce_digest: Digest::SHA256.hexdigest("scheduled-retained-flow"),
         state_id: ClientSignInFlow.state_id_for("PRIMARY_PENDING"),
         issued_at: now - 2.hours,
         expires_at: now - 1.hour,
         created_at: now - 2.hours,
         updated_at: now - 2.hours, }],
    ).rows.first.first
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", now: now - 2.hours,
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: "scheduled-retention",
        nonce: "scheduled-nonce",
        scope: "openid",
      },
    ).transaction
    transaction.update!(secret_sign_in_flow_id: flow_id)
    before = transaction.reload.attributes

    assert_raises(GovernanceLookupUnavailableError) { OidcAuthorizationTransactionPurgeJob.perform_now }
    assert_equal before, transaction.reload.attributes
    assert ClientSignInFlow.exists?(flow_id)
  end
end
