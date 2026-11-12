# frozen_string_literal: true

class AddPrincipalPublicIdToClientDeviceSessions < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_device_sessions, :principal_public_id, :string, limit: 255)
  end
end
