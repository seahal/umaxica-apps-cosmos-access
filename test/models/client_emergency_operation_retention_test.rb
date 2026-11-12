# frozen_string_literal: true

require "test_helper"

class ClientEmergencyOperationRetentionTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens client_device_sessions)

  test "a historical emergency operation prevents root deletion" do
    token = client_tokens(:one)
    operation = ClientEmergencySignInOperation.create!(
      client_token: token, operation_id: SecureRandom.uuid, credential_public_id: PublicId.generate,
    )
    token = ClientToken.includes(:client_sign_up_flows, :op_app_grants, :client_verifications, :step_up_session)
      .find(token.id)

    ClientToken.transaction(requires_new: true) { assert_not token.destroy }

    assert_predicate token.reload, :persisted?
    assert_predicate operation.reload, :persisted?
    [:en, :ja].each do |locale|
      I18n.with_locale(locale) { assert_not_empty token.errors.full_messages }
    end
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientToken.transaction(requires_new: true) { ClientToken.where(id: token.id).delete_all }
    end
    assert_predicate operation.reload, :persisted?
  end
end
