# typed: false
# frozen_string_literal: true

class OidcAccessTokenAuthenticator < ApplicationService
  Result =
    Data.define(:success, :payload, :token, :device, :principal_public_id, :error) do
      def success? = success
    end

  def initialize(access_token:, resource_type:, host:, authorization_scheme: nil, dpop_proof: nil,
                 request_method: nil, request_uri: nil)
    super()
    @access_token = access_token
    @resource_type = OidcSubject.normalize_resource_type(resource_type)
    @host = host
    @authorization_scheme = authorization_scheme
    @dpop_proof = dpop_proof
    @request_method = request_method
    @request_uri = request_uri
  end

  public

  def call
    return failure("invalid_token") if access_token.blank?

    payload = AuthenticationTokenService.decode(
      access_token,
      host: host,
      resource_type: resource_type,
      issuer: OidcIssuer.for_resource_type(resource_type),
      audiences: OidcClientRegistry.audiences_for_resource_type(resource_type),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
    )
    return failure("invalid_token") unless payload
    return failure("invalid_token") unless dpop_valid?(payload)

    base_session = find_base_session(payload)
    return failure("invalid_token") unless base_session&.active_status?
    return failure("invalid_token") unless authentication_context_matches_root?(payload, base_session)
    return failure("invalid_token") unless token_belongs_to_audience?(payload)
    return failure("insufficient_scope") unless token_scope_allows_userinfo?(payload)

    device = find_device_session(base_session)
    return failure("invalid_token") if device&.subject_public_id.blank?
    return failure("invalid_token") unless token_subject_matches?(device.subject_public_id, payload)

    Result.new(
      success: true, payload: payload, token: base_session, device: device,
      principal_public_id: device.subject_public_id, error: nil,
    )
  end

  private

  attr_reader :access_token, :resource_type, :host, :authorization_scheme, :dpop_proof,
              :request_method, :request_uri

  # Enforce DPoP sender-constraint, mirroring
  # AuthenticationCurrentResourceResolver#dpop_valid?. A DPoP-bound access
  # token (one carrying cnf.jkt) must be presented with the DPoP scheme and a
  # valid proof; it must never be accepted as a plain Bearer token.
  def dpop_valid?(payload)
    token_jkt = payload.dig("cnf", "jkt")
    scheme_dpop = authorization_scheme.to_s.casecmp?("DPoP")

    return true if token_jkt.blank? && !scheme_dpop && dpop_proof.blank?
    return false unless scheme_dpop
    return false if token_jkt.blank?

    DpopRequestVerifier.new(
      access_token_payload: payload,
      proof_jwt: dpop_proof,
      request_method: request_method,
      request_uri: request_uri,
      access_token: access_token,
      resource_type: resource_type,
    ).call.valid?
  end

  # Normal Access JWT authentication is cryptographic (RFC 9068) plus a direct
  # binding to the Base Browser Session that issued the RP credentials. Read the
  # parent from the writer without query caching so a committed parent revocation
  # takes effect on the next authenticated request. `sid` remains the protocol
  # identifier for the RP Session; `umx_base_sid` identifies the parent Base session.
  def find_base_session(payload)
    base_sid = AuthorizationTokenClaims.base_session_id(payload).to_s
    return if base_sid.blank?

    token_class = token_class_for_resource_type
    token_class.connection_class_for_self.connected_to(role: :writing) do
      token_class.uncached { token_class.find_by(public_id: base_sid) }
    end
  end

  def token_belongs_to_audience?(payload)
    client = OidcClientRegistry.find(AuthorizationTokenClaims.client_id(payload))
    return false unless client
    return false unless OidcIssuer.resource_type_for_client(client) == resource_type

    Array(payload["aud"]).include?(client.aud)
  end

  def token_scope_allows_userinfo?(payload)
    AuthorizationTokenClaims.scopes(payload).include?("openid")
  end

  def authentication_context_matches_root?(payload, root_token)
    context = payload[AuthenticationContextValue::CLAIM]
    return false unless context.is_a?(String) && AuthenticationContextValue::KEYS.include?(context)

    context == root_token.strict_authentication_context_value.to_s
  rescue AuthenticationContextValue::UnknownContextError
    false
  end

  def find_device_session(root)
    model, owner =
      case resource_type
      when "client" then [ClientDeviceSession, { subject_public_id: root.subject_public_id }]
      when "operator" then [OperatorDeviceSession, { subject_public_id: root.subject_public_id }]
      else raise ArgumentError, "unsupported OP realm"
      end
    model.connection_class_for_self.connected_to(role: :writing) do
      model.uncached { model.find_by(id: root.device_session_id, **owner) }
    end
  end

  def token_subject_matches?(principal_public_id, payload)
    expected = "#{OidcSubject.prefix_for(resource_type)}_#{principal_public_id}"
    actual = payload["sub"].to_s
    return false unless expected.bytesize == actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def token_class_for_resource_type
    case resource_type
    when "operator" then OperatorToken
    when "client" then ClientToken
    else raise ArgumentError, "unsupported OP realm"
    end
  end

  def failure(error)
    Result.new(success: false, payload: nil, token: nil, device: nil, principal_public_id: nil, error: error)
  end
end
