# frozen_string_literal: true

require "test_helper"

class OpSessionTokenClaimsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "existing OP session claims can be signed without a Governance actor record" do
    %w(client operator).each do |resource_type|
      issuer = OidcIssuer.for_resource_type(resource_type)
      subject = "#{OidcSubject.prefix_for(resource_type)}_existing-principal"
      token = SecurityJwtAuthAccessTokenCodec.encode(
        nil,
        host: OidcIssuer.host_for_resource_type(resource_type),
        resource_type: resource_type,
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        issuer: issuer,
        audiences: ["existing-rp"],
        subject: subject,
        scopes: ["openid", "authenticated", "domain:#{resource_type}"],
        client_id: "existing-rp",
        session_public_id: "root-session",
        base_session_public_id: "root-session",
        oidc_sid: "existing-grant",
        oidc_jti: SecureRandom.uuid,
        authentication_context: AuthenticationContextValue::NORMAL_KEY,
      )

      assert_predicate token, :present?, resource_type
      claims = SecurityJwtAuthAccessTokenCodec.decode(
        token,
        host: OidcIssuer.host_for_resource_type(resource_type),
        resource_type: resource_type,
        issuer: issuer,
        audiences: ["existing-rp"],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      )

      assert_equal subject, claims.fetch("sub")
      assert_equal "existing-grant", claims.fetch("sid")
      assert_equal "root-session", claims.fetch("umx_base_sid")
    end
  end

  test "ID token realm and subject come from the existing OP session explicitly" do
    %w(client operator).each do |resource_type|
      client = OidcClientRegistry.find((resource_type == "client") ? "core-app-jp" : "core-org-jp")
      now = Time.current
      subject = "#{OidcSubject.prefix_for(resource_type)}_existing-principal"
      claims = SecurityJwtOidcIdTokenCodec.build_payload(
        resource_type: resource_type,
        client: client,
        nonce: "existing-nonce",
        issued_at: now,
        expires_at: now + 60.seconds,
        acr: "aal1",
        amr: ["pwd"],
        issuer: OidcIssuer.for_resource_type(resource_type),
        subject: subject,
        sid: "existing-grant",
        auth_time: now,
        step_up_until: nil,
      )

      assert_equal resource_type, claims.fetch("act")
      assert_equal subject, claims.fetch("sub")
      assert_equal "existing-grant", claims.fetch("sid")
    end
  end

  test "ID tokens issue and verify with PS256 and refuse an ES384 signature" do
    resource_type = "client"
    client = OidcClientRegistry.find!("core-app-jp")
    issuer = OidcIssuer.for_resource_type(resource_type)
    token = OidcIdTokenIssuer.call(
      resource_type:,
      client:,
      nonce: "existing-nonce",
      issuer:,
      subject: "cli_existing-principal",
      sid: "existing-grant",
    )
    payload, header = JWT.decode(token, nil, false)

    assert_equal "PS256", header.fetch("alg")
    assert_equal "id-token+jwt", header.fetch("typ")
    assert_equal "cli_existing-principal", payload.fetch("sub")
    assert SecurityJwtOidcIdTokenCodec.decode(
      id_token: token,
      client_id: client.client_id,
      resource_type:,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      issuer:,
    )

    legacy_token = JWT.encode(
      payload,
      OpenSSL::PKey::EC.generate("secp384r1"),
      "ES384",
      header.merge("alg" => "ES384"),
    )

    assert_raises(JWT::DecodeError) do
      SecurityJwtOidcIdTokenCodec.decode(
        id_token: legacy_token,
        client_id: client.client_id,
        resource_type:,
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        issuer:,
      )
    end
  end
end
