# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      module Logouts
        class ConfirmationsController < ::Visa::App::AuthorityController
          include ::VisaAppOidcLogoutEndpoint

          AUTHENTICATION_MODE = :open

          layout "visa/app/inertia"
          inertia_share chrome: -> { surface_chrome }
          inertia_share clear_history: -> { session[:inertia_clear_history] == true }
          declare_authentication_mode! :open

          public

          def create
            confirm_oidc_end_session_logout
          end

          private

          def allow_expired_session_access? = true
        end
      end
    end
  end
end
