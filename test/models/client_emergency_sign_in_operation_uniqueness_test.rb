# frozen_string_literal: true

require "test_helper"

class ClientEmergencySignInOperationUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens client_device_sessions)

  test "historical operation identifiers and its root cannot be reused" do
    attributes = {
      operation_id: SecureRandom.uuid,
      credential_public_id: PublicId.generate,
      client_token_id: client_tokens(:one).id,
    }
    ClientEmergencySignInOperation.create!(attributes)

    %i(operation_id credential_public_id client_token_id).each do |field|
      replacement = {
        operation_id: SecureRandom.uuid,
        credential_public_id: PublicId.generate,
        client_token_id: client_tokens(:two).id,
      }.merge(field => attributes.fetch(field))
      duplicate = ClientEmergencySignInOperation.new(replacement)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(field, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        ClientEmergencySignInOperation.transaction(requires_new: true) do
          ClientEmergencySignInOperation.insert_all!([replacement])
        end
      end
    end

    independent = ClientEmergencySignInOperation.create!(
      operation_id: SecureRandom.uuid,
      credential_public_id: PublicId.generate,
      client_token_id: client_tokens(:two).id,
    )

    assert_predicate independent, :persisted?
  end
end
