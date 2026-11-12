# typed: false
# frozen_string_literal: true

require "test_helper"

class DatabasePkTypeTest < ActiveSupport::TestCase
  # Test that representative tables from each schema have bigint PKs
  # After migration, all status/kind/master tables should use bigint

  test "APP OP tables use bigint primary keys" do
    assert_bigint_pk(ClientDeviceSession)
    assert_bigint_pk(ClientToken)
    assert_bigint_pk(OpAppGrant)
  end

  test "ORG OP tables use bigint primary keys" do
    assert_bigint_pk(OperatorDeviceSession)
    assert_bigint_pk(OperatorToken)
    assert_bigint_pk(OpOrgGrant)
  end

  test "occurrence schema tables use bigint primary keys" do
    assert_bigint_pk(AreaOccurrenceStatus)
    assert_bigint_pk(EmailOccurrenceStatus)
  end

  test "chronicle schema tables use bigint primary keys" do
    assert_bigint_pk(OperatorChronicleEvent)
    assert_bigint_pk(ClientChronicleLevel)
  end

  private

  def assert_bigint_pk(model)
    id_column = model.columns_hash["id"]

    assert id_column, "#{model.name} should have 'id' column"

    # PostgreSQL bigint is reported as :integer with limit: 8
    sql_type = id_column.sql_type.downcase

    assert ["bigint", "bigserial"].any? { |type| sql_type.include?(type) },
           "#{model.name}.id should be bigint/bigserial, got: #{sql_type}"
  end
end
