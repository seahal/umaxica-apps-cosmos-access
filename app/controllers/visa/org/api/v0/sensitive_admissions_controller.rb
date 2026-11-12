# frozen_string_literal: true

module Visa
  module Org
    module Api
      module V0
        # Creates an ORG passkey O-9 admission under Visa's verified actor and grant boundary.
        class SensitiveAdmissionsController < ActionController::API
          include ::DefaultNoStore

          AUTHENTICATION_MODE = :open
          CLIENT_ID = "base-org-ww"
          RESOURCE_TYPE = "operator"

          prepend_before_action :apply_default_no_store
          before_action :authenticate_base_caller!

          public

          def create
            sensitive_admission_params
            render plain: "Service unavailable", status: :service_unavailable
          rescue ActionController::ParameterMissing
            render json: { error: "invalid_request" }, status: :bad_request
          end

          private

          def authenticate_base_caller!
            response.headers["Cache-Control"] = "no-store"
            url = "#{request.base_url}#{request.path}"
            assertion_valid = OidcClientRegistry.authenticate_assertion(
              CLIENT_ID, request.headers["X-Client-Assertion"].to_s, token_url: url,
            )
            return render(json: { error: "invalid_client" }, status: :unauthorized) unless assertion_valid

            auth = OidcAccessTokenAuthenticator.call(
              access_token: request.authorization.to_s.delete_prefix("Bearer "),
              resource_type: RESOURCE_TYPE, host: request.host, authorization_scheme: "Bearer",
            )
            unless auth.success? && auth.payload["client_id"] == CLIENT_ID && auth.token.is_a?(OperatorToken)
              return render(json: { error: "invalid_token" }, status: :unauthorized)
            end

            grant =
              OpOrgGrant.connection_class_for_self.connected_to(role: :writing) do
                OpOrgGrant.uncached do
                  OpOrgGrant.find_by(public_id: auth.payload["sid"], oidc_client_id: CLIENT_ID)
                end
              end
            unless sensitive_admission_binding_valid?(auth, grant)
              render json: { error: "invalid_token" }, status: :unauthorized
            end
          rescue ActiveRecord::ActiveRecordError, PG::Error => e
            Rails.logger.error(
              "visa.sensitive_admission_authentication_unavailable error_class=#{e.class.name} realm=org",
            )
            render json: { error: "temporarily_unavailable" }, status: :service_unavailable
          end

          def sensitive_admission_binding_valid?(auth, grant)
            device = auth.device
            grant&.active? && device.usable? && device.current_refresh_token_id == auth.token.id &&
              grant.operator_token_id == auth.token.id && grant.device_session_id == device.id
          end

          def sensitive_admission_params
            {
              rp_session_ref: params.expect(:rp_session_ref),
              rp_session_expires_at: params.expect(:rp_session_expires_at),
              browser_binding_digest: params.expect(:browser_binding_digest),
              purpose: params.expect(:purpose),
              provider: params.expect(:provider),
              response_type: params.expect(:response_type),
              client_id: params.expect(:client_id),
              redirect_uri: params.expect(:redirect_uri),
              scope: params.expect(:scope),
              state: params.expect(:state),
              nonce: params.expect(:nonce),
              code_challenge: params.expect(:code_challenge),
              code_challenge_method: params.expect(:code_challenge_method),
              claims: params.expect(:claims),
              prompt: params[:prompt],
              max_age: params[:max_age],
              ri: params[:ri],
            }
          end
        end
      end
    end
  end
end
