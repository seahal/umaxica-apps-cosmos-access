# frozen_string_literal: true

require "test_helper"

class SignUpPasskeyTerminationHttpTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "passkey signup actions refuse while retaining existing OP session and proof" do
    device = ClientDeviceSession.create!(user_id: 9_700_001, principal_public_id: "historical-subject")
    root = ClientToken.create!(user_id: 9_700_001, device_session: device, authentication_epoch: 0)
    proof = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: device.principal_public_id, session_ref: root.public_id, purpose: "credential_registration",
      required_scope: "settings_passkey", required_aal: "none", step_up_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      phishing_resistant_required: false, audience: "step_up:app", token_binding: root.public_id,
      require_session_binding: true, allowed_methods: ["passkey"],
    )
    before = [root.reload.attributes, device.reload.attributes, proof.reload.attributes]
    counts = [ClientToken.count, ClientDeviceSession.count, OpAppGrant.count]
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    payload = AuthorizationTokenClaims.build(
      resource: nil, subject: root.user_id.to_s, resource_type: "client", issued_at: Time.current,
      access_token_ttl: 60.seconds, session_public_id: device.public_id, oidc_jti: root.oidc_jti,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    cookies[AuthenticationCookieName.access] = JitSecurityJwtKeyring.encode(
      payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
               issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
    )
    path = "/sign/up/check/telephone/passkey"
    %i(get post patch delete).each do |verb|
      case verb
      when :get then get(path)
      when :post then post(path, params: { credential: "untrusted" })
      when :patch then patch(path, params: { credential: "untrusted" })
      when :delete then delete(path)
      end

      assert_response :service_unavailable
      assert_equal "Service unavailable", response.body
      assert_nil response.headers["Location"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_equal counts, [ClientToken.count, ClientDeviceSession.count, OpAppGrant.count]
      assert_equal before, [root.reload.attributes, device.reload.attributes, proof.reload.attributes]
    end
  end
end
