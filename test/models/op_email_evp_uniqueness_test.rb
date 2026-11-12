# frozen_string_literal: true

require "test_helper"

class OpEmailEvpUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "EVP nonce and token digests are unique without preventing absent values" do
    [ClientEmailCeremonyTransaction, OperatorEmailCeremonyTransaction].each do |model|
      [:evp_nonce_digest, :evp_token_digest].each do |field|
        rows =
          2.times.map do
            model.create_transaction!(actor_ref: "actor", session_ref: "session", operation: "sign_in")
          end
        digest = SecureRandom.hex(32)
        rows.first.update_columns(field => digest)
        rows.last.assign_attributes(field => digest)

        assert_not rows.last.valid?
        assert rows.last.errors.of_kind?(field, :taken)
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { rows.last.update_columns(field => digest) }
        end
      end
    end
  end
end
