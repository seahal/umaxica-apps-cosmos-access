# frozen_string_literal: true

# Visa controllers supply resource_type, token_class, root_owner_id, token_dbsc_path,
# token_dbsc_url, browser_risk_payload and write_browser_refresh_audit.
# Callbacks are registered explicitly by each AuthorityController.
module OpBrowserSessionRequest
  extend ActiveSupport::Concern
  include DbscCanonicalUrl

  class RefreshRefused < StandardError
    attr_reader :root

    public

    def initialize(root)
      @root = root
      super("browser refresh prerequisite refused")
    end
  end

  private

  def enforce_op_boundary_mode!
    head :forbidden unless self.class.authentication_mode_for(action_name) == :open
  end

  def with_request_actor_lifecycle
    Actor.clear
    yield
  ensure
    Actor.clear
  end

  def current_session
    return @current_session if defined?(@current_session)

    result = OpBrowserSessionResolver.call(
      access_token: extract_access_token(AuthenticationCookieName.access), request_host: request.host,
      resource_type: resource_type, allow_expired: allow_expired_session_access?,
      authorization_scheme: request.authorization.to_s.split.first,
      dpop_proof: request.headers["DPoP"], request_method: request.request_method, request_uri: request.original_url,
    )
    @current_session = result.root
  end

  def logged_in? = current_session.present?

  def allow_expired_session_access? = false

  def current_session_public_id = current_session&.device_session&.public_id

  def extract_access_token(cookie_key)
    AuthAuthorizationHeader.access_token(request) || BrowserCredentialCookie.read(cookies, cookie_key)
  end

  def clear_auth_cookies!
    service = AuthenticationCookieService.new(cookies, request)
    service.clear_auth_cookies
    cookies.delete(AuthenticationCookieName.dbsc, service.auth_cookie_deletion_options)
    @current_session = nil
    Actor.clear
  end

  def set_dbsc_cookie!(value, expires_at:)
    options = AuthenticationCookieService.new(cookies, request).auth_cookie_options(expires: expires_at)
    cookies[AuthenticationCookieName.dbsc] = options.merge(value: value)
  end

  def dbsc_cookie_expires_at_for(root, now: Time.current)
    return unless root&.binding_method_dbsc?

    [now + SecurityTokenLifetimes::DBSC_COOKIE_TTL, root.discard_at].min
  end

  def dbsc_payload_for(root)
    return unless root

    {
      binding_method: root.binding_method_dbsc? ? "dbsc" : (root.binding_method_legacy? ? "legacy" : "nothing"),
      status: root.dbsc_status_active? ? "active" : dbsc_unbound_status(root),
      session_id: root.dbsc_session_id,
      registration_url: token_dbsc_path,
      verification_url: token_dbsc_path,
    }
  end

  def dbsc_unbound_status(root)
    return "pending" if root.dbsc_status_pending?
    return "failed" if root.dbsc_status_failed?
    return "revoke" if root.dbsc_status_revoke?

    "nothing"
  end

  def issue_dbsc_challenge_for!(root)
    challenge = SecureRandom.urlsafe_base64(32)
    ActiveRecord::Base.connected_to(role: :writing) do
      root.update!(dbsc_challenge: challenge, dbsc_challenge_issued_at: Time.current)
    end
    challenge
  end

  def issue_dbsc_registration_header_for(root, issue_challenge: false)
    return unless root
    return if root.binding_method_dbsc?

    challenge = issue_challenge ? issue_dbsc_challenge_for!(root) : root.dbsc_challenge
    return if challenge.blank?
    return unless root.dbsc_challenge_issued_at &&
      root.dbsc_challenge_issued_at > Time.current - SecurityTokenLifetimes::DBSC_COOKIE_TTL

    value = DbscHeaderSerializer.registration(path: token_dbsc_path, challenge: challenge)
    response.set_header(AuthIoKeys::Headers::DBSC_REGISTRATION, value)
    response.set_header(AuthIoKeys::Headers::SECURE_DBSC_REGISTRATION, value)
  end

  def find_refresh_token_record(public_id)
    return if public_id.blank?

    token_class.find_by(public_id: public_id)
  end

  def refresh_access_token(secret)
    network = OccurrenceHmac.network_hmac(request.remote_ip)
    result = AuthRefreshTokenIssuer.call(
      refresh_token: secret, resource_type: resource_type,
      precondition: ->(root) { verify_browser_refresh!(root) },
      response_builder: ->(root, raw) { build_browser_refresh(root, raw) },
    )
    unless result.success?
      clear_auth_cookies!
      return nil
    end

    credentials = result.response
    record_browser_refresh_effects(result.token, network: network)
    unless result.token.reload.active_status? && result.token.device_session_record.reload.usable?
      clear_auth_cookies!
      return nil
    end
    install_browser_refresh_cookies(result, credentials)
    @current_session = result.token
    issue_dbsc_registration_header_for(result.token, issue_challenge: true)
    credentials
  rescue RefreshRefused => e
    OpAuthorityStopCommitter.stop_root(
      root: e.root, cause: "risk", principal_public_id: e.root.principal_public_id,
      authority_evidence_ref: "browser_refresh_binding:#{e.root.public_id}",
    )
    clear_auth_cookies!
    nil
  end

  def install_browser_refresh_cookies(result, credentials)
    service = AuthenticationCookieService.new(cookies, request)
    options = service.auth_cookie_options
    cookies[AuthenticationCookieName.access] = options.merge(
      value: credentials.fetch(:access_token), expires: credentials.fetch(:access_expires_at),
    )
    cookies[AuthenticationCookieName.refresh] = options.merge(
      value: result.refresh_token, expires: result.token.discard_at,
    )
    return unless result.token.binding_method_dbsc?

    set_dbsc_cookie!(result.token.dbsc_session_id, expires_at: dbsc_cookie_expires_at_for(result.token))
  end

  def refresh_failure_status = :unauthorized

  def refresh_failure_code = "invalid_refresh_token"

  def record_browser_refresh_effects(root, network:)
    payload = browser_risk_payload(root).merge(
      ip: request.remote_ip, user_agent: request.user_agent,
      request_id: request.request_id,
    )
    SignRiskEmitter.emit("refresh_rotated", **payload)
    device = root.device_session_record
    if network.present? && device.last_network_hmac != network
      changed = device.last_network_hmac.present?
      device.update!(last_network_hmac: network)
      SignRiskEmitter.emit("ip_change_detected", **payload, meta: { reason: "network_change" }) if changed
    end
    SignRiskEnforcer.call(root)
    write_browser_refresh_audit(root)
  end

  def verify_browser_refresh!(root)
    reference = root.last_used_at || root.created_at
    raise RefreshRefused, root if reference < Time.current - SecurityTokenLifetimes.idle_ttl_for(resource_type)
    raise RefreshRefused, root unless browser_refresh_dpop_allowed?(root)
    raise RefreshRefused, root unless browser_refresh_binding_allowed?(root)
  end

  def browser_refresh_dpop_allowed?(root)
    expected = root.dpop_jkt.presence || root.device_session_record.dpop_jkt.presence
    return true unless expected

    result = DpopProofVerifier.new(
      proof_jwt: request.headers["DPoP"], request_method: request.request_method,
      request_uri: request.original_url, resource_type: resource_type,
    ).call
    result.valid? && secure_browser_value?(expected, result.jkt)
  end

  def browser_refresh_binding_allowed?(root)
    device = root.device_session_record
    return false if device.dbsc_bound? && !browser_refresh_device_proof_allowed?(root, device)

    if root.binding_method_dbsc?
      return root.dbsc_status_active? && root.dbsc_session_id.present? &&
          secure_browser_value?(root.dbsc_session_id, cookies[AuthenticationCookieName.dbsc])
    end
    return false unless root.binding_method_nothing? || root.binding_method_legacy?

    if root.binding_method_legacy? && root.dbsc_status_pending?
      issued = root.dbsc_challenge_issued_at
      root.downgrade_dbsc_status_to_nothing! if issued.nil? || issued <= Time.current - SecurityTokenLifetimes::DBSC_COOKIE_TTL
      return true
    end
    root.dbsc_status_nothing?
  end

  def browser_refresh_device_proof_allowed?(root, device)
    session_id = DbscHeaderParser.string_value(
      request.headers["Sec-Secure-Session-Id"].presence || request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID],
    )
    proof = DbscHeaderParser.string_value(
      request.headers[AuthIoKeys::Headers::SECURE_DBSC_RESPONSE].presence || request.headers[AuthIoKeys::Headers::DBSC_RESPONSE],
    )
    return false if session_id.blank? || proof.blank?

    if device.dbsc_session_id_digest.present? && !secure_browser_value?(
      device.dbsc_session_id_digest, device.class.digest_session_identifier(session_id),
    )
      return false
    end

    verified = DbscVerificationService.call(
      record: root, session_id: session_id, proof: proof, expected_audience: token_dbsc_url,
    )
    return false unless verified.fetch(:ok)

    root.update!(dbsc_challenge: nil, dbsc_challenge_issued_at: nil)
    true
  end

  def secure_browser_value?(expected, actual)
    expected.is_a?(String) && actual.is_a?(String) &&
      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def build_browser_refresh(root, _secret)
    expires_at = [Time.current + SecurityTokenLifetimes::AUTH_ACCESS_JWT_TTL, root.discard_at].min
    token = SecurityJwtAuthAccessTokenCodec.encode(
      nil, host: request.host, resource_type: resource_type, subject: root_owner_id(root).to_s,
           session_public_id: root.device_session_record.public_id, oidc_jti: root.oidc_jti,
           dpop_jkt: root.dpop_jkt.presence || root.device_session_record.dpop_jkt.presence,
           expires_at: expires_at, auth_time: root.authentication_event_at,
           authentication_context: root.strict_authentication_context_value.to_s,
           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
    )
    raise RuntimeError, "browser access token signing failed" if token.blank?

    { access_token: token, access_expires_at: expires_at, dbsc: dbsc_payload_for(root) }
  end
end
