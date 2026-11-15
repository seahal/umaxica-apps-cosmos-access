# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      class LogoutsController < Visa::App::AuthorityController
        include ::VisaAppOidcLogoutEndpoint

        AUTHENTICATION_MODE = :open

        layout "visa/app/inertia"
        inertia_share chrome: -> { surface_chrome }
        inertia_share clear_history: -> { session[:inertia_clear_history] == true }
        declare_authentication_mode! :open
        after_action :sign_out_notice_cache_headers!, only: %i(show create)

        public

        def show
          handle_oidc_end_session_request
        end

        def create
          handle_oidc_end_session_request
        end

        private

        def allow_expired_session_access? = true
      end
    end
  end
end
