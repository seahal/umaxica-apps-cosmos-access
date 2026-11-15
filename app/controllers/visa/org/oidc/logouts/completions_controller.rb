# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module Oidc
      module Logouts
        class CompletionsController < ::Visa::Org::AuthorityController
          include ::VisaOrgOidcLogoutEndpoint

          AUTHENTICATION_MODE = :open

          layout "visa/org/inertia"
          inertia_share chrome: -> { surface_chrome }
          inertia_share clear_history: -> { session[:inertia_clear_history] == true }
          declare_authentication_mode! :open

          public

          def show
            render_oidc_logout_completion
          end
        end
      end
    end
  end
end
