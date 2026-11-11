# typed: false
# frozen_string_literal: true

module OutboundHttp
  # Visa's OP endpoints resolve to this process in local development. HTTPS terminates at the
  # tunnel, so an in-process back-channel request uses the local HTTP port. Production keeps the
  # public HTTPS URL unchanged.
  module LocalBackChannel
    module_function

    def url(public_url)
      return public_url unless Rails.env.local?

      uri = URI.parse(public_url)
      return public_url unless uri.is_a?(URI::HTTP) && first_party_host?(uri.host)

      uri.scheme = "http"
      uri.port = local_port
      uri.to_s
    rescue URI::InvalidURIError
      public_url
    end

    # HTTPS is required except for the exact local form `url` produces.
    def require_https?(url)
      return true unless Rails.env.local?

      uri = URI.parse(url)
      !(uri.scheme == "http" && first_party_host?(uri.host) && uri.port == local_port && uri.userinfo.blank?)
    rescue URI::InvalidURIError
      true
    end

    def first_party_host?(host)
      hosts = Rails.configuration.x.boot_config.fetch(:hosts)
      [hosts.visa_service, hosts.visa_staff].map do |configured|
        configured.host.to_s.downcase
      end.include?(host.to_s.downcase)
    end

    def local_port
      Integer(ENV.fetch("PORT"), exception: false) || 3000
    end
  end
end
