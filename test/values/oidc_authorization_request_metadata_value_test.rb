# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationRequestMetadataValueTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "canonical request metadata preserves immutable realm prompt capabilities" do
    metadata = OidcAuthorizationRequestMetadataValue

    assert_equal %w(login none create), metadata::SUPPORTED_PROMPTS
    assert_equal %w(none login create), metadata.prompt_values_supported("client")
    assert_equal %w(none login), metadata.prompt_values_supported("operator")
    assert_equal metadata.prompt_values_supported("client"), metadata.prompt_values_supported(:client)
    [nil, "", 0, "principal", "CLIENT"].each do |realm|
      assert_raises(KeyError) { metadata.prompt_values_supported(realm) }
    end
    assert_raises(FrozenError) { metadata.prompt_values_supported("client") << "new" }
    assert_raises(FrozenError) { metadata.prompt_values_supported("client").first << "changed" }
  end

  test "historical authorization prompt field validation retains its accepted and refused partitions" do
    [ClientOidcAuthorizationTransaction, OperatorOidcAuthorizationTransaction].each do |model|
      validator = model.validators_on(:oidc_prompt).find { |item| item.kind == :inclusion }
      cases = { nil => true,
                "login" => true,
                "none" => true,
                "create" => true,
                "" => false,
                "LOGIN" => false,
                "login none" => false,
                false => false,
                0 => false, }
      cases.each do |prompt, accepted|
        record = model.new(oidc_prompt: prompt)
        validator.validate(record)

        assert_equal accepted, record.errors.details[:oidc_prompt].empty?, "#{model.name}: #{prompt.inspect}"
      end
    end
  end

  test "historical step-up authorize parameters and discovery keep the same wire metadata" do
    claims = '{"id_token":{"acr":{"essential":true,"value":"https://visa.umaxica.app/acr/reauthentication"},"auth_time":{"essential":true}}}'

    assert_equal claims, OidcAuthorizationRequestMetadataValue::STEP_UP_CLAIMS
    assert_predicate OidcAuthorizationRequestMetadataValue::STEP_UP_CLAIMS, :frozen?
    [[ClientOidcAuthorizationTransaction, "client", %w(none login create)],
     [OperatorOidcAuthorizationTransaction, "operator", %w(none login)],].each do |model, realm, prompts|
      record = model.new(intent: "step_up")

      assert_equal claims, record.authorize_params.fetch(:claims)
      record.intent = "sign_in"

      assert_not record.authorize_params.key?(:claims)
      assert_equal prompts, OidcDiscoveryDocument.for_resource_type(realm).fetch(:prompt_values_supported)
    end
  end
end
