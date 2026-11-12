# frozen_string_literal: true

class AddPrincipalPublicIdToOperatorDeviceSessions < ActiveRecord::Migration[8.2]
  def change
    add_column(:operator_device_sessions, :principal_public_id, :string, limit: 255)
  end
end
