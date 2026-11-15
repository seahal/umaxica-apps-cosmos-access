# frozen_string_literal: true

class OpBrowserSessionResolver
  Result =
    Data.define(:root, :payload, :failure_reason) do
      def success? = root.present?
    end

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  public

  def initialize(access_token:, request_host:, resource_type:, allow_expired: false,
                 authorization_scheme: nil, dpop_proof: nil, request_method: nil, request_uri: nil)
    raise ArgumentError, "unsupported browser session realm" unless %w(client operator).include?(resource_type)
    raise ArgumentError, "allow_expired must be boolean" unless [true, false].include?(allow_expired)

    @access_token = access_token
    @request_host = request_host
    @resource_type = resource_type
    @allow_expired = allow_expired
    @authorization_scheme = authorization_scheme
    @dpop_proof = dpop_proof
    @request_method = request_method
    @request_uri = request_uri
  end

  def call
    return failure(:missing_access_token) if access_token.blank? || request_host.blank?

    payload = verified_payload
    return failure(:invalid_access_token) unless payload
    return failure(:realm_mismatch) unless
      SecurityJwtAuthAccessTokenCodec.resource_type_scope_matches?(payload, resource_type)
    return failure(:invalid_dpop) unless dpop_valid?(payload)

    root, device = resolve_session(payload)
    return failure(:inactive_session) unless root&.active_status? && device&.usable?
    return failure(:stale_root) unless device.current_refresh_token_id == root.id
    return failure(:subject_mismatch) unless owner_matches?(root, device, payload)
    return failure(:binding_mismatch) unless binding_matches?(root, device, payload)
    return failure(:jti_mismatch) unless jti_matches?(root, payload)
    return failure(:context_mismatch) unless
      root.strict_authentication_context_value == AuthenticationContextValue.from_claims(payload)
    return failure(:idle_session) if !allow_expired && idle_expired?(root)

    Result.new(root: root, payload: payload, failure_reason: nil)
  rescue AuthenticationContextValue::UnknownContextError
    failure(:context_mismatch)
  end

  private

  attr_reader :access_token, :request_host, :resource_type, :allow_expired,
              :authorization_scheme, :dpop_proof, :request_method, :request_uri

  def verified_payload
    arguments = {
      host: request_host,
      resource_type: resource_type,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
    }
    if allow_expired
      SecurityJwtAuthAccessTokenCodec.decode_allow_expired(access_token, **arguments)
    else
      SecurityJwtAuthAccessTokenCodec.decode(access_token, **arguments)
    end
  end

  def resolve_session(payload)
    sid = AuthorizationTokenClaims.session_id(payload)
    return [nil, nil] unless sid.is_a?(String) && sid.present?

    connection_owner.connected_to(role: :writing) do
      root_class.uncached do
        device = device_class.find_by(public_id: sid)
        if device
          root = root_class.includes(:device_session).find_by(
            id: device.current_refresh_token_id,
            device_session_id: device.id,
          )
        else
          root = root_for_protocol_identifier(sid)
          device = device_class.find_by(id: root.device_session_id) if root
        end
        [root, device]
      end
    end
  end

  def root_for_protocol_identifier(sid)
    root = root_class.includes(:device_session).find_by(public_id: sid)
    return root if root
    return unless /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.match?(sid)

    root_class.includes(:device_session).find_by(oidc_sid: sid)
  end

  def owner_matches?(root, device, payload)
    owner_id, device_owner_id =
      [root.subject_public_id, device.subject_public_id]
    owner_id == device_owner_id && payload["sub"].is_a?(String) &&
      ActiveSupport::SecurityUtils.secure_compare(owner_id.to_s, payload["sub"])
  end

  def binding_matches?(root, device, payload)
    expected = root.dpop_jkt.presence || device.dpop_jkt
    actual = payload.dig("cnf", "jkt")
    return true if expected.blank? && actual.blank?
    return false unless expected.present? && actual.present?

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def jti_matches?(root, payload)
    return true if root.oidc_jti.blank?

    ActiveSupport::SecurityUtils.secure_compare(root.oidc_jti, payload["jti"].to_s)
  end

  def idle_expired?(root)
    activity = root.last_used_at || root.created_at
    activity.nil? || activity < Time.current - SecurityTokenLifetimes.idle_ttl_for(resource_type)
  end

  def dpop_valid?(payload)
    jkt = payload.dig("cnf", "jkt")
    scheme_dpop = authorization_scheme.to_s.casecmp?("DPoP")
    return true if jkt.blank? && !scheme_dpop && dpop_proof.blank?
    return false unless scheme_dpop && jkt.present?

    DpopRequestVerifier.new(
      access_token_payload: payload, proof_jwt: dpop_proof,
      request_method: request_method, request_uri: request_uri,
      access_token: access_token, resource_type: resource_type,
    ).call.valid?
  end

  def root_class = (resource_type == "client") ? ClientToken : OperatorToken

  def device_class = (resource_type == "client") ? ClientDeviceSession : OperatorDeviceSession

  def connection_owner = (resource_type == "client") ? OpBaseAppRecord : OpBaseOrgRecord

  def failure(reason)
    Result.new(root: nil, payload: nil, failure_reason: reason)
  end
end
