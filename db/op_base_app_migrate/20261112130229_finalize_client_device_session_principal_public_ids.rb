# frozen_string_literal: true

class FinalizeClientDeviceSessionPrincipalPublicIds < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(:client_device_sessions, name: "chk_client_device_sessions_principal_public_id_present")
    # The validated CHECK proves non-nullness, so PostgreSQL avoids a table scan.
    safety_assured { change_column_null(:client_device_sessions, :principal_public_id, false) }
  end

  def down
    change_column_null(:client_device_sessions, :principal_public_id, true)
  end
end
