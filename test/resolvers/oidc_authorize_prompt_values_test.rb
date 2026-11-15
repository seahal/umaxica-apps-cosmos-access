# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizePromptValuesTest < ActiveSupport::TestCase
  test "client prompts match the accepted APP and COM authorization profile" do
    prompts = OidcAuthorizeRequestResolver.prompt_values_supported("client")

    assert_equal %w(none login create), prompts
    assert_predicate prompts, :frozen?
    assert prompts.all?(&:frozen?)
  end

  test "operator prompts match the accepted ORG authorization profile" do
    prompts = OidcAuthorizeRequestResolver.prompt_values_supported("operator")

    assert_equal %w(none login), prompts
    assert_predicate prompts, :frozen?
    assert prompts.all?(&:frozen?)
  end

  test "an unknown authorization resource fails instead of receiving default prompts" do
    assert_raises(KeyError) do
      OidcAuthorizeRequestResolver.prompt_values_supported("unknown")
    end
  end
end
