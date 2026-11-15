# typed: false
# frozen_string_literal: true

require "omniauth/strategies/apple"
require Rails.root.join("lib/external_authentication_infrastructure_omniauth_apple_nonce_enforcement").to_s

OmniAuth::Strategies::Apple.prepend(ExternalAuthenticationInfrastructureOmniauthAppleNonceEnforcement)
