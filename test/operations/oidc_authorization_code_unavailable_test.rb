# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationCodeUnavailableTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "authorization code issuance requires Governance before using its storage" do
    issuer = OidcAuthorizationCodeIssuer.new(
      client: nil, params: {}, resource: nil, session_token: nil, store: nil,
    )

    error = assert_raises(GovernanceLookupUnavailableError) { issuer.call }

    assert_match(/Governance/, error.message)
  end

  test "authorization coordination reports unavailable without issuing a redirect" do
    result = OidcAuthorizeCoordinator.call(params: {}, resource: nil, session_token: nil)

    assert_not_predicate result, :success?
    assert_equal "temporarily_unavailable", result.error
    assert_match(/Governance/, result.error_description)
    assert_nil result.redirect_url
    assert_nil result.redirect_uri
  end
end
