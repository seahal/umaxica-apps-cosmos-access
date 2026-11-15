# frozen_string_literal: true

require "test_helper"

class OpExistingGrantRevocationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "both Visa discovery endpoints publish the correct issuer and public endpoint URLs" do
    %w(client operator).each do |type|
      browser = open_session
      browser.host!(OidcIssuer.host_for_resource_type(type))
      browser.https!
      browser.get("/.well-known/openid-configuration")

      assert_equal 200, browser.response.status
      document = browser.response.parsed_body

      assert_equal OidcIssuer.for_resource_type(type), document.fetch("issuer")
      assert_equal OidcIssuer.token_endpoint(type), document.fetch("token_endpoint")
      assert_equal OidcIssuer.revocation_endpoint(type), document.fetch("revocation_endpoint")
      assert_equal "#{OidcIssuer.for_resource_type(type)}/.well-known/jwks.json", document.fetch("jwks_uri")
    end
  end

  test "both realms revoke only an authenticated client's grant and reject its later refresh" do
    [["client", ClientToken, OpAppGrant, :client_token_id, "core-app-jp", "warp-app-jp"],
     ["operator", OperatorToken, OpOrgGrant, :operator_token_id, "core-org-jp",
      "warp-org-jp",],].each do |type, model, grant_class, root_key, client_id, sibling_client_id|
      root = model.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      target = grant_class.create!(
        root_key => root.id, :device_session_id => root.device_session_id,
        :authentication_epoch => root.authentication_epoch, :oidc_client_id => client_id,
        :oidc_scope => "openid", :oidc_jti => SecureRandom.uuid, :refresh_token_expires_at => 1.hour.from_now,
      )
      sibling = grant_class.create!(
        root_key => root.id, :device_session_id => root.device_session_id,
        :authentication_epoch => root.authentication_epoch, :oidc_client_id => sibling_client_id,
        :oidc_scope => "openid", :oidc_jti => SecureRandom.uuid, :refresh_token_expires_at => 1.hour.from_now,
      )
      refresh = target.issue_refresh_token!
      endpoint = OidcIssuer.revocation_endpoint(type)
      browser = open_session
      browser.host!(OidcIssuer.host_for_resource_type(type))
      browser.https!
      browser.post(
        URI.parse(endpoint).path, params: {
          token: refresh,
          client_id: client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "invalid",
        },
      )

      assert_equal 401, browser.response.status
      assert_nil target.reload.revoked_at
      assert_nil sibling.reload.revoked_at
      assert_predicate root.reload, :currently_usable?

      browser.post(
        URI.parse(endpoint).path, params: {
          token: refresh,
          client_id: client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: OidcClientAssertionJwt.issue(client_id: client_id, token_url: endpoint),
        },
      )

      assert_equal 200, browser.response.status
      assert_predicate target.reload, :revoked?
      assert_nil sibling.reload.revoked_at
      assert_predicate root.reload, :currently_usable?
      assert_includes browser.response.headers.fetch("Cache-Control"), "no-store"
      assert_nil browser.response.headers["Set-Cookie"]

      token_endpoint = OidcIssuer.token_endpoint(type)
      browser.post(
        URI.parse(token_endpoint).path, params: {
          grant_type: "refresh_token",
          refresh_token: refresh,
          client_id: client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: OidcClientAssertionJwt.issue(client_id: client_id, token_url: token_endpoint),
        },
      )

      assert_equal 400, browser.response.status
      assert_equal "invalid_grant", browser.response.parsed_body.fetch("error")
      assert_nil sibling.reload.revoked_at
      assert_predicate root.reload, :currently_usable?
    end
  end
end
