# frozen_string_literal: true

require "test_helper"

class SensitiveReasonNoteEncryptionTest < ActiveSupport::TestCase
  test "retained Chronicle account-access reason notes are encrypted at rest" do
    marker = "sensitive-note-#{SecureRandom.hex(8)}"
    access_event = AccountAccessEvent.create!(
      account_type: "Client",
      account_id: 9_876_543,
      event_type: AccountAccessEvent::EVENT_TYPE_ADMIN_LOCK,
      previous_access_state: "enabled",
      next_access_state: "admin_locked",
      operator_id: 9_876_544,
      reason_code: "security_incident",
      reason_note: marker,
      occurred_at: Time.current,
      metadata: {},
    )

    assert_equal marker, access_event.reload.reason_note
    raw_value = raw_column_value(access_event, "account_access_events", :reason_note)

    assert_not_equal marker, raw_value
    assert_not_includes raw_value.to_s, marker
  end

  private

  def raw_column_value(record, table_name, column_name)
    connection = record.class.lease_connection
    quoted_table = connection.quote_table_name(table_name)
    quoted_column = connection.quote_column_name(column_name)
    quoted_id = connection.quote(record.id)
    connection.select_value("SELECT #{quoted_column} FROM #{quoted_table} WHERE id = #{quoted_id}")
  end
end
