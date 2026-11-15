# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oauth
      class AuthorizationsController < ::Visa::App::AuthorityController
        include ::OauthAuthorizeRateLimit
        include ::OauthAuthorizeRequestSizeLimit
        include ::OidcAuthorizationRequestErrors
        include ::OidcAuthorizationStart
        include ::BaseAdmissionBrowserBinding

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        skip_before_action :normalize_visa_browser_region!, raise: false

        before_action :enforce_oauth_authorize_request_size!, only: %i(show create)
        before_action :enforce_oauth_authorize_rate_limits!, only: %i(show create)

        public

        def show
          process_authorization_start!
        end

        def create
          process_authorization_start!
        end

        private

        def apply_default_no_store
          super
          response.headers["Referrer-Policy"] = "no-referrer"
        end

        def authorization_route_path = visa_app_oauth_authorization_path

        def authorization_surface = "app"

        def authorization_resource = current_session

        def authorization_resource_class = ClientToken

        def authorization_resource_type = "client"

        def authorization_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

        def authorization_sentry_url(entry_ref:)
          auth_app_sign_in_sentry_url(
            entry_ref: entry_ref,
            ri: params[:ri],
            host: authorization_auth_host,
            protocol: "https",
          )
        end
      end
    end
  end
end
