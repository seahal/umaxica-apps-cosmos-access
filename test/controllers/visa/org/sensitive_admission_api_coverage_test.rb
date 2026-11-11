# frozen_string_literal: true

require "test_helper"

class Visa::Org::SensitiveAdmissionApiCoverageTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @root_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.hour.from_now,
      root_login_established_at: Time.current,
      established_authentication_method: "passkey",
    )
    @host = visa_host_for_test_surface(:org)
    https!
    host! @host
    @client = OidcClientRegistry.find!("base-org-ww")
    @grant = OpOrgGrant.create!(
      authentication_epoch: @root_token.authentication_epoch,
      operator_token: @root_token,
      oidc_client_id: @client.client_id,
      oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.current,
      refresh_token_expires_at: 1.hour.from_now,
    )
    @access_token = AuthenticationTokenService.encode(
      @operator,
      host: @host,
      resource_type: "operator",
      session_public_id: @root_token.public_id,
      base_session_public_id: @root_token.public_id,
      oidc_sid: @grant.public_id,
      oidc_jti: @grant.oidc_jti,
      expires_at: 5.minutes.from_now,
      scopes: %w(openid),
      issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud],
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
      client_id: @client.client_id,
    )
  end

  test "ORG admission creation reaches validation with an authenticated registered client" do
    before = [OperatorVisaSensitiveAdmission.count, OperatorAuthAdmissionBinding.count]

    post "/api/v0/sensitive_admissions", params: {}, headers: {
      "Authorization" => "Bearer #{@access_token}",
      "X-Client-Assertion" => OidcClientAssertionJwt.issue(
        client_id: @client.client_id,
        token_url: "https://#{@host}/api/v0/sensitive_admissions",
      ),
    }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_equal before, [OperatorVisaSensitiveAdmission.count, OperatorAuthAdmissionBinding.count]
  end

  test "ORG browser confirmation rejects missing binding evidence without changing the admission" do
    before = [OperatorVisaSensitiveAdmission.count, OperatorAuthAdmissionBinding.count]

    post "/api/v0/sensitive_admission_confirmation", params: {}, headers: {
      "Authorization" => "Bearer #{@access_token}",
      "X-Client-Assertion" => OidcClientAssertionJwt.issue(
        client_id: @client.client_id,
        token_url: "https://#{@host}/api/v0/sensitive_admission_confirmation",
      ),
    }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_equal before, [OperatorVisaSensitiveAdmission.count, OperatorAuthAdmissionBinding.count]
  end
end
