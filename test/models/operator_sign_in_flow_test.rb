# frozen_string_literal: true

require "test_helper"

class OperatorSignInFlowTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorSignInFlow)
  end
  test "historical principal scalars and terminal lifecycle do not require a retired actor model" do
    OperatorSignInFlowState.ensure_defaults!
    now = OperatorSignInFlow.database_now
    flow = OperatorSignInFlow.create!(
      principal_id: 9_876_543, nonce_digest: "a" * 64,
      issued_at: now - 1.minute, expires_at: now + 1.minute,
    )
    flow.update!(return_to: "/history")
    flow.halt_sign_in!

    assert_predicate flow.reload, :sign_in_halted?
    assert_equal 9_876_543, flow.principal_id
    assert_equal "/history", flow.return_to
    # Persisted identity is a historical scalar; no cross-store ORM navigation remains.
    assert_nil OperatorSignInFlow.reflect_on_association(:principal)
  end

  test "new authentication evidence and forward progress require Governance authority" do
    OperatorSignInFlowState.ensure_defaults!
    now = OperatorSignInFlow.database_now
    flow = OperatorSignInFlow.create!(
      principal_id: 9_876_543, nonce_digest: "b" * 64,
      issued_at: now - 1.minute, expires_at: now + 1.minute,
    )
    before = flow.attributes

    assert_raises(GovernanceLookupUnavailableError) { flow.record_authentication_evidence!(method: "passkey") }
    assert_raises(GovernanceLookupUnavailableError) { flow.advance_sign_in_to_mfa! }
    assert_equal before, flow.reload.attributes
  end
end
