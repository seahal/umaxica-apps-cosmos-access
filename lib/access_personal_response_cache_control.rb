# frozen_string_literal: true

# Runs outside ShowExceptions and OmniAuth so refused personal requests retain their cache policy.
# Host sets mirror the Auth/Visa route boundaries; public metadata is outside these path sets.
class AccessPersonalResponseCacheControl
  SETTINGS_PATH = %r{\A/settings(?:/|\.|\z)}
  APP_SOCIAL_CALLBACK_PATH = %r{\A/social/(?:google|apple)/callback(?:\.[^/]+)?/?\z}
  ORG_SOCIAL_CALLBACK_PATH = %r{\A/social/entra/callback(?:\.[^/]+)?/?\z}
  AUTHORIZATION_PATH = %r{\A/oauth/authorize(?:\.[^/]+)?/?\z}

  public

  def initialize(app, hosts:, environment: ENV)
    @app = app
    @auth_app_hosts = host_names(hosts.auth_service.host, environment["PUBLIC_AUTH_SERVICE_URL"], "auth.app.localhost")
    @auth_org_hosts = host_names(hosts.auth_staff.host, environment["PUBLIC_AUTH_STAFF_URL"], "auth.org.localhost")
    @visa_app_hosts = host_names(hosts.visa_service.host, environment["PUBLIC_VISA_SERVICE_URL"], "visa.app.localhost")
    @visa_org_hosts = host_names(hosts.visa_staff.host, environment["PUBLIC_VISA_STAFF_URL"], "visa.org.localhost")
  end

  def call(env)
    # ShowExceptions changes PATH_INFO to the status path while producing a framework error page.
    # Use the router's normalization, which squeezes slashes without decoding escaped segments.
    path = ActionDispatch::Journey::Router::Utils.normalize_path(env.fetch("PATH_INFO"))
    status, headers, body = @app.call(env)
    host = ActionDispatch::Request.new(env).host
    return [status, headers, body] unless personal_path?(host, path)

    filtered = headers.dup
    filtered.delete_if { |name, _| name.casecmp("cache-control").zero? }
    filtered["cache-control"] = "private, no-store"
    [status, filtered, body]
  end

  private

  def host_names(origin_host, public_host, local_host)
    names = [origin_host, local_host]
    names << public_host unless public_host.nil?
    names.map!(&:downcase)
    names.uniq!
    names.freeze
  end

  def personal_path?(host, path)
    (@auth_app_hosts.include?(host) && (SETTINGS_PATH.match?(path) || APP_SOCIAL_CALLBACK_PATH.match?(path))) ||
      (@auth_org_hosts.include?(host) && ORG_SOCIAL_CALLBACK_PATH.match?(path)) ||
      ((@visa_app_hosts.include?(host) || @visa_org_hosts.include?(host)) && AUTHORIZATION_PATH.match?(path))
  end
end
