# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class EmailValidationCoverageTest < ActiveSupport::TestCase
  test "valid_email?" do
    assert JitUtilsEmailValidator.valid?("test@example.com")
    assert_not JitUtilsEmailValidator.valid?("invalid")
  end

  test "validate_and_normalize_email" do
    assert_equal "test@example.com", JitUtilsEmailValidator.normalize(" TEST@example.com ")
    assert_nil JitUtilsEmailValidator.normalize("invalid")
  end
end
