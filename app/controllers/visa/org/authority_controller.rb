# typed: false
# frozen_string_literal: true

module Visa
  module Org
    # Visa's Org browser authority owns its root-session lifecycle independently of Base.
    class AuthorityController < ::ApplicationController
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore
      include ::JumpRtReturnVerification
      include ::AuthenticationBase
      include ::OpBrowserSessionRequest
      include ::VisaBrowserRequestContext
      include ::SignErrorResponses

      AUTHENTICATION_MODE = :deny_all

      class << self
        public

        def base_admission_surface_name = "org"
      end

      layout "visa/org/application"

      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      helper_method :current_session_public_id, :logged_in?

      allow_browser versions: :modern

      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "visa_org_authority_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
      before_action :normalize_visa_browser_region!
      around_action :with_visa_request_locale
      before_action :enforce_op_boundary_mode!

      # Rails validates Origin and Fetch Metadata first; require its session-bound token before surface callbacks.
      prepend_before_action :require_authenticity_token_for_unsafe_request!
      protect_from_forgery using: :header_or_legacy_token, with: :exception, prepend: true
      ensure_fqdn_gate_first!
      prepend_before_action :apply_default_no_store
      prepend_around_action :with_request_actor_lifecycle

      private

      def resource_type = "operator"

      def token_class = OperatorToken

      def root_owner_id(root) = root.subject_public_id

      def browser_risk_payload(root) = { staff_id: root.subject_public_id, user_token_id: root.public_id }

      def write_browser_refresh_audit(root)
        AuthenticationAuditWriter.write_reference(
          OperatorChronicle, OperatorChronicleEvent::TOKEN_REFRESHED,
          subject_type: "Operator", subject_id: root.subject_public_id.to_s,
          actor_type: "Operator", actor_id: root.subject_public_id.to_s,
          context: { session_public_id: root.device_session_record.public_id },
        )
      end

      def token_dbsc_path = dbsc_canonical_url(visa_org_edge_v0_token_dbsc_path)

      def token_dbsc_url = dbsc_canonical_url(visa_org_edge_v0_token_dbsc_url)

      def require_authenticity_token_for_unsafe_request!
        return unless protect_against_forgery?
        return if request.get? || request.head? || verified_query_request?
        return if any_authenticity_token_valid?

        instrument_unverified_request
        handle_unverified_request
      end

      def sign_in_url_with_target(_return_to)
        raise ActionController::BadRequest, "No OIDC authorization return is available"
      end

      def after_login_path
        raise ActionController::BadRequest, "No OIDC authorization return is available"
      end

      def oidc_sign_host
        ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      end

      def actor_verification_path(**args)
        auth_org_verification_url(**args, host: oidc_sign_host, protocol: "https")
      end

      def actor_verification_setup_path(**args)
        new_auth_org_verification_setup_url(**args, host: oidc_sign_host, protocol: "https")
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end
end
