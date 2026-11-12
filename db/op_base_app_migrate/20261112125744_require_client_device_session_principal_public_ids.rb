# frozen_string_literal: true

class RequireClientDeviceSessionPrincipalPublicIds < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint(
      :client_device_sessions,
      "principal_public_id IS NOT NULL AND principal_public_id ~ '[^[:space:]]'",
      name: "chk_client_device_sessions_principal_public_id_present", validate: false,
    )
  end
end
