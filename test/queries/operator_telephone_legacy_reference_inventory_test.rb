# frozen_string_literal: true

require "test_helper"

class OperatorTelephoneLegacyReferenceInventoryTest < ActiveSupport::TestCase
  test "empty explicit ORG scope returns empty inventory counts" do
    assert_equal(
      { pending_ceremonies: 0, deliverable_proofs: 0, unexpired_receipts: 0 },
      OperatorTelephoneLegacyReferenceInventory.call(scope: OperatorTelephoneCeremonyTransaction.none),
    )
  end

  test "APP scope cannot be used as an ORG legacy inventory" do
    error =
      assert_raises(ArgumentError) do
        OperatorTelephoneLegacyReferenceInventory.call(scope: ClientTelephoneCeremonyTransaction.all)
      end

    assert_equal "legacy reference inventory requires an explicit ORG Telephone ceremony scope", error.message
  end
end
