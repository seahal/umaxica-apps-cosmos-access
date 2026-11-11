# typed: false
# frozen_string_literal: true

require "test_helper"

# Focused arms that close the remaining ~0.5-1.2 branch points to the 90% floor.
# Prefer calling real methods; stubs only fill collaborators.
class BranchCoverageBatch37ThresholdCloseTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "AppleOnlyCredentialStatus returns false for blank client" do
    assert_not AppleOnlyCredentialStatus.call(nil)
    assert_not AppleOnlyCredentialStatus.new(false).call
  end


  test "OperatorPreferenceDensityOption name covers STANDARD id" do
    option = OperatorPreferenceDensityOption.allocate
    option.define_singleton_method(:id) { OperatorPreferenceDensityOption::STANDARD }

    assert_equal "standard", option.name
    option.define_singleton_method(:id) { OperatorPreferenceDensityOption::COMPACT }

    assert_equal "compact", option.name
  end

  test "WithdrawalOccurrenceRecording unsupported subject and actor paths" do
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.occurrence_class_for(Object.new) }
    assert_raises(ArgumentError) { WithdrawalOccurrenceRecording.surface_for(Object.new) }

    subject = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)
    subject.define_singleton_method(:public_id) { "client-pub" }
    actor = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)
    actor.define_singleton_method(:public_id) { "operator-pub" }
    request = ActionDispatch::TestRequest.create
    request.request_id = "req-1"
    request.user_agent = "CoverageAgent/1.0"

    ctx = WithdrawalOccurrenceRecording.allowed_context(
      subject: subject,
      actor: actor,
      request: request,
      occurred_at: Time.zone.parse("2026-01-02 03:04:05 UTC"),
      context: { reason_code: "user_request" },
    )

    assert_equal "Operator", ctx["actor_type"]
    assert_equal "operator-pub", ctx["actor_public_id"]
    assert_equal "app", ctx["surface"]
    assert_equal "req-1", ctx["request_id"]
    assert_predicate ctx["user_agent_digest"], :present?
  end

  test "Webauthn AuthenticatorMetadata nil resolution safe navigation then arms" do
    context = Object.new
    %i(
      aaguid transports backup_eligible backup_state authenticator_attachment
    ).each do |m|
      context.define_singleton_method(m) { nil }
    end
    Webauthn::AuthenticatorNameResolver.stub(:resolve, nil) do
      result = Webauthn::AuthenticatorMetadata.attributes_from(context)

      assert_nil result[:provider_name]
      assert_nil result[:metadata_source]
    end
  end
end
