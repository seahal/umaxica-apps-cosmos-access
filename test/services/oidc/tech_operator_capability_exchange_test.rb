# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcTechOperatorCapabilityExchangeTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    operator_tokens operator_device_sessions operator_token_kinds operator_token_statuses
    operator_token_binding_methods operator_token_dbsc_statuses
  )

  test "refresh requiring operator capability fails closed before rotating the RP credential" do
    root = OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))
    root.update!(authentication_context: "normal")
    client = OidcClientRegistry.find!("tech-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: root.authentication_epoch,
      operator_token_id: root.id,
      device_session_id: root.device_session_id,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 1.hour.from_now,
    )
    refresh_token = grant.issue_refresh_token!
    digest = grant.reload.refresh_token_digest
    generation = grant.refresh_generation
    assertion = OidcClientRegistry::AssertionAuthenticationResult.new(
      authenticated: true, client:, step_up_claims_state: :none, step_up_expectation: nil,
    )

    result =
      OidcClientRegistry.stub(:verify_client_assertion, assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token:,
          client_id: client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "verified-tech-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("operator"),
          expected_resource_type: "operator",
        )
      end

    assert_not result.success?
    assert_equal "temporarily_unavailable", result.error
    assert_equal "Governance operator capability lookup is unavailable", result.error_description
    assert_nil result.token_response
    assert_equal digest, grant.reload.refresh_token_digest
    assert_equal generation, grant.refresh_generation
    assert_predicate root.reload, :currently_usable?
  end
end
