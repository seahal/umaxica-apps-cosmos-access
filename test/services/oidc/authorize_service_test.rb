# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizeCoordinatorTest < ActiveSupport::TestCase
  test "authorization errors preserve state and identify their issuing Visa realm" do
    [
      ["base-app-ww", "client"],
      ["base-org-ww", "operator"],
    ].each do |client_id, resource_type|
      client = OidcClientRegistry.find!(client_id)
      redirect_uri = client.redirect_uris_by_realm.fetch(resource_type).first

      url = OidcAuthorizeCoordinator.error_redirect_url(
        redirect_uri: redirect_uri,
        resource_type: resource_type,
        error: "login_required",
        state: "protocol-error-state",
      )

      target = URI.parse(url)
      response = Rack::Utils.parse_query(target.query)

      assert_equal URI.parse(redirect_uri).host, target.host
      assert_equal "login_required", response.fetch("error")
      assert_equal "protocol-error-state", response.fetch("state")
      assert_equal OidcIssuer.for_resource_type(resource_type), response.fetch("iss")
    end
  end

  test "authorization error omits blank state while retaining the issuer" do
    client = OidcClientRegistry.find!("base-app-ww")
    redirect_uri = client.redirect_uris_by_realm.fetch("client").first
    target = URI.parse(
      OidcAuthorizeCoordinator.error_redirect_url(
        redirect_uri: redirect_uri,
        resource_type: "client",
        error: "login_required",
        state: "",
      ),
    )
    response = Rack::Utils.parse_query(target.query)

    assert_equal "login_required", response.fetch("error")
    assert_not response.key?("state")
    assert_equal OidcIssuer.for_resource_type("client"), response.fetch("iss")
  end
end
