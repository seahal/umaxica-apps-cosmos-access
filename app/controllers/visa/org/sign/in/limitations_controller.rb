# frozen_string_literal: true

module Visa
  module Org
    module Sign
      module In
        class LimitationsController < ::Visa::Org::AuthorityController
          include ::SurfaceInertiaPage
          include ::VisaSignInLimitations

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :load_resolution

          private

          def actor_class = Operator

          def token_class = OperatorToken

          def ticket_record = OpBaseOrgRecord

          def resolution_transaction_class = OperatorSessionLimitResolutionTransaction

          def actor_foreign_key = :staff_id

          def limitation_component = "visa/org/sign/in/limitations/show"

          def limitation_path(params = {}) = visa_org_sign_in_limitation_path(**params)
        end
      end
    end
  end
end
