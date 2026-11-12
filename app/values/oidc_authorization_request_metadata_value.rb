# frozen_string_literal: true

module OidcAuthorizationRequestMetadataValue
  SUPPORTED_PROMPTS = %w(login none create).map(&:freeze).freeze
  PROMPTS_BY_RESOURCE_TYPE = {
    "client" => %w(none login create).map(&:freeze).freeze,
    "operator" => %w(none login).map(&:freeze).freeze,
  }.freeze
  STEP_UP_ACR = "https://visa.umaxica.app/acr/reauthentication".freeze
  STEP_UP_CLAIMS = JSON.generate(
    "id_token" => {
      "acr" => { "essential" => true, "value" => STEP_UP_ACR },
      "auth_time" => { "essential" => true },
    },
  ).freeze

  module_function

  def prompt_values_supported(resource_type)
    PROMPTS_BY_RESOURCE_TYPE.fetch(resource_type.to_s)
  end
end
