# typed: false
# frozen_string_literal: true

# Handles only the public OIDC authorization request and its initial Auth handoff.
module OidcAuthorizationStart
  extend ActiveSupport::Concern

  included do
    rescue_from GovernanceLookupUnavailableError, with: :render_sign_in_authority_unavailable!
  end

  private

  def process_authorization_start!
    validate_authorization_start_parameters!
    validate_authorization_request!
    if @validated_authorization_request.step_up_requested
      raise OidcAuthorizeRequestResolver::UnmetAuthenticationRequirements,
            "requested authentication class is not available"
    end
    return redirect_login_required! if @validated_authorization_request.prompt == "none"
    return render_front_channel_issuance_unavailable! if
      @validated_authorization_request.client.front_channel_id_token?

    start_authorization_handoff!
  rescue OidcAuthorizeRequestResolver::UnsupportedPrompt => e
    render_unsupported_prompt!(e)
  rescue OidcAuthorizeRequestResolver::RequestError => e
    redirect_authorization_request_error!(e)
  rescue BaseAuthAdmissionCoordinator::Denied
    render_invalid_authorization_request!
  rescue ArgumentError, OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri => e
    render json: { error: "invalid_request", error_description: e.message }, status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
    render_authorization_backend_failure!(e)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.authorize.invalid_request", surface: authorization_surface,
                                          error_class: e.class.name, request_id: request.request_id,
      ),
    )
    render_invalid_authorization_request!
  end

  def validate_authorization_start_parameters!
    raise ActionController::RoutingError, "authorization route does not match its Visa realm" unless
      request.path == authorization_route_path
    raise ArgumentError, "HEAD is not accepted at authorization start" if request.head?

    forbidden = %w(
      result result_ref transaction_ref cancellation_ref switch_handoff continuation
      step_up_result_ref step_up_cancellation_ref step_up_ticket_ref step_up_context_ref restart_of
    )
    raise ArgumentError, "continuation parameters are not accepted at authorization start" if
      forbidden.any? { |key| params.key?(key) }
  end

  def validate_authorization_request!
    @validated_authorization_request = OidcAuthorizeRequestResolver.call(
      params: authorize_params,
      duplicate_parameters: authorization_duplicate_parameters,
      resource: authorization_resource_for_validation,
      resource_type: authorization_resource_type,
    )
  end

  def start_authorization_handoff!
    issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
      surface: authorization_surface,
      intent: authorization_intent,
      params: authorize_params,
      base_browser_nonce: base_admission_browser_nonce_for_request!,
      base_token: current_session,
    )
    redirect_to_jump_url(authorization_sentry_url(entry_ref: issuance.handoff.reference), status: :see_other)
  end

  def authorization_intent
    client_id = authorize_params[:client_id].to_s
    return "authentication" if AuthBoundaryAuthorityMap.first_party_rp_client_ids.include?(client_id)

    "sign_in"
  end

  def authorize_params
    keys = OidcAuthorizeRequestResolver::PARAMETER_NAMES
    params.slice(*keys).permit(*keys)
  end

  def render_invalid_authorization_request!
    render json: { error: "invalid_request", error_description: "invalid authorization request" }, status: :bad_request
  end

  def render_front_channel_issuance_unavailable!
    render json: {
      error: "temporarily_unavailable",
      error_description: "Base front-channel ID Token issuance is unavailable",
    }, status: :service_unavailable
  end

  def render_sign_in_authority_unavailable!
    render json: {
      error: "temporarily_unavailable", error_description: "Sign-in authority is unavailable",
    }, status: :service_unavailable
  end

  def render_authorization_backend_failure!(error)
    Rails.logger.error(
      JitLogEvent.format(
        "oidc.authorize.backend_failure", surface: authorization_surface,
                                          error_class: error.class.name, request_id: request.request_id,
      ),
    )
    render json: {
      error: "temporarily_unavailable", error_description: I18n.t("errors.rate_limit.backend_unavailable"),
    }, status: :service_unavailable
  end

  def authorization_resource_for_validation
    resource = authorization_resource
    return if resource.nil?
    return resource if resource.is_a?(authorization_resource_class)

    raise TypeError, "authorization session resource does not match its realm"
  end

  def authorization_route_path
    raise NotImplementedError, "authorization_route_path must be implemented by the Visa realm controller"
  end

  def authorization_surface
    raise NotImplementedError, "authorization_surface must be implemented by the Visa realm controller"
  end

  def authorization_auth_host
    raise NotImplementedError, "authorization_auth_host must be implemented by the Visa realm controller"
  end

  def authorization_resource
    raise NotImplementedError, "authorization_resource must be implemented by the Visa realm controller"
  end

  def authorization_resource_class
    raise NotImplementedError, "authorization_resource_class must be implemented by the Visa realm controller"
  end

  def authorization_resource_type
    raise NotImplementedError, "authorization_resource_type must be implemented by the Visa realm controller"
  end

  def authorization_sentry_url(entry_ref:)
    raise NotImplementedError, "authorization_sentry_url must be implemented by the Visa realm controller"
  end
end
