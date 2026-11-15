# typed: false
# frozen_string_literal: true

# Bounds authorization input before it reaches request resolution or persistence.
module OauthAuthorizeRequestSizeLimit
  extend ActiveSupport::Concern

  MAX_PARAMETER_BYTES = 2048
  MAX_QUERY_BYTES = 8192

  private

  def enforce_oauth_authorize_request_size!
    return unless oauth_authorize_request_oversized?

    render json: { error: "invalid_request", error_description: "authorization request is too large" },
           status: :bad_request
  end

  def oauth_authorize_request_oversized?
    return true if request.query_string.bytesize > MAX_QUERY_BYTES

    request.query_parameters.any? do |_name, value|
      !value.is_a?(String) || value.bytesize > MAX_PARAMETER_BYTES
    end
  end
end
