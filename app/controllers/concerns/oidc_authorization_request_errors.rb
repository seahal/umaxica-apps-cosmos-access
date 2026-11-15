# typed: false
# frozen_string_literal: true

# Shared delivery for errors after the client and its exact redirect URI are trusted.
module OidcAuthorizationRequestErrors
  extend ActiveSupport::Concern

  private

  def authorization_duplicate_parameters
    pairs = URI.decode_www_form(request.query_string)
    if request.post? && request.form_data?
      form_pairs = request.request_parameters_list
      raise ActionController::BadRequest, "authorization form field names are unavailable" if form_pairs.nil?

      pairs.concat(form_pairs.to_a)
    end

    pairs.map(&:first).tally.filter_map do |name, count|
      name if count > 1 && OidcAuthorizeRequestResolver::PARAMETER_NAMES.include?(name)
    end
  end

  def redirect_authorization_request_error!(error)
    url = OidcAuthorizeCoordinator.error_redirect_url(
      redirect_uri: authorize_params[:redirect_uri].to_s,
      resource_type: authorization_resource_type,
      error: error.error,
      state: authorize_params[:state],
    )
    redirect_to_same_origin_or_jump_url(url)
  end

  def redirect_login_required!
    url = OidcAuthorizeCoordinator.error_redirect_url(
      redirect_uri: authorize_params[:redirect_uri].to_s,
      resource_type: authorization_resource_type,
      error: "login_required",
      state: authorize_params[:state],
    )
    redirect_to_same_origin_or_jump_url(url)
  end

  def render_unsupported_prompt!(error)
    render json: { error: "invalid_request", error_description: "prompt: #{error.message}" }, status: :bad_request
  end
end
