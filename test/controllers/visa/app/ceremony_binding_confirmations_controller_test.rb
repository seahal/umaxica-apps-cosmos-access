# frozen_string_literal: true

require "test_helper"

class Visa::App::CeremonyBindingConfirmationsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  setup do
    @visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    @auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    ClientTotpCredential.create_for_user!(
      user: @actor,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    @token = ClientToken.create!(
      authentication_epoch: 0,
      user: @actor,
      root_login_established_at: ClientToken.database_now,
    )
    @client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: @token.authentication_epoch,
      client_token: @token,
      oidc_client_id: @client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour,
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    @authorization_params = {
      response_type: "code",
      client_id: @client.client_id,
      redirect_uri: @client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("visa-step-up-confirmation"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(
      params: @authorization_params,
      resource: @actor,
      resource_type: "client",
    )
    @issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app",
      actor: @actor,
      token: @token,
      client: @client,
      params: @authorization_params,
      validated_request:,
    )
    @step_up_transaction = @issuance.ticket
    @binding = ClientAuthAdmissionBinding.find_by!(entry_ref: @issuance.entry_ref)
    @auth_session, = ClientAuthCeremonySession.issue!
    @binding.attach_auth_session!(auth_session: @auth_session, confirmation_ref: SecureRandom.uuid)
    @visa_access_token = AuthenticationToken.encode(
      @actor,
      host: @visa_host,
      session_public_id: @token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:VISA_APP",
    )
    @confirmation_path = visa_app_ceremony_binding_confirmation_path(
      binding_ref: @binding.confirmation_ref,
      ri: "jp",
    )

    host! @visa_host
    https!
    get "/health"
    set_browser_nonce_cookie(@issuance.authorization_transaction.login_challenge)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = @visa_access_token
  end

  test "step-up confirmation succeeds only in the matching user's OP session" do
    get @confirmation_path, headers: NAVIGATION_HEADERS

    assert_response :see_other
    assert_predicate @binding.reload, :confirmed?
    assert_equal @auth_host, URI.parse(response.location).host
    assert_equal auth_app_verification_path(ri: "jp", entry_ref: @issuance.entry_ref),
                 URI.parse(response.location).request_uri
    assert_equal [@token.id, @actor.public_id], [@binding.base_token_id, @step_up_transaction.reload.actor_ref]
  end

  test "step-up confirmation refuses another user's OP session without confirming the binding" do
    other_actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    other_token = ClientToken.create!(
      authentication_epoch: 0,
      user: other_actor,
      root_login_established_at: ClientToken.database_now,
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      other_actor,
      host: @visa_host,
      session_public_id: other_token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:VISA_APP",
    )

    get @confirmation_path, headers: NAVIGATION_HEADERS

    assert_response :bad_request
    assert_not_predicate @binding.reload, :confirmed?
    assert_nil @binding.base_confirmed_at
  end

  test "step-up confirmation refuses an expired binding" do
    ClientAuthAdmissionBinding.stub(:database_now, @binding.expires_at) do
      get @confirmation_path, headers: NAVIGATION_HEADERS
    end

    assert_response :bad_request
    assert_nil @binding.reload.base_confirmed_at
  end

  test "step-up confirmation refuses a redeemed binding replay" do
    get @confirmation_path, headers: NAVIGATION_HEADERS

    assert_response :see_other
    admitted_session, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff",
      step_up_ceremony_transaction_ref: @step_up_transaction.transaction_id,
    )
    @binding.reload.redeem!(auth_session: @auth_session, admitted_auth_session: admitted_session)

    get @confirmation_path, headers: NAVIGATION_HEADERS

    assert_response :bad_request
    assert_predicate @binding.reload, :redeemed?
  end

  test "authorization and step-up bindings are confirmed against their own parent purposes" do
    assert_equal :step_up_ceremony_transaction, @binding.parent_kind
    assert_equal @step_up_transaction.id, @binding.step_up_ceremony_transaction_id
    assert_nil @binding.authorization_transaction_id

    authorization_nonce = SecureRandom.urlsafe_base64(32)
    authorization_transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        client_id: @client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: @client.redirect_uris_by_realm.fetch("client").first,
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
        code_challenge: Base64.urlsafe_encode64(
          Digest::SHA256.digest("visa-authorization-confirmation"), padding: false,
        ),
        code_challenge_method: "S256",
      },
    ).transaction
    authorization_issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: authorization_transaction,
      base_browser_nonce: authorization_nonce,
      base_token: nil,
    )
    authorization_binding = ClientAuthAdmissionBinding.find_by!(entry_ref: authorization_issuance.reference)
    authorization_session, = ClientAuthCeremonySession.issue!
    authorization_binding.attach_auth_session!(
      auth_session: authorization_session,
      confirmation_ref: SecureRandom.uuid,
    )
    set_browser_nonce_cookie(authorization_nonce)
    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
    authorization_confirmation_path = visa_app_ceremony_binding_confirmation_path(
      binding_ref: authorization_binding.confirmation_ref,
      ri: "jp",
    )

    get authorization_confirmation_path, headers: NAVIGATION_HEADERS

    assert_response :see_other
    assert_predicate authorization_binding.reload, :confirmed?
    assert_equal :authorization_transaction, authorization_binding.parent_kind
    assert_equal authorization_transaction.id, authorization_binding.authorization_transaction_id
    assert_nil authorization_binding.step_up_ceremony_transaction_id
    assert_predicate authorization_transaction.reload, :pending?
  end

  private

  def set_browser_nonce_cookie(nonce)
    continuity = {
      "session_id" => SecureRandom.hex(16),
      "_csrf_token" => SecureRandom.urlsafe_base64(32),
      BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY => nonce,
    }
    cookie_request = ActionDispatch::TestRequest.create
    jar = ActionDispatch::Cookies::CookieJar.build(cookie_request, {})
    session_key = Rails.application.config.session_options.fetch(:key)
    jar.encrypted[session_key] = { value: continuity }
    store_raw_cookies(
      cookies, "#{session_key}=#{Rack::Utils.escape(jar[session_key])}", URI.parse("https://#{@visa_host}/"),
    )
  end
end
