# frozen_string_literal: true

require "test_helper"

class StepUpTransactionReferenceUniquenessTest < ActiveSupport::TestCase
  CELLS = [
    [ClientDeviceSession, ClientToken, :user_id, ClientStepUpSession, :user_token, ClientStepUpCeremonyTransaction],
    [OperatorDeviceSession, OperatorToken, :staff_id, OperatorStepUpSession, :staff_token,
     OperatorStepUpCeremonyTransaction,],
  ].freeze

  CELLS.each do |device_class, root_class, owner_key, session_class, session_token_key, transaction_class|
    test "#{session_class.name} keeps nullable transaction references and raw unique enforcement" do
      device = device_class.create!(owner_key => 9_700_001, :principal_public_id => "historical-subject")
      first_root = root_class.create!(owner_key => 9_700_001, :authentication_epoch => 0, :device_session => device)
      second_root = root_class.create!(owner_key => 9_700_001, :authentication_epoch => 0, :device_session => device)
      metadata = { scope: "settings_birthdate",
                   return_to: "/identity/birthdate",
                   status: "PENDING",
                   discard_at: session_class.database_now + 300, }
      first = session_class.create!(metadata.merge(session_token_key => first_root))
      second = session_class.create!(metadata.merge(session_token_key => second_root))

      assert_nil first.reload.step_up_ceremony_transaction_ref
      assert_nil second.reload.step_up_ceremony_transaction_ref
      reference = transaction_class.create_transaction!(
        actor_ref: "historical-subject", session_ref: first_root.public_id, required_scope: "settings_birthdate",
        required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
      ).transaction_id
      first.update!(step_up_ceremony_transaction_ref: reference)
      assert_raises(ActiveRecord::RecordNotUnique) do
        session_class.transaction(requires_new: true) do
          second.update_columns(step_up_ceremony_transaction_ref: reference)
        end
      end
      assert_nil second.reload.step_up_ceremony_transaction_ref
      first.save!

      assert_equal reference, first.reload.step_up_ceremony_transaction_ref
      other_device = device_class.create!(owner_key => 9_700_002, :principal_public_id => "other-historical-subject")
      third_root = root_class.create!(
        owner_key => 9_700_002, :authentication_epoch => 0,
        :device_session => other_device,
      )
      third_transaction = transaction_class.create_transaction!(
        actor_ref: "other-historical-subject", session_ref: third_root.public_id, required_scope: "settings_birthdate",
        required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
      )
      candidate = session_class.new(
        metadata.merge(
          session_token_key => third_root,
          :step_up_ceremony_transaction_ref => third_transaction.transaction_id,
        ),
      )
      queries = []
      subscriber =
        lambda do |_name, _started, _finished, _id, payload|
          sql = payload.fetch(:sql)
          if payload[:name] != "SCHEMA" && sql.include?(session_class.table_name) &&
              sql.include?("step_up_ceremony_transaction_ref") && sql.match?(/\ASELECT/i)
            queries << sql
          end
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate first, :valid?
      end
      assert_equal 1, queries.size
    end

    test "#{session_class.name} refuses a duplicate transaction reference on creation" do
      device = device_class.create!(owner_key => 9_700_001, :principal_public_id => "historical-subject")
      first_root = root_class.create!(owner_key => 9_700_001, :authentication_epoch => 0, :device_session => device)
      second_root = root_class.create!(owner_key => 9_700_001, :authentication_epoch => 0, :device_session => device)
      transaction = transaction_class.create_transaction!(
        actor_ref: "historical-subject", session_ref: first_root.public_id, required_scope: "settings_birthdate",
        required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
      )
      metadata = { scope: "settings_birthdate",
                   return_to: "/identity/birthdate",
                   status: "PENDING",
                   discard_at: session_class.database_now + 300,
                   step_up_ceremony_transaction_ref: transaction.transaction_id, }
      session_class.create!(metadata.merge(session_token_key => first_root))
      duplicate = session_class.new(metadata.merge(session_token_key => second_root))

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:step_up_ceremony_transaction_ref, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    end

    test "#{session_class.name} validates transaction reference changes on reused persisted rows" do
      device = device_class.create!(owner_key => 9_700_001, :principal_public_id => "historical-subject")
      first_root = root_class.create!(owner_key => 9_700_001, :authentication_epoch => 0, :device_session => device)
      second_root = root_class.create!(owner_key => 9_700_001, :authentication_epoch => 0, :device_session => device)
      transaction = transaction_class.create_transaction!(
        actor_ref: "historical-subject", session_ref: first_root.public_id, required_scope: "settings_birthdate",
        required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
      )
      metadata = { scope: "settings_birthdate",
                   return_to: "/identity/birthdate",
                   status: "PENDING",
                   discard_at: session_class.database_now + 300, }
      first = session_class.create!(
        metadata.merge(
          session_token_key => first_root,
          :step_up_ceremony_transaction_ref => transaction.transaction_id,
        ),
      )
      second = session_class.create!(metadata.merge(session_token_key => second_root))
      second.step_up_ceremony_transaction_ref = first.step_up_ceremony_transaction_ref

      assert_not second.valid?
      assert second.errors.of_kind?(:step_up_ceremony_transaction_ref, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { second.save! }
      assert_nil second.reload.step_up_ceremony_transaction_ref
      replacement = transaction_class.create_transaction!(
        actor_ref: "historical-subject", session_ref: second_root.public_id, required_scope: "settings_birthdate",
        required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
      ).transaction_id
      second.update!(step_up_ceremony_transaction_ref: replacement)

      assert_equal replacement, second.reload.step_up_ceremony_transaction_ref
      second.update!(step_up_ceremony_transaction_ref: nil)

      assert_nil second.reload.step_up_ceremony_transaction_ref
    end
  end
end
