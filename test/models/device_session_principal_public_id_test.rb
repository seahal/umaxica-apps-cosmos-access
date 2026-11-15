# frozen_string_literal: true

require "test_helper"

class DeviceSessionPrincipalPublicIdTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "persisted principal subjects cannot be reassigned while device lifecycle updates remain valid" do
    [
      [ClientDeviceSession, :subject_public_id, "E"],
      [OperatorDeviceSession, :subject_public_id, "F"],
    ].each do |model, actor_key, prefix|
      row = model.create!(
        :public_id => prefix * 21,
        :subject_public_id => "original-retention-subject",
      )
      assert_raises(ActiveRecord::ReadonlyAttributeError) do
        row.update!(principal_public_id: "different-retention-subject")
      end
      assert_equal "original-retention-subject", row.reload.principal_public_id
      seen_at = model.database_now
      row.update!(last_seen_at: seen_at)

      assert_equal seen_at, row.reload.last_seen_at
      assert_equal "original-retention-subject", row.principal_public_id
    end
  end

  test "both realm databases preserve exact subjects and reject absent blank and overlength subjects" do
    [
      [ClientDeviceSession, :subject_public_id, "A"],
      [OperatorDeviceSession, :subject_public_id, "O"],
    ].each do |model, actor_key, prefix|
      subject = "#{prefix}#{"x" * 254}"
      result = model.insert_all!(
        [{ :public_id => "#{prefix}#{"1" * 20}", :subject_public_id => subject }],
        returning: %w(id),
      )
      row = model.find(result.rows.first.first)

      assert_equal subject, row.principal_public_id
      assert_equal 255, row.principal_public_id.length

      [nil, "", "   ", "\t\n", "#{prefix}#{"x" * 255}"].each do |invalid|
        error =
          assert_raises(ActiveRecord::StatementInvalid) do
            model.transaction(requires_new: true) do
              model.where(id: row.id).update_all(principal_public_id: invalid)
            end
          end
        expected_cause =
          if invalid.nil?
            PG::NotNullViolation
          elsif invalid.length > 255
            PG::StringDataRightTruncation
          else
            PG::CheckViolation
          end

        assert_instance_of expected_cause, error.cause
        assert_equal subject, row.reload.principal_public_id
      end
    end
  end
end
