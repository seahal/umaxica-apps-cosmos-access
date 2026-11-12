# frozen_string_literal: true

require "test_helper"

class OpExistingSessionLogoutTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "logout confirmation without a staged request cannot stop either realm's root" do
    ["client", "operator"].each do |type|
      browser = open_session
      browser.host!(OidcIssuer.host_for_resource_type(type))
      browser.https!
      before = [ClientToken.count, OperatorToken.count, ClientChronicle.count, OperatorChronicle.count]

      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 422, browser.response.status
      assert_equal before, [ClientToken.count, OperatorToken.count, ClientChronicle.count, OperatorChronicle.count]
      assert_not ClientToken.find(ActiveRecord::FixtureSet.identify(:one)).revoked?
      assert_not OperatorToken.find(ActiveRecord::FixtureSet.identify(:one)).revoked?
    end
  end

  test "a staged logout cannot be confirmed using a different device credential" do
    browser = open_session
    host = OidcIssuer.host_for_resource_type("client")
    browser.host!(host)
    browser.https!
    [:one, :two].each do |fixture|
      root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(fixture))
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: root.user_id.to_s, resource_type: "client",
        issued_at: Time.current, access_token_ttl: 60.seconds,
        session_public_id: root.device_session.public_id, oidc_jti: root.oidc_jti,
        authentication_context: AuthenticationContextValue::NORMAL_KEY,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      next unless fixture == :one

      browser.get("/oidc/logout?ri=jp&lx=en")

      assert_equal 200, browser.response.status
    end

    browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

    assert_equal 403, browser.response.status
    [:one, :two].each do |fixture|
      root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(fixture))

      assert_not root.revoked?
      assert_not root.device_session.revoked?
    end
  end

  test "both realms confirm logout with valid or expired existing OP credentials and retain scalar audit history" do
    [["client", ClientToken, :user_id, ClientChronicle],
     ["operator", OperatorToken, :staff_id, OperatorChronicle],].each do |type, model, owner_key, audits|
      [[:one, Time.current], [:two, 5.minutes.ago]].each do |fixture, issued_at|
        root = model.includes(:device_session).find(ActiveRecord::FixtureSet.identify(fixture))
        root.update!(authentication_context: "normal") if type == "operator"
        payload = AuthorizationTokenClaims.build(
          resource: nil, subject: root[owner_key].to_s, resource_type: type,
          issued_at: issued_at, access_token_ttl: 60.seconds,
          session_public_id: root.device_session.public_id, oidc_jti: root.oidc_jti,
          authentication_context: AuthenticationContextValue::NORMAL_KEY,
        )
        credential = JitSecurityJwtKeyring.encode(
          payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                   issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
        )
        host = OidcIssuer.host_for_resource_type(type)
        browser = open_session
        browser.host!(host)
        browser.https!
        browser.cookies << Rack::Test::Cookie.new(
          "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
        )
        before = audits.count

        browser.get("/oidc/logout?ri=jp&lx=en")

        assert_equal 200, browser.response.status
        assert_not root.reload.revoked?
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

        assert_equal 303, browser.response.status
        assert_predicate root.reload, :revoked?
        assert_predicate root.device_session.reload, :revoked?
        assert_equal before + 1, audits.count
        audit = audits.order(id: :desc).first!

        assert_equal root[owner_key].to_s, audit.subject_id.to_s
        assert_equal root[owner_key].to_s, audit.actor_id.to_s
        assert_predicate browser.cookies[AuthenticationCookieName.access], :blank?
        assert_predicate browser.cookies[AuthenticationCookieName.refresh], :blank?
        assert_includes browser.response.headers["Set-Cookie"].to_s, "#{AuthenticationCookieName.access}=;"
      end
    end
  end
end
