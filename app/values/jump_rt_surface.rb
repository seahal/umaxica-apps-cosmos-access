# typed: false
# frozen_string_literal: true

module JumpRtSurface
  module_function

  # Auth and Visa own signing identities. External RP origins remain available only to validate
  # approved OIDC return destinations.
  # Each issuer identity comes from the existing public surface setting; there is no Jump-specific
  # issuer-origin setting.
  ISSUER_ORIGIN_ENV = {
    "AUTH_APP" => "PUBLIC_AUTH_SERVICE_URL",
    "AUTH_ORG" => "PUBLIC_AUTH_STAFF_URL",
    "VISA_APP" => "PUBLIC_VISA_SERVICE_URL",
    "VISA_ORG" => "PUBLIC_VISA_STAFF_URL",
  }.freeze
  RETURN_ORIGIN_ENV = ISSUER_ORIGIN_ENV.merge(
    "BASE_APP" => "PUBLIC_BASE_SERVICE_URL",
    "BASE_ORG" => "PUBLIC_BASE_STAFF_URL",
    "CORE_APP" => "PUBLIC_CORE_SERVICE_URL",
    "CORE_ORG" => "PUBLIC_CORE_STAFF_URL",
    "WARP_APP" => "PUBLIC_WARP_SERVICE_URL",
    "WARP_ORG" => "PUBLIC_WARP_STAFF_URL",
    "PALM_APP" => "PUBLIC_PALM_SERVICE_URL",
  ).freeze
  BOOT_HOST_FIELDS = { "VISA_APP" => :visa_service, "VISA_ORG" => :visa_staff }.freeze
  ISSUER_NAMESPACES = ISSUER_ORIGIN_ENV.keys.freeze
  RETURN_ORIGIN_NAMESPACES = RETURN_ORIGIN_ENV.keys.freeze

  JWKS_PATH = "/.well-known/jwks.json"

  # The issuer origin is also the Jump return origin for the namespace. Rails.env plays no part: the
  # identity is whatever PUBLIC_* origin publishes this instance's active signing key in its JWKS.
  def issuer_origin(namespace, env: ENV)
    normalized_namespace = normalize_issuer_namespace(namespace)
    name = ISSUER_ORIGIN_ENV.fetch(normalized_namespace)
    raw = env[name]
    from_local_boot = raw.blank? && env.equal?(ENV) && Rails.env.local?
    raw = local_boot_origin(normalized_namespace) if from_local_boot
    raise JumpRtConfigurationError, "#{name} is required for Jump issuance" if raw.blank?

    raw = raw.to_s
    candidate = raw.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? raw : "https://#{raw}"
    begin
      from_local_boot ? ConfigValues.build(
        candidate,
        allow_localhost: true,
      ).to_s : ConfigValues.public_https_origin(candidate)
    rescue ArgumentError => e
      raise JumpRtConfigurationError, "#{name} must be a public HTTPS origin for Jump: #{e.message}"
    end
  end

  def return_origin(namespace, env: ENV)
    normalized_namespace = namespace.to_s.upcase
    name = RETURN_ORIGIN_ENV.fetch(normalized_namespace)
    raw = env.fetch(name)
    candidate = raw.to_s.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? raw.to_s : "https://#{raw}"
    ConfigValues.public_https_origin(candidate)
  rescue ArgumentError, KeyError => e
    raise JumpRtConfigurationError, "#{name} is required as a public HTTPS return origin: #{e.message}"
  end

  def issuer_jwks_uri(namespace, env: ENV)
    "#{issuer_origin(namespace, env: env)}#{JWKS_PATH}"
  end

  # Only Auth and Visa controllers issue Jump return tokens.
  def namespace_for_controller(controller_class_name)
    service =
      case controller_class_name.to_s
      when /\AAuth::/ then "AUTH"
      when /\AVisa::/ then "VISA"
      end
    surface =
      case controller_class_name.to_s
      when /\A\w+::App::/ then "APP"
      when /\A\w+::Org::/ then "ORG"
      end
    if service.nil? || surface.nil?
      raise JumpRtConfigurationError,
            "No Jump RT issuer namespace is configured for controller #{controller_class_name.inspect}"
    end

    normalize_issuer_namespace("#{service}_#{surface}")
  end

  def normalize_issuer_namespace(namespace)
    value = namespace.to_s.upcase
    unless ISSUER_ORIGIN_ENV.key?(value)
      raise JumpRtConfigurationError, "unsupported Jump RT issuer surface: #{namespace.inspect}"
    end

    value
  end

  def normalize_host(host)
    host.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first
  end

  def local_boot_origin(namespace)
    field = BOOT_HOST_FIELDS.fetch(namespace, nil)
    return unless field

    Rails.configuration.x.boot_config.fetch(:hosts).public_send(field).to_s
  rescue NoMethodError, KeyError
    nil
  end
end
