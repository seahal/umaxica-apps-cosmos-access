# frozen_string_literal: true

class OidcAuthorizationCodeIssuer < ApplicationService
  def initialize(client:, params:, resource:, session_token:, auth_method: nil, acr: nil,
                 authentication_event_at: nil, authorization_transaction_ref: nil, store: nil)
    super()
  end

  def call
    raise GovernanceLookupUnavailableError, "Governance authorization code authority is unavailable"
  end
end
