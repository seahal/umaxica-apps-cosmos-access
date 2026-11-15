# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationTransactionCoordinatorPublicContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "transaction lookup preserves a pending transaction and consumption refuses it" do
    now = ClientOidcAuthorizationTransaction.database_now
    params = {
      client_id: "rp-client-id",
      redirect_uri: "https://rp.example/callback",
      response_type: "code",
      scope: "openid",
      state: "state-reference",
      nonce: "nonce-reference",
      code_challenge: "A" * 43,
      code_challenge_method: "S256",
    }
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "authentication",
      params:,
      login_challenge: "login-challenge-reference",
      now:,
    )

    found = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: "app",
      transaction_id: issuance.transaction.transaction_id,
    )

    assert_equal issuance.transaction, found
    error =
      assert_raises(ArgumentError) do
        OidcAuthorizationTransactionCoordinator.consume!(
          surface: "app",
          login_challenge: "login-challenge-reference",
        )
      end
    assert_equal "authorization transaction is not authenticated", error.message
    assert_predicate found.reload, :pending?
    assert_nil found.consumed_at
  end

  test "result registration binds the actor and session to the live authorization transaction" do
    now = ClientOidcAuthorizationTransaction.database_now
    login_challenge = SecureRandom.urlsafe_base64(32)
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "authentication",
      params: {
        client_id: "rp-client-id",
        redirect_uri: "https://rp.example/callback",
        response_type: "code",
        scope: "openid",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
        code_challenge: "A" * 43,
        code_challenge_method: "S256",
      },
      login_challenge:,
      now:,
    )
    actor = Struct.new(:public_id).new("client-subject-reference")

    result = OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app",
      login_challenge:,
      actor:,
      session_ref: "session-reference",
      auth_method: "passkey",
      acr: "aal2",
      authentication_event_at: now,
    )

    assert_equal issuance.transaction.id, result.transaction.id
    assert_predicate result.transaction, :authenticated?
    assert_equal "client-subject-reference", result.transaction.actor_ref
    assert_equal "session-reference", result.transaction.session_ref
    assert_equal "passkey", result.transaction.auth_method
    assert_equal "aal2", result.transaction.acr
    assert_equal now, result.transaction.authenticated_at
  end
end
