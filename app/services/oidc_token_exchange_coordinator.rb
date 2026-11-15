# typed: false
# frozen_string_literal: true

class OidcTokenExchangeCoordinator < ApplicationService
  class TokenIssuanceError < StandardError; end

  Result =
    Data.define(:success, :token_response, :error, :error_description, :access_expires_at, :refresh_expires_at) do
      def success? = success
    end

  def initialize(grant_type:, code: nil, refresh_token: nil, redirect_uri: nil, client_id:, client_secret: nil,
                 code_verifier: nil,
                 client_assertion_type: nil, client_assertion: nil,
                 dpop_proof: nil, token_endpoint_uri: nil, request_method: "POST",
                 expected_resource_type:)
    super()
    @grant_type = grant_type
    @refresh_token = refresh_token
    @client_id = client_id
    @client_secret = client_secret
    @client_assertion_type = client_assertion_type
    @client_assertion = client_assertion
    @dpop_proof = dpop_proof
    @token_endpoint_uri = token_endpoint_uri
    @request_method = request_method
    @expected_resource_type = expected_resource_type
  end

  public

  def call
    return failure(
      "invalid_request", "grant_type must be 'authorization_code' or 'refresh_token'",
    ) unless valid_grant_type?
    return failure("invalid_request", "token endpoint realm is required") unless expected_realm_configured?
    return failure("invalid_client", "OIDC client authentication failed") unless authenticated_client?
    return failure("unauthorized_client", "Base front-channel clients do not use the Token Endpoint") if
      authenticated_client_config.authorization_response_type == "id_token"

    if grant_type == "refresh_token"
      exchange_refresh_token!
    else
      failure("temporarily_unavailable", "authorization-code issuance is unavailable for this client")
    end
  rescue AuthenticationContextValue::UnknownContextError
    failure("invalid_grant", "session authentication context is invalid")
  rescue TokenIssuanceError => e
    Rails.logger.error("[OidcTokenExchangeCoordinator] token issuance failed: #{e.class}")
    failure("server_error", "token issuance failed")
  rescue RpSession::IssuanceRejected
    failure("invalid_grant", "RP Session is no longer active")
  end

  private

  attr_reader :grant_type, :refresh_token, :client_id, :client_secret, :client_assertion_type,
              :client_assertion, :dpop_proof, :token_endpoint_uri, :request_method, :expected_resource_type

  def valid_grant_type?
    %w(authorization_code refresh_token).include?(grant_type)
  end

  def authenticated_client?
    @authenticated_client = nil
    @client_assertion_verification = nil

    client = OidcClientRegistry.find(client_id)
    return false unless client

    return false if client_id.blank?

    case client.registered_token_endpoint_auth_method
    when "none"
      return false unless public_client_authenticated?

      @authenticated_client = client
      true
    when "private_key_jwt"
      return false if client_secret.present?

      authenticated_client_assertion?
    else
      return false if client_assertion.present? || client_assertion_type.present?

      return false unless OidcClientRegistry.authenticate(client_id, client_secret)

      @authenticated_client = client
      true
    end
  end

  def public_client_authenticated?
    client_secret.blank? && client_assertion.blank? && client_assertion_type.blank?
  end

  def authenticated_client_assertion?
    return false unless client_assertion_type == OidcClientAssertionJwt::ASSERTION_TYPE
    return false if token_endpoint_uri.blank?
    return false if client_assertion.blank?

    @client_assertion_verification = OidcClientRegistry.verify_client_assertion(
      client_id,
      client_assertion,
      token_url: token_endpoint_uri,
    )
    return false unless @client_assertion_verification.authenticated?

    @authenticated_client = @client_assertion_verification.client
    true
  end

  def exchange_refresh_token!
    return failure("invalid_request", "step-up assertion claims require an authorization code") if
      step_up_assertion_claims_present?
    return failure("invalid_grant", "refresh_token is required") if refresh_token.blank?

    resolved = resolve_refresh_usage
    return failure("invalid_grant", "refresh token not found") unless resolved

    usage = resolved.usage
    return failure("invalid_grant", "refresh token is not bound to this client") unless
      usage.oidc_client_id == client_id

    resource_type = resource_type_for_usage(usage)
    return failure("invalid_grant", "refresh token realm mismatch") unless expected_realm_matches?(resource_type)

    client = authenticated_client_config
    return failure("invalid_grant", "refresh token resource mismatch") unless
      OidcIssuer.resource_type_for_client(client) == resource_type

    return failure("invalid_grant", "refresh token session is not active") unless
      refresh_session_usable?(usage)

    return failure("temporarily_unavailable", "Governance operator capability lookup is unavailable") if
      client.required_operator_capability.present?

    auth_time = parse_time(usage.oidc_auth_time)
    return failure("invalid_grant", "refresh token authentication time missing") unless auth_time

    scopes = usage.oidc_scope.to_s.split
    return failure("invalid_grant", "refresh token scope is invalid") unless valid_refresh_scopes?(client, scopes)

    dpop_jkt = validate_refresh_dpop_proof(usage, resource_type)
    return dpop_jkt if dpop_jkt.is_a?(Result)

    rotation = rotate_refresh_token(
      client: client,
      auth_time: auth_time,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
    )
    return refresh_rotation_failure(rotation) unless rotation.success?

    Result.new(
      success: true,
      token_response: rotation.token_response,
      error: nil,
      error_description: nil,
      access_expires_at: rotation.access_expires_at,
      refresh_expires_at: rotation.refresh_expires_at,
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.error("[OidcTokenExchangeCoordinator] refresh rotation failed: #{e.class}")
    failure("server_error", "refresh token rotation failed")
  end

  def resource_type_for_usage(usage)
    case usage
    when OpAppGrant then "client"
    when OpOrgGrant then "operator"
    end
  end

  def refresh_session_usable?(usage)
    root = usage.parent_token
    device = usage.parent_device_session
    return false unless root&.active_status? && device&.usable? && device.subject_public_id.present?

    root.strict_authentication_context_value
    true
  end

  def resolve_refresh_usage
    OidcRefreshTokenIssuer.resolve(
      refresh_token: refresh_token,
      resource_type: expected_resource_type,
    )
  end

  def rotate_refresh_token(client:, auth_time:, resource_type:, dpop_jkt:)
    OidcRefreshTokenIssuer.call(
      refresh_token: refresh_token,
      client_id: client_id,
      resource_type: resource_type,
      response_builder: lambda do |usage:, refresh_token:, now:, **_|
        locked_root_token = usage.parent_token
        principal_public_id = usage.parent_device_session.subject_public_id
        result = issue_refreshed_token_result(
          usage: usage,
          principal_public_id: principal_public_id,
          client: client,
          root_token: locked_root_token,
          refresh_plain: refresh_token,
          dpop_jkt: dpop_jkt,
          auth_time: auth_time,
          resource_type: resource_type,
          now: now,
        )
        raise TokenIssuanceError, "refreshed token response could not be built" unless result.success?

        result.token_response
      end,
    )
  end

  def refresh_rotation_failure(rotation)
    case rotation.reason
    when :refresh_token_reuse_detected
      failure("invalid_grant", "refresh token reuse detected")
    when :client_mismatch, :inactive_token, :invalid_digest
      failure("invalid_grant", "refresh token could not be rotated")
    else
      failure("server_error", "refresh token rotation failed")
    end
  end

  def valid_refresh_scopes?(client, scopes)
    scopes.include?("openid") && (scopes - client.allowed_scopes).empty?
  end

  def authenticated_client_config
    @authenticated_client || raise(ArgumentError, "authenticated OIDC client is unavailable")
  end

  def step_up_assertion_claims_present?
    @client_assertion_verification&.step_up_claims_present? || false
  end

  def validate_refresh_dpop_proof(usage, resource_type)
    expected_jkt = usage.dpop_jkt.to_s
    return nil if expected_jkt.blank? && dpop_proof.blank?
    return failure("invalid_request", "DPoP proof is required") if expected_jkt.present? && dpop_proof.blank?
    return failure("invalid_request", "DPoP proof is not bound to the refresh token") if expected_jkt.blank?

    result = DpopProofVerifier.new(
      proof_jwt: dpop_proof,
      request_method: request_method,
      request_uri: token_endpoint_uri.to_s,
      resource_type: resource_type,
    ).call
    return failure("invalid_request", "DPoP proof invalid: #{result.error}") unless result.valid?
    return failure("invalid_request", "DPoP proof key mismatch") unless result.jkt == expected_jkt

    result.jkt
  end

  def parse_time(value)
    return nil if value.blank?
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def rp_session_oidc_jti(usage)
    usage.oidc_jti.presence || raise(ArgumentError, "OIDC token usage is missing oidc_jti")
  end

  def issue_refreshed_token_result(usage:, principal_public_id:, client:, root_token:, refresh_plain:, dpop_jkt:,
                                   auth_time:, resource_type:, now:)
    client = client_for_resource_type(client, resource_type)
    issuer = OidcIssuer.for_resource_type(resource_type)
    subject = "#{OidcSubject.prefix_for(resource_type)}_#{principal_public_id}"
    access_expires_at = session_token_expiry(now, root_token)
    scopes = usage.oidc_scope.to_s.split
    amr = parse_stored_amr(usage.oidc_amr)
    usage.record_access_token_expiry!(access_expires_at, now: now)
    access_token = refreshed_access_token(
      usage:, root_token:, dpop_jkt:, auth_time:, resource_type:, client:, issuer:, subject:,
      scopes:, amr:, access_expires_at:,
    )
    id_token =
      refreshed_id_token(
        usage:, root_token:, auth_time:, resource_type:, client:, issuer:, subject:, scopes:, amr:, now:,
      )
    raise TokenIssuanceError, "required token output is blank" if access_token.blank? || refresh_plain.blank? ||
      (scopes.include?("openid") && id_token.blank?)

    Result.new(
      success: true,
      token_response: {
        access_token: access_token,
        token_type: dpop_jkt.present? ? "DPoP" : "Bearer",
        expires_in: [(access_expires_at - now).to_i, 0].max,
        refresh_token: refresh_plain,
        refresh_token_expires_in: [(usage.refresh_token_expires_at - now).to_i, 0].max,
        id_token: id_token,
      }.compact,
      error: nil,
      error_description: nil,
      access_expires_at: access_expires_at,
      refresh_expires_at: usage.refresh_token_expires_at,
    )
  end

  def refreshed_access_token(usage:, root_token:, dpop_jkt:, auth_time:, resource_type:, client:, issuer:,
                             subject:, scopes:, amr:, access_expires_at:)
    AuthenticationTokenService.encode(
      nil,
      host: OidcIssuer.host_for_resource_type(resource_type),
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: usage.public_id,
      oidc_jti: rp_session_oidc_jti(usage),
      resource_type: resource_type,
      expires_at: access_expires_at,
      scopes: scopes,
      acr: usage.oidc_acr,
      amr: amr,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      issuer: issuer,
      audiences: [client.aud],
      subject: subject,
      auth_time: auth_time,
      client_id: client.client_id,
      authentication_context: root_token.strict_authentication_context_value.to_s,
    )
  end

  def refreshed_id_token(
    usage:, root_token:, auth_time:, resource_type:, client:, issuer:, subject:, scopes:, amr:, now:
  )
    return unless scopes.include?("openid")

    OidcIdTokenIssuer.call(
      resource_type: resource_type,
      client: client,
      nonce: usage.oidc_nonce,
      issued_at: now,
      expires_at: SessionAbsoluteExpiryValue.cap(
        proposed_expiry: now + OidcIdTokenIssuer::TOKEN_TTL,
        absolute_expiry: root_token.discard_at,
      ),
      acr: usage.oidc_acr,
      amr: amr,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      issuer: issuer,
      subject: subject,
      sid: usage.public_id,
      auth_time: auth_time,
    )
  end

  def parse_stored_amr(value)
    return [] if value.blank?

    parsed = JSON.parse(value.to_s)
    parsed.is_a?(Array) ? parsed.map(&:to_s) : []
  rescue JSON::ParserError
    []
  end

  def session_token_expiry(now, root_token)
    SessionAbsoluteExpiryValue.cap(
      proposed_expiry: now + SecurityTokenLifetimes::AUTH_ACCESS_JWT_TTL,
      absolute_expiry: root_token.discard_at,
    )
  end

  def client_for_resource_type(client, resource_type)
    OidcClientRegistry::ClientConfiguration.new(
      client_id: client.client_id,
      client_secret: client.client_secret,
      redirect_uris: client.redirect_uris,
      redirect_uris_by_realm: client.redirect_uris_by_realm,
      post_logout_redirect_uris: client.post_logout_redirect_uris,
      aud: client.aud,
      resource_type: resource_type,
      name: client.name,
      domains: client.domains,
      allowed_scopes: client.allowed_scopes,
      registered_token_endpoint_auth_method: client.registered_token_endpoint_auth_method,
      metadata_token_endpoint_auth_method: client.metadata_token_endpoint_auth_method,
      jwt_namespace: client.jwt_namespace,
      required_operator_capability: client.required_operator_capability,
      authorization_response_type: client.authorization_response_type,
    )
  end

  def failure(error, description)
    Result.new(
      success: false,
      token_response: nil,
      error: error,
      error_description: description,
      access_expires_at: nil,
      refresh_expires_at: nil,
    )
  end

  def expected_realm_matches?(actual_resource_type)
    expected_realm_configured? &&
      actual_resource_type.to_s == expected_resource_type.to_s
  end

  def expected_realm_configured?
    %w(client operator).include?(expected_resource_type.to_s)
  end
end
