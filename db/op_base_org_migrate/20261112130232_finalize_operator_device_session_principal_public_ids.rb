# frozen_string_literal: true

class FinalizeOperatorDeviceSessionPrincipalPublicIds < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(:operator_device_sessions, name: "chk_operator_device_sessions_principal_public_id_present")
    # The validated CHECK proves non-nullness, so PostgreSQL avoids a table scan.
    safety_assured { change_column_null(:operator_device_sessions, :principal_public_id, false) }
  end

  def down
    change_column_null(:operator_device_sessions, :principal_public_id, true)
  end
end
