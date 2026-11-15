# frozen_string_literal: true

require "test_helper"

class ClientSecretSignInReceiptTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens client_device_sessions)

  setup { ClientSignInFlowState.ensure_defaults! }

  test "historical receipt identifiers reject duplicates in validation and PostgreSQL" do
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      principal_id: client_tokens(:one).user_id, nonce_digest: SecureRandom.hex(32),
      issued_at: now, expires_at: now + 1.minute,
    )
    attributes = {
      operation_id: SecureRandom.uuid,
      credential_ref: PublicId.generate,
      client_ref: client_device_sessions(:one).principal_public_id,
      sign_in_flow_id: flow.id,
      root_token_ref: PublicId.generate,
      committed_at: now,
    }
    ClientSecretSignInReceipt.insert_all!([attributes])

    %i(operation_id credential_ref root_token_ref).each do |field|
      candidate = ClientSecretSignInReceipt.new(
        **attributes.merge(
          :operation_id => SecureRandom.uuid, :credential_ref => PublicId.generate,
          :root_token_ref => PublicId.generate, field => attributes.fetch(field),
        ),
      )

      assert_not candidate.valid?
      assert candidate.errors.of_kind?(field, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        ClientSecretSignInReceipt.transaction(requires_new: true) do
          ClientSecretSignInReceipt.insert_all!([candidate.attributes.except("id", "created_at", "updated_at")])
        end
      end
    end
  end

  test "historical receipt prevents its sign-in flow from being destroyed" do
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      principal_id: client_tokens(:one).user_id, nonce_digest: SecureRandom.hex(32),
      issued_at: now, expires_at: now + 1.minute,
    )
    ClientSecretSignInReceipt.insert_all!(
      [{
        operation_id: SecureRandom.uuid,
        credential_ref: PublicId.generate,
        client_ref: client_device_sessions(:one).principal_public_id,
        sign_in_flow_id: flow.id,
        root_token_ref: client_tokens(:one).public_id,
        committed_at: now,
      }],
    )

    assert_not flow.destroy
    assert_predicate flow.reload, :persisted?
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientSignInFlow.transaction(requires_new: true) { ClientSignInFlow.where(id: flow.id).delete_all }
    end
  end
  test "Governance-unavailable receipt creation rejects a pending flow without recording an attempt" do
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      principal_id: client_tokens(:one).user_id, nonce_digest: "a" * 64,
      issued_at: now, expires_at: now + 1.minute,
      state_id: ClientSignInFlowState::PRIMARY_PENDING,
    )

    assert_raises(GovernanceLookupUnavailableError) do
      ClientSecretSignInReceipt.create!(
        operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1xxxxx",
        client_ref: client_device_sessions(:one).principal_public_id, sign_in_flow: flow,
        root_token_ref: client_tokens(:one).public_id, committed_at: now,
      )
    end
  end

  test "Governance-unavailable receipt creation refuses completed local flow facts without authority" do
    now = ClientSignInFlow.database_now
    owner = client_device_sessions(:one)
    token = client_tokens(:one)
    token.update!(root_login_established_at: now)
    flow = ClientSignInFlow.create!(
      principal_id: owner.user_id, token: token, nonce_digest: "a" * 64,
      issued_at: now - 1.second, expires_at: now + 1.minute,
      state_id: ClientSignInFlowState::COMPLETED,
      completed_at: now, session_issued_at: now,
      authentication_method: "secret", authentication_context: "normal", authentication_event_at: now - 1.second,
    )
    assert_no_difference "ClientSecretSignInReceipt.count" do
      assert_raises(GovernanceLookupUnavailableError) do
        ClientSecretSignInReceipt.create!(
          operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1xxxxx",
          client_ref: owner.principal_public_id, sign_in_flow: flow,
          root_token_ref: token.public_id, committed_at: now,
        )
      end
    end
  end

  test "Governance-unavailable receipt creation refuses a different historical actor reference" do
    now = ClientSignInFlow.database_now
    token = client_tokens(:one)
    token.update!(root_login_established_at: now)
    flow = ClientSignInFlow.create!(
      principal_id: client_tokens(:one).user_id, token: token, nonce_digest: "a" * 64,
      issued_at: now - 1.second, expires_at: now + 1.minute,
      state_id: ClientSignInFlowState::COMPLETED,
      completed_at: now, session_issued_at: now,
      authentication_method: "secret", authentication_context: "normal", authentication_event_at: now - 1.second,
    )

    assert_raises(GovernanceLookupUnavailableError) do
      ClientSecretSignInReceipt.create!(
        operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1xxxxx",
        client_ref: client_device_sessions(:two).principal_public_id, sign_in_flow: flow,
        root_token_ref: token.public_id, committed_at: now,
      )
    end
  end

  test "Governance-unavailable receipt creation refuses adjacent times other methods and restricted context" do
    now = ClientSignInFlow.database_now
    owner = client_device_sessions(:one)
    token = client_tokens(:one)
    token.update!(root_login_established_at: now)
    flow = ClientSignInFlow.create!(
      principal_id: owner.user_id, token: token, nonce_digest: "a" * 64,
      issued_at: now - 1.second, expires_at: now + 1.minute,
      state_id: ClientSignInFlowState::COMPLETED,
      completed_at: now, session_issued_at: now,
      authentication_method: "secret", authentication_context: "normal", authentication_event_at: now - 1.second,
    )

    [now - Rational(1, 1_000_000), now + Rational(1, 1_000_000)].each do |timestamp|
      assert_raises(GovernanceLookupUnavailableError) do
        ClientSecretSignInReceipt.create!(
          operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1xxxxx",
          client_ref: owner.principal_public_id, sign_in_flow: flow,
          root_token_ref: token.public_id, committed_at: timestamp,
        )
      end
    end
    [["passkey", "normal"], ["secret", "standby"]].each do |method, context|
      flow.update!(authentication_method: method, authentication_context: context)
      assert_raises(GovernanceLookupUnavailableError) do
        ClientSecretSignInReceipt.create!(
          operation_id: SecureRandom.uuid, credential_ref: "fixture-secret-1xxxxx",
          client_ref: owner.principal_public_id, sign_in_flow: flow,
          root_token_ref: token.public_id, committed_at: now,
        )
      end
    end
  end
  test "a new receipt requires Governance credential commit verification before any insert" do
    ClientSignInFlowState.ensure_defaults!
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      principal_id: 9_876_543, nonce_digest: "e" * 64,
      issued_at: now - 1.minute, expires_at: now + 1.minute,
    )

    assert_no_difference "ClientSecretSignInReceipt.count" do
      assert_raises(GovernanceLookupUnavailableError) do
        ClientSecretSignInReceipt.create!(
          sign_in_flow: flow, operation_id: SecureRandom.uuid,
          client_ref: "p" * 21, credential_ref: "c" * 21, root_token_ref: "r" * 21, committed_at: now,
        )
      end
    end
  end
  test "historical committed receipt facts remain readable and ordinary metadata remains writable" do
    now = ClientSignInFlow.database_now
    root = client_tokens(:one)
    device = client_device_sessions(:one)
    flow = ClientSignInFlow.create!(
      principal_id: root.subject_public_id, token: root, nonce_digest: "f" * 64,
      issued_at: now - 11.days, expires_at: now - 9.days,
      state_id: ClientSignInFlowState::COMPLETED, completed_at: now - 10.days, session_issued_at: now - 10.days,
      authentication_method: "secret", authentication_context: "normal",
      authentication_event_at: now - 10.days - 1.second,
    )
    rows = ClientSecretSignInReceipt.insert_all!(
      [{
        operation_id: SecureRandom.uuid,
        sign_in_flow_id: flow.id,
        credential_ref: "c" * 21,
        client_ref: device.subject_public_id,
        root_token_ref: root.public_id,
        committed_at: now,
        created_at: now,
        updated_at: now,
      }],
    )
    receipt = ClientSecretSignInReceipt.includes(:sign_in_flow).find(rows.rows.first.first)
    facts = receipt.attributes.slice(
      *%w(operation_id sign_in_flow_id credential_ref client_ref root_token_ref
          committed_at),
    )
    assert_raises(GovernanceLookupUnavailableError) do
      ClientSecretSignInReceiptPurger.call!(receipt: receipt, retention_after: 1.day)
    end
    assert_equal facts, receipt.reload.attributes.slice(*facts.keys)
    assert ClientSecretSignInReceipt.exists?(receipt.id)
    receipt.update!(updated_at: now + 1.second)

    assert_equal facts, receipt.reload.attributes.slice(*facts.keys)
    assert_equal now + 1.second, receipt.updated_at
    assert_equal flow.id, receipt.sign_in_flow_id
  end
end
