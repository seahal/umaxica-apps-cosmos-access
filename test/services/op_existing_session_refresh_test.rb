# frozen_string_literal: true

require "test_helper"

class OpExistingSessionRefreshTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    client_token_binding_methods client_token_dbsc_statuses client_token_kinds client_token_statuses
    operator_token_binding_methods operator_token_dbsc_statuses operator_token_kinds operator_token_statuses
    client_device_sessions operator_device_sessions client_tokens operator_tokens
  )

  test "each realm refreshes an existing session using only OP-owned identity evidence" do
    [["client", ClientToken, OpAppGrant],
     ["operator", OperatorToken, OpOrgGrant],].each do |type, root_class, grant_class|
      root = root_class.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      client = OidcClientRegistry.find((type == "client") ? "core-app-jp" : "core-org-jp")
      grant = grant_class.create!(
        authentication_epoch: root.authentication_epoch,
        device_session_id: root.device_session_id,
        **((type == "client") ? { client_token_id: root.id } : { operator_token_id: root.id }),
        oidc_client_id: client.client_id,
        oidc_jti: SecureRandom.uuid,
        oidc_scope: "openid",
        oidc_auth_time: Time.current,
        oidc_acr: "aal1",
        oidc_amr: '["pwd"]',
        oidc_nonce: "existing-nonce",
        refresh_token_expires_at: 1.hour.from_now,
      )
      refresh = grant.issue_refresh_token!
      assertion = OidcClientRegistry::AssertionAuthenticationResult.new(
        authenticated: true, client: client, step_up_claims_state: :none, step_up_expectation: nil,
      )
      connections = []
      subscriber = ->(event) { connections << event.payload.fetch(:connection).pool.db_config.name }
      result =
        ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
          OidcClientRegistry.stub(:verify_client_assertion, assertion) do
            OidcTokenExchangeCoordinator.call(
              grant_type: "refresh_token",
              refresh_token: refresh,
              client_id: client.client_id,
              client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
              client_assertion: "externally-verified-client-assertion",
              token_endpoint_uri: OidcIssuer.token_endpoint(type),
              expected_resource_type: type,
            )
          end
        end

      assert_predicate result, :success?, result.error_description
      assert_empty connections.grep(/zenith/)
      claims = SecurityJwtOidcIdTokenCodec.decode(
        id_token: result.token_response.fetch(:id_token),
        client_id: client.client_id,
        resource_type: type,
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
        issuer: OidcIssuer.for_resource_type(type),
      )

      assert_equal "#{OidcSubject.prefix_for(type)}_#{root.device_session.subject_public_id}", claims.fetch("sub")
      assert_equal type, claims.fetch("act")
      assert_not_equal refresh, result.token_response.fetch(:refresh_token)
      assert_operator grant.reload.refresh_generation, :>, 0
    end
  end
end
