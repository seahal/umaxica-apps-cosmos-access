# typed: false
# frozen_string_literal: true

require "test_helper"

# Expired authorization transactions are removed once their retention has passed
# (specs/sign-fqdn-integrated-plan/plan.md section 5). BVA at the cutoff, now - RETENTION_PERIOD:
# one microsecond before and exactly at the cutoff are removed, one microsecond after is kept.
class OidcAuthorizationTransactionPurgerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SURFACES = {
    "app" => { model: ClientOidcAuthorizationTransaction, client_id: "core-app-jp", realm: "client" },
    "org" => { model: OperatorOidcAuthorizationTransaction, client_id: "core-org-jp", realm: "operator" },
  }.freeze

  test "removes transactions expired at or before the retention cutoff and keeps later ones" do
    now = Time.current.change(usec: 0)
    cutoff = now - OidcAuthorizationTransactionable::RETENTION_PERIOD
    # The global collector must see only this case's eligible disposable test rows.
    [ClientOidcAuthorizationTransaction, OperatorOidcAuthorizationTransaction].each do |model|
      model.update_all(expires_at: now + 10.years)
    end

    SURFACES.each do |surface, config|
      client = OidcClientRegistry.find!(config.fetch(:client_id))
      transactions =
        { before: Rational(-1, 1_000_000), at: 0, after: Rational(1, 1_000_000) }.to_h do |label, offset|
          issued = OidcAuthorizationTransactionCoordinator.issue!(
            surface: surface,
            intent: "sign_in",
            params: {
              response_type: "code",
              client_id: client.client_id,
              redirect_uri: client.redirect_uris_by_realm.fetch(config.fetch(:realm)).first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: "state-#{label}",
              nonce: "nonce-#{label}",
              scope: "openid",
            },
          ).transaction
          issued.update_columns(expires_at: cutoff + offset)
          [label, issued]
        end

      counts = OidcAuthorizationTransactionPurger.call(now: now)

      assert_equal %w(app org), counts.keys
      assert_equal 2, counts.fetch(surface)
      assert_not config.fetch(:model).exists?(transactions.fetch(:before).id), "#{surface} before cutoff"
      assert_not config.fetch(:model).exists?(transactions.fetch(:at).id), "#{surface} at cutoff"
      assert config.fetch(:model).exists?(transactions.fetch(:after).id), "#{surface} after cutoff"
    end
  end

  test "keeps a live transaction" do
    client = OidcClientRegistry.find!("core-app-jp")
    live = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: "state-live",
        nonce: "nonce-live",
        scope: "openid",
      },
    ).transaction

    OidcAuthorizationTransactionPurger.call

    assert ClientOidcAuthorizationTransaction.exists?(live.id)
  end

  test "Governance-dependent APP history is retained while independent APP and ORG collection completes" do
    now = Time.current.change(usec: 0)
    flow_id = ClientSignInFlow.insert_all!(
      [{ public_id: PublicId.generate,
         principal_id: 9_600_001,
         nonce_digest: Digest::SHA256.hexdigest("retained-flow"),
         state_id: ClientSignInFlow.state_id_for("PRIMARY_PENDING"),
         issued_at: now - 2.hours,
         expires_at: now - 1.hour,
         created_at: now - 2.hours,
         updated_at: now - 2.hours, }],
    ).rows.first.first
    rows = {}
    %w(held app org).each do |label|
      surface = (label == "org") ? "org" : "app"
      config = SURFACES.fetch(surface)
      client = OidcClientRegistry.find!(config.fetch(:client_id))
      row = OidcAuthorizationTransactionCoordinator.issue!(
        surface:, intent: "sign_in", now: now - 2.hours,
        params: {
          response_type: "code",
          client_id: client.client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch(config.fetch(:realm)).first,
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          state: "retention-#{label}",
          nonce: "nonce-#{label}",
          scope: "openid",
        },
      ).transaction
      row.update!(secret_sign_in_flow_id: flow_id) if label == "held"
      rows[label] = row
    end
    # These SQL inserts represent retained pre-cutover evidence; new receipt issuance requires Governance.
    receipt_id = ClientSecretSignInReceipt.insert_all!(
      [{ operation_id: SecureRandom.uuid,
         client_ref: PublicId.generate,
         credential_ref: PublicId.generate,
         sign_in_flow_id: flow_id,
         root_token_ref: PublicId.generate,
         committed_at: now - 1.hour,
         created_at: now - 1.hour,
         updated_at: now - 1.hour, }],
    ).rows.first.first
    resolution_id = ClientSessionLimitResolutionTransaction.insert_all!(
      [{ actor_ref: "retained-principal",
         sign_in_flow_id: flow_id,
         oidc_authorization_transaction_id: rows.fetch("held").id,
         challenge_digest: Digest::SHA256.hexdigest("retained-resolution"),
         browser_binding_digest: Digest::SHA256.hexdigest("retained-browser"),
         state_id: ClientSessionLimitResolutionTransaction::CANCELLED,
         started_at: now - 2.hours,
         expires_at: now - 1.hour,
         cancelled_at: now - 1.hour,
         created_at: now - 2.hours,
         updated_at: now - 1.hour, }],
    ).rows.first.first
    before = [rows.fetch("held").reload.attributes, ClientSignInFlow.find(flow_id).attributes,
              ClientSecretSignInReceipt.find(receipt_id).attributes,
              ClientSessionLimitResolutionTransaction.find(resolution_id).attributes,]

    error = assert_raises(GovernanceLookupUnavailableError) { OidcAuthorizationTransactionPurger.call(now:) }

    assert_equal "Governance credential-claim retention verification is unavailable", error.message
    assert_equal before, [rows.fetch("held").reload.attributes, ClientSignInFlow.find(flow_id).attributes,
                          ClientSecretSignInReceipt.find(receipt_id).attributes,
                          ClientSessionLimitResolutionTransaction.find(resolution_id).attributes,]
    assert_not ClientOidcAuthorizationTransaction.exists?(rows.fetch("app").id)
    assert_not OperatorOidcAuthorizationTransaction.exists?(rows.fetch("org").id)
  end

  test "invalid retention periods are refused before any history can be collected" do
    [nil, "15 minutes", 0, -1, Float::INFINITY, Float::NAN, 0.seconds, (-1).second].each do |period|
      before = [ClientOidcAuthorizationTransaction.count, OperatorOidcAuthorizationTransaction.count]

      assert_raises(ArgumentError) { OidcAuthorizationTransactionPurger.call(retention_period: period) }
      assert_equal before, [ClientOidcAuthorizationTransaction.count, OperatorOidcAuthorizationTransaction.count]
    end
  end

  test "local resolution retention holds open and unresolved continuations and collects terminal children first" do
    now = Time.current.change(usec: 0)
    # Existing test rows are retained beyond this case's clock and restored by the framework transaction.
    [ClientOidcAuthorizationTransaction, OperatorOidcAuthorizationTransaction].each do |model|
      model.update_all(expires_at: now + 10.years)
    end
    [["app", ClientSignInFlow, ClientSessionLimitResolutionTransaction],
     ["org", OperatorSignInFlow, OperatorSessionLimitResolutionTransaction],].each do |surface, flow_model, resolutions|
      config = SURFACES.fetch(surface)
      client = OidcClientRegistry.find!(config.fetch(:client_id))
      history = {}
      [resolutions::PENDING, resolutions::CANCELLED, resolutions::RESOLVED].each do |state|
        flow_id = flow_model.insert_all!(
          [{ public_id: PublicId.generate,
             principal_id: 9_600_003,
             nonce_digest: Digest::SHA256.hexdigest("local-#{surface}-#{state}"),
             state_id: flow_model.state_id_for("PRIMARY_PENDING"),
             issued_at: now - 2.hours,
             expires_at: now - 1.hour,
             created_at: now - 2.hours,
             updated_at: now - 2.hours, }],
        ).rows.first.first
        parent = OidcAuthorizationTransactionCoordinator.issue!(
          surface:, intent: "sign_in", now: now - 2.hours,
          params: {
            response_type: "code",
            client_id: client.client_id,
            redirect_uri: client.redirect_uris_by_realm.fetch(config.fetch(:realm)).first,
            code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
            code_challenge_method: "S256",
            state: "local-#{surface}-#{state}",
            nonce: "nonce-#{state}",
            scope: "openid",
          },
        ).transaction
        terminal_attributes = {
          resolutions::PENDING => { waiting_slot: 1 },
          resolutions::CANCELLED => { cancelled_at: now - 1.hour },
          resolutions::RESOLVED => { resolved_at: now - 1.hour },
        }.fetch(state)
        resolution_id = resolutions.insert_all!(
          [{ actor_ref: "local-#{surface}-#{state}",
             sign_in_flow_id: flow_id,
             oidc_authorization_transaction_id: parent.id,
             challenge_digest: Digest::SHA256.hexdigest("local-resolution-#{surface}-#{state}"),
             browser_binding_digest: Digest::SHA256.hexdigest("local-browser-#{surface}-#{state}"),
             state_id: state,
             started_at: now - 2.hours,
             expires_at: now - 1.hour,
             created_at: now - 2.hours,
             updated_at: now - 1.hour,
             **terminal_attributes, }],
        ).rows.first.first
        history[state] = [parent, resolutions.find(resolution_id)]
      end

      counts = OidcAuthorizationTransactionPurger.call(now:)

      assert_equal 1, counts.fetch(surface)
      [resolutions::PENDING, resolutions::RESOLVED].each do |state|
        parent, resolution = history.fetch(state)

        assert config.fetch(:model).exists?(parent.id)
        assert resolutions.exists?(resolution.id)
        assert_equal state, resolution.reload.state_id
      end
      parent, resolution = history.fetch(resolutions::CANCELLED)

      assert_not config.fetch(:model).exists?(parent.id)
      assert_not resolutions.exists?(resolution.id)
    end
  end
end
