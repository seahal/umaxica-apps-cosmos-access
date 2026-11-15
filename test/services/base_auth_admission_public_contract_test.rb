# frozen_string_literal: true

require "test_helper"

class BaseAuthAdmissionPublicContractTest < ActiveSupport::TestCase
  test "ceremony session lookup preserves the app and org authority classes" do
    assert_equal ClientAuthCeremonySession, BaseAuthAdmissionCoordinator.ceremony_session_class("app")
    assert_equal OperatorAuthCeremonySession, BaseAuthAdmissionCoordinator.ceremony_session_class("org")
    assert_raises(KeyError) { BaseAuthAdmissionCoordinator.ceremony_session_class("com") }
  end

  test "binding proof detection treats any recognized symbol or string key as client supplied" do
    assert_not BaseAuthAdmissionCoordinator.client_supplied_binding_proof?({})
    assert BaseAuthAdmissionCoordinator.client_supplied_binding_proof?("auth_sid" => nil)
    assert BaseAuthAdmissionCoordinator.client_supplied_binding_proof?(purpose: "sign_in")
    assert_not BaseAuthAdmissionCoordinator.client_supplied_binding_proof?("unrelated" => "value")
  end

  test "cancellation handoff digest commits to the complete encrypted handoff value" do
    handoff = "encrypted-cancellation-handoff"
    digest = BaseAuthAdmissionCoordinator.cancellation_handoff_digest(handoff)

    assert_match(/\A[0-9a-f]{64}\z/, digest)
    assert_equal Digest::SHA256.hexdigest("cancellation-handoff:#{handoff}"), digest
    assert_raises(ArgumentError) { BaseAuthAdmissionCoordinator.cancellation_handoff_digest(nil) }
    assert_raises(ArgumentError) { BaseAuthAdmissionCoordinator.cancellation_handoff_digest("") }
  end

  test "unsupported or unbound admission requests fail before accessing another trust boundary" do
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
        payload: {}, surface: "app", expected_intent: "authentication",
      )
    end
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.issue_switch_admission!(
        transaction: nil, source_auth_session: nil, base_browser_nonce: nil, base_token: nil, target: "org",
        store: nil,
      )
    end
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.validate_registration_restart_browser!(
        binding: Object.new, surface: "app", base_browser_nonce: "nonce", base_token: nil,
        scope: "settings_email", method: "passkey",
      )
    end
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.read_result!(
        raw_code: nil, surface: "app", transaction_ref: "", expected_intent: "sign_in", store: nil,
      )
    end
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.read_result_reference!(
        reference: "", surface: "app", transaction_ref: "", expected_intent: "sign_in", store: nil,
      )
    end
  end

  test "malformed signed handoffs cannot reach cancellation or switch state" do
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.read_cancellation_handoff!(
        handoff: "", surface: "app", transaction_ref: SecureRandom.uuid, store: nil,
      )
    end
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.read_authorization_cancellation_handoff!(
        handoff: "", surface: "app", transaction_ref: SecureRandom.uuid, store: nil,
      )
    end
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.read_switch_handoff!(handoff: nil, surface: "app")
    end
  end

  test "cancellation handoffs are issued, bound to the step-up, and consumed from their own realm" do
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "client-public-id", session_ref: "client-session-id", required_scope: "settings_passkey",
      required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
    )
    suite = "suite-#{SecureRandom.hex(8)}"
    namespace = Umaxica::Valkey::Namespaces.admission(
      suite_run_id: suite,
      worker_id: "w0",
      test_id: name,
    )
    connection = Umaxica::Valkey::Connection.new(
      url: Umaxica::Valkey::Settings.current.auth_state.url,
      namespace: namespace,
    )
    store = Valkey::AuthState::OpaqueAdmissionStore.new(connection: connection)

    begin
      issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(transaction:, store:)

      assert_equal transaction.transaction_id, issuance.transaction.transaction_id
      assert_match(AuthAdmissionBinding::REFERENCE_PATTERN, issuance.reference)
      assert_predicate issuance.handoff, :present?
      assert_equal issuance.reference, transaction.reload.cancellation_handoff_ref
      assert_equal issuance.handoff, transaction.cancellation_handoff_ciphertext
      assert_equal "pending", transaction.status

      consumed = BaseAuthAdmissionCoordinator.read_cancellation_handoff!(
        handoff: issuance.handoff,
        surface: "app",
        transaction_ref: transaction.transaction_id,
        store:,
      )

      assert_equal transaction.transaction_id, consumed.transaction_id
      assert_equal "pending", transaction.reload.status
    ensure
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "#{namespace}:")
      Umaxica::Valkey::Cleanup.ensure_empty!(connection, prefix: "#{namespace}:")
      connection.close
    end
  end

  test "expired step-up cancellation is refused before reaching the admission store" do
    now = ClientStepUpCeremonyTransaction.database_now
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "client-public-id", session_ref: "client-session-id", required_scope: "settings_passkey",
      required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up", now: now - 16.minutes,
    )

    error =
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseAuthAdmissionCoordinator.issue_cancellation!(transaction:, store: nil)
      end

    assert_equal "transaction_unavailable", error.code
    assert_equal "pending", transaction.reload.status
    assert_nil transaction.cancellation_handoff_ref
    assert_nil transaction.cancellation_handoff_ciphertext
  end

  test "cancellation preparation cannot be committed against a different transaction" do
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "client-public-id", session_ref: "client-session-id", required_scope: "settings_passkey",
      required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
    )
    preparation = BaseAuthAdmissionCoordinator::CancellationPreparation.new(
      transaction_ref: "another-transaction",
      surface: "app",
      reference: SecureRandom.uuid,
      handoff: "encrypted-handoff",
    )

    error =
      assert_raises(ArgumentError) do
        BaseAuthAdmissionCoordinator.commit_cancellation!(transaction:, preparation:)
      end

    assert_equal "cancellation preparation binding mismatch", error.message
    assert_equal "pending", transaction.reload.status
    assert_nil transaction.cancellation_handoff_ref
  end

  test "switch admission accepts only an available neutral app authorization" do
    now = ClientOidcAuthorizationTransaction.database_now
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "authentication",
      params: {
        client_id: "rp-client-id",
        redirect_uri: "https://rp.example/callback",
        response_type: "code",
        scope: "openid",
        state: "state-reference",
        nonce: "nonce-reference",
        code_challenge: "A" * 43,
        code_challenge_method: "S256",
      },
      login_challenge: "switchable-login-challenge",
      now:,
    )

    assert_nil BaseAuthAdmissionCoordinator.validate_switch_request!(
      transaction: issuance.transaction,
      target: "sign_in",
    )
    error =
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseAuthAdmissionCoordinator.validate_switch_request!(
          transaction: issuance.transaction,
          target: "org",
        )
      end
    assert_equal "invalid_admission", error.code
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.issue_switch_handoff!(
        transaction: issuance.transaction,
        ceremony_session: nil,
        target: "org",
      )
    end
    assert_predicate issuance.transaction.reload, :pending?
  end

  test "result issuance refuses a parent before authentication without changing it" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "authentication",
      params: {
        client_id: "rp-client-id",
        redirect_uri: "https://rp.example/callback",
        response_type: "code",
        scope: "openid",
        state: "state-reference",
        nonce: "nonce-reference",
        code_challenge: "B" * 43,
        code_challenge_method: "S256",
      },
      login_challenge: "unauthenticated-login-challenge",
    )

    error =
      assert_raises(ArgumentError) do
        BaseAuthAdmissionCoordinator.issue_result!(transaction: issuance.transaction, store: nil)
      end

    assert_equal "authorization transaction is not authenticated", error.message
    assert_predicate issuance.transaction.reload, :pending?
    assert_nil issuance.transaction.result_digest
    assert_equal 0, issuance.transaction.result_generation
  end

  test "reusing an authenticated parent refuses a different actor before result issuance" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "authentication",
      params: {
        client_id: "rp-client-id",
        redirect_uri: "https://rp.example/callback",
        response_type: "code",
        scope: "openid",
        state: "state-reference",
        nonce: "nonce-reference",
        code_challenge: "C" * 43,
        code_challenge_method: "S256",
      },
      login_challenge: "authenticated-login-challenge",
    )
    authenticated = issuance.transaction.register_authentication!(
      actor_ref: "original-actor",
      session_ref: "original-session",
      auth_method: "passkey",
      acr: "aal1",
      authentication_event_at: ClientOidcAuthorizationTransaction.database_now,
    )

    error =
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseAuthAdmissionCoordinator.register_result_and_issue!(
          surface: "app",
          login_challenge: authenticated.login_challenge,
          actor: Data.define(:public_id).new("different-actor"),
          session_ref: "different-session",
          auth_method: "passkey",
          store: nil,
        )
      end

    assert_equal "session_binding_mismatch", error.code
    assert_equal "original-actor", authenticated.reload.actor_ref
    assert_nil authenticated.result_digest
  end
end
