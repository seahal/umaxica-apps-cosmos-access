# typed: false
# frozen_string_literal: true

module OidcClientStoresStaticClientStore
  LOOPBACK_HOST_TOKENS = %w(localhost 127.0.0.1 ::1).freeze
  private_constant :LOOPBACK_HOST_TOKENS

  module_function

  def clients
    first_party_browser_rp_clients
      .freeze
  end

  # First-party Browser RP clients use independent audiences, keys, callbacks, and RP sessions.
  # Specs are keyed by family-realm; the exact Client ID (and its audience) comes from the trusted
  # deployment binding, so a JP process registers core-app-jp and never a US or unsuffixed ID.
  def first_party_browser_rp_clients
    FIRST_PARTY_RP_SPECS.to_h do |family_realm, spec|
      client_id = RpDeploymentBindingValue.client_id(family_realm)
      # Key namespace follows the exact Client ID (core-app-jp -> CORE_APP_JP); only the Base
      # Self-RPs keep their explicit BASE_RP_* namespaces.
      jwt_namespace = spec.fetch(:jwt_namespace) { client_id.upcase.tr("-", "_") }
      [client_id, face_rp_client(**spec, aud: client_id, jwt_namespace:)]
    end
  end

  FIRST_PARTY_RP_SPECS = {
    "core-app" => {
      env_key: "PUBLIC_CORE_SERVICE_URL",
      resource_type: "client",
      name: "Core App RP",
    },
    "core-org" => {
      env_key: "PUBLIC_CORE_STAFF_URL",
      resource_type: "operator",
      name: "Core Org RP",
    },
    "warp-app" => {
      env_key: "PUBLIC_WARP_SERVICE_URL",
      resource_type: "client",
      name: "Warp App RP",
    },
    "warp-org" => {
      env_key: "PUBLIC_WARP_STAFF_URL",
      resource_type: "operator",
      name: "Warp Org RP",
    },
    "edit-org" => {
      env_key: "PUBLIC_EDIT_STAFF_URL",
      resource_type: "operator",
      name: "Edit Org RP",
    },
    "palm-app" => {
      env_key: "PUBLIC_PALM_SERVICE_URL",
      resource_type: "client",
      name: "Palm App RP",
    },
    "tech-org" => {
      env_key: "PUBLIC_TECH_STAFF_URL",
      resource_type: "operator",
      name: "Tech Org RP",
      required_operator_capability: OperatorCapabilityGrant::TECH_ACCESS,
    },
    "base-app" => {
      env_key: "PUBLIC_BASE_SERVICE_URL",
      resource_type: "client",
      name: "Base App Self RP",
      jwt_namespace: "BASE_RP_APP_WW",
      step_up_callback_path: AuthBoundaryAuthorityMap.step_up_callback_path_for("base-app-ww"),
    },
    "base-org" => {
      env_key: "PUBLIC_BASE_STAFF_URL",
      resource_type: "operator",
      name: "Base Org Self RP",
      jwt_namespace: "BASE_RP_ORG_WW",
      step_up_callback_path: AuthBoundaryAuthorityMap.step_up_callback_path_for("base-org-ww"),
    },
  }.freeze

  RP_BACKCHANNEL_LOGOUT_PATH = "/oidc/closures"

  # The frozen back-channel logout endpoint for an active first-party RP (R5-WU10, one.md 7.6).
  # It is derived from the same registered host as the RP callback; no logout delivery target is
  # ever taken from a grant, token or request.
  def backchannel_logout_uri(client_id)
    family_realm, spec =
      FIRST_PARTY_RP_SPECS.find { |key, _|
      RpDeploymentBindingValue.client_id(key) == client_id.to_s
    }
    raise KeyError, "no registered back-channel logout endpoint for #{client_id.inspect}" unless family_realm

    build_redirect_uris(spec.fetch(:env_key), path: RP_BACKCHANNEL_LOGOUT_PATH).first
  end

  def face_rp_client(env_key:, resource_type:, aud:, name:, jwt_namespace:,
                     callback_path: AuthBoundaryAuthorityMap::CANONICAL_RP_CALLBACK_PATH,
                     step_up_callback_path: nil,
                     sign_out_path: AuthBoundaryAuthorityMap::CANONICAL_RP_SIGN_OUT_PATH,
                     required_operator_capability: nil)
    callback_paths = [callback_path, step_up_callback_path].compact
    callback_paths.uniq!
    {
      redirect_uris_by_realm: {
        resource_type => callback_paths.flat_map do |path|
          build_redirect_uris(env_key, path: path)
        end,
      },
      post_logout_redirect_uris: build_post_logout_redirect_uris(
        env_key, path: sign_out_path,
      ),
      aud: aud,
      resource_type: resource_type,
      name: name,
      allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      token_endpoint_auth_method: "private_key_jwt",
      jwt_namespace: jwt_namespace,
      required_operator_capability: required_operator_capability,
    }
  end

  # These URLs identify external RP callback destinations. They are deliberately not part of
  # Access's host allowlist or route constraints.
  def build_redirect_uris(env_key, path: "/oidc/callback")
    configured_hosts_for(env_key).map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      validate_registered_redirect_uri!("#{protocol}://#{host}#{port_suffix}#{path}")
    end
  end

  RESERVED_REDIRECT_QUERY_KEYS = %w(code state iss error error_description error_uri session_state).freeze

  # D-147 N-4: an invalid registration stops the boot (RFC 6749 3.1.2 absolute, no fragment;
  # TLS in production, RFC 6749 3.1.2.1 and RFC 9700 2.1; no reserved query key, UMAXICA).
  def validate_registered_redirect_uri!(value)
    uri = URI.parse(value)
    valid = uri.absolute? && uri.host.present? && uri.fragment.nil? && uri.userinfo.nil? &&
      %w(http https).include?(uri.scheme) && (!Rails.env.production? || uri.scheme == "https") &&
      (URI.decode_www_form(uri.query.to_s).map(&:first) & RESERVED_REDIRECT_QUERY_KEYS).empty?
    raise ArgumentError, "invalid registered redirect_uri: #{value}" unless valid

    value
  rescue URI::InvalidURIError
    raise ArgumentError, "invalid registered redirect_uri: #{value}"
  end

  def build_post_logout_redirect_uris(env_key,
                                      path: AuthBoundaryAuthorityMap::CANONICAL_RP_SIGN_OUT_PATH)
    configured_hosts_for(env_key).flat_map do |host|
      protocol = (Rails.env.production? || public_host?(host)) ? "https" : "http"
      port_suffix = (Rails.env.production? || public_host?(host)) ? "" : ":3000"
      RequestContextContract.allowed_regions.map do |region|
        "#{protocol}://#{host}#{port_suffix}#{path}?ri=#{region}"
      end
    end
  end

  def public_host?(host)
    normalized_host = URI.parse("//#{host}").host.to_s

    normalized_host.present? &&
      LOOPBACK_HOST_TOKENS.none? { |token| normalized_host.include?(token) }
  rescue URI::InvalidURIError
    false
  end

  def configured_hosts_for(env_keys)
    hosts =
      Array(env_keys).map do |env_key|
        env_host = ENV.fetch(env_key)
        raise ArgumentError, "#{env_key} must be a configured public RP origin" if env_host.blank?

        env_host
      end
    hosts.map! { |host| normalize_host(host) }
    hosts.uniq!
    hosts
  end

  def normalize_host(host)
    parsed_host = URI.parse(host.to_s).host if host.to_s.include?("://")
    parsed_host.presence || URI.parse("//#{host}").host.to_s.presence || host.to_s
  rescue URI::InvalidURIError
    host.to_s
  end

  private_class_method :first_party_browser_rp_clients, :face_rp_client, :build_redirect_uris,
                       :build_post_logout_redirect_uris,
                       :public_host?, :configured_hosts_for,
                       :normalize_host, :validate_registered_redirect_uri!
end
