# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Api
      module V0
        # Authenticates OP-bound requests before refusing unavailable ceremony transitions.
        class SensitiveAdmissionSessionsController < ActionController::API
          include ::DefaultNoStore

          AUTHENTICATION_MODE = :open
          CLIENT_ID = "base-app-ww"
          RESOURCE_TYPE = "client"

          prepend_before_action :apply_default_no_store
          before_action :authenticate_base_caller!

          public

          def create
            admission_ref = params.expect(:admission_ref)
            rp_session_ref = params.expect(:rp_session_ref)
            browser_binding_digest = params.expect(:browser_binding_digest)
            unless admission_ref.is_a?(String) &&
                admission_ref.match?(ClientVisaSensitiveAdmission::PUBLIC_REF_PATTERN) &&
                rp_session_ref.is_a?(String) && rp_session_ref.present? && rp_session_ref.length <= 64 &&
                browser_binding_digest.is_a?(String) &&
                browser_binding_digest.match?(ClientVisaSensitiveAdmission::DIGEST_PATTERN)
              return render_bad_request
            end

            render plain: "Service unavailable", status: :service_unavailable
          rescue ActionController::ParameterMissing
            render_bad_request
          end

          def update
            reference = params.expect(:rp_session_ref)
            unless reference.is_a?(String) && reference.match?(ClientVisaSensitiveAdmission::PUBLIC_REF_PATTERN)
              return render_bad_request
            end

            render plain: "Service unavailable", status: :service_unavailable
          rescue ActionController::ParameterMissing
            render_bad_request
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
            unless auth.success? && auth.payload["client_id"] == CLIENT_ID && auth.token.is_a?(ClientToken)
              return render(json: { error: "invalid_token" }, status: :unauthorized)
            end

            grant =
              OpAppGrant.connection_class_for_self.connected_to(role: :writing) do
                OpAppGrant.uncached do
                  OpAppGrant.find_by(public_id: auth.payload["sid"], oidc_client_id: CLIENT_ID)
                end
              end
            unless sensitive_admission_binding_valid?(auth, grant)
              render json: { error: "invalid_token" }, status: :unauthorized
            end
          rescue ActiveRecord::ActiveRecordError, PG::Error => e
            Rails.logger.error(
              "visa.sensitive_admission_authentication_unavailable error_class=#{e.class.name} realm=app",
            )
            render json: { error: "temporarily_unavailable" }, status: :service_unavailable
          end

          def render_bad_request
            render json: { error: "invalid_request" }, status: :bad_request
          end

          def sensitive_admission_binding_valid?(auth, grant)
            device = auth.device
            grant&.active? && device.usable? && device.current_refresh_token_id == auth.token.id &&
              grant.client_token_id == auth.token.id && grant.device_session_id == device.id
          end
        end
      end
    end
  end
end
