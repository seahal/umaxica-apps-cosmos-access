# frozen_string_literal: true

require "test_helper"

class StepUpContextIdentifierTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "both realm contexts require the standard 21 character identifier" do
    [ClientStepUpContext, OperatorStepUpContext].each do |model|
      [20, 21, 22].each do |length|
        context = model.new(public_id: "a" * length)
        context.validate

        assert_equal length != 21, context.errors.of_kind?(:public_id, :wrong_length), "length #{length}"
      end
      [nil, ""].each do |missing|
        context = model.new(public_id: missing)
        context.validate

        assert context.errors.of_kind?(:public_id, :blank)
      end
    end
  end

  test "PostgreSQL enforces identifier length before checking missing parents" do
    [ClientStepUpContext, OperatorStepUpContext].each do |model|
      { 20 => ActiveRecord::StatementInvalid,
        21 => ActiveRecord::InvalidForeignKey,
        22 => ActiveRecord::ValueTooLong, }.each do |length, error_class|
        error =
          assert_raises(error_class) do
            model.transaction(requires_new: true) do
              model.insert!(
                {
                  public_id: "a" * length,
                  oidc_authorization_transaction_id: -1,
                  grant_id: -1,
                  bound_subject: "subject",
                  requested_acr: OidcAuthorizeRequestResolver::STEP_UP_ACR,
                  state_id: 10,
                  expires_at: 1.minute.from_now,
                },
              )
            end
          end
        assert_instance_of PG::CheckViolation, error.cause if length == 20
      end
    end
  end
end
