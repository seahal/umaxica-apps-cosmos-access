# frozen_string_literal: true

require "test_helper"

class OpExternalOwnerScalarTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_device_sessions operator_device_sessions)

  test "device and OIDC connection owner references reject null before and after validation bypass" do
    [[ClientDeviceSession, :subject_public_id], [OperatorDeviceSession, :subject_public_id],
     [ClientOidcConnection, :subject_public_id], [OperatorOidcConnection, :subject_public_id],].each do |model, owner_key|
      record = model.new(owner_key => nil)
      record.valid?

      assert_includes record.errors.details.fetch(owner_key).pluck(:error), :blank
      persisted =
        case model.name
        when "ClientDeviceSession", "OperatorDeviceSession"
          model.find(ActiveRecord::FixtureSet.identify(:one))
        when "ClientOidcConnection", "OperatorOidcConnection"
          model.create!(owner_key => 9_876_543, :client_id => "test-client")
        else
          raise ArgumentError, "unsupported test model"
        end
      assert_raises(ActiveRecord::NotNullViolation) do
        model.transaction(requires_new: true) { persisted.update_columns(owner_key => nil) }
      end
    end
  end
end
