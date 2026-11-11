# frozen_string_literal: true

require "test_helper"

class StepUpCeremonyObservabilityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @original_logger = Rails.logger
    @log = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log)
  end

  teardown do
    Rails.logger = @original_logger
  end

  test "an Auth ceremony page opened without an OIDC step-up context is refused generically and logged" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.headers["Location"]
    refusal = @log.string.lines.filter_map do |line|
      JSON.parse(line) if line.start_with?('{"event":"auth.step_up.refused"')
    end.sole.fetch("data")

    assert_equal "invalid_admission", refusal.fetch("error_code")
    assert_equal "auth_ceremony_context", refusal.fetch("stage")
    assert_equal "refused", refusal.fetch("outcome")
    assert_not refusal.key?("ceremony_ref")
    assert_not_includes response.body, "invalid_admission"
  end
end
