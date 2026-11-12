# typed: false
# frozen_string_literal: true

class OidcAuthorizeCoordinator < ApplicationService
  Result =
    Data.define(:success, :redirect_url, :redirect_uri, :error, :error_description) do
      def success? = success
    end

  def initialize(params:, resource:, session_token:, auth_method: nil, acr: nil, authentication_event_at: nil,
                 authorization_transaction_ref: nil)
    super()
  end

  def call
    Result.new(
      success: false, redirect_url: nil, redirect_uri: nil, error: "temporarily_unavailable",
      error_description: "Governance authorization code authority is unavailable",
    )
  end

  class << self
    public

    # Builds an authorization response redirect to an already validated RP redirect_uri.
    # Callers must validate the client and redirect_uri first (OidcAuthorizeRequestResolver).
    def rp_redirect_url(redirect_uri:, resource_type:, response_params:)
      # RFC 9207: identify the issuing authorization server in the response so a
      # client registered against more than one AS cannot be tricked into sending
      # the code to the wrong one (RFC 9700 section 4.4.2, mix-up attack).
      params = response_params + [["iss", OidcIssuer.for_resource_type(resource_type)]]
      # RFC 6749 3.1.2: keep the registered URI as is and append the response parameters (N-2).
      separator = URI.parse(redirect_uri).query.nil? ? "?" : "&"
      "#{redirect_uri}#{separator}#{URI.encode_www_form(params)}"
    end

    # OIDC Core 1.0 section 3.1.2.6: authentication errors such as login_required are
    # returned to the RP redirect_uri with the original state, not rendered locally.
    def error_redirect_url(redirect_uri:, resource_type:, error:, state: nil)
      response_params = [["error", error]]
      response_params << ["state", state] if state.present?
      rp_redirect_url(redirect_uri: redirect_uri, resource_type: resource_type, response_params: response_params)
    end
  end
end
