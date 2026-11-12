# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module Oidc
      class LogoutsController < Visa::Org::AuthorityController
        include ::VisaOrgOidcLogoutEndpoint

        AUTHENTICATION_MODE = :open

        layout -> { @render_surface_erb_layout ? "visa/org/application" : "visa/org/inertia" }
        declare_authentication_mode! :open

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
