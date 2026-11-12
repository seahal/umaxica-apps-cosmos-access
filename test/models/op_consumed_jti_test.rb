# frozen_string_literal: true

require "test_helper"

class OpConsumedJtiTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "both realms reject duplicate scoped digests before saving" do
    [OpAppConsumedJti, OpOrgConsumedJti].each do |model|
      attributes = {
        purpose: "logout_token",
        issuer: "https://op.example.test",
        realm: model::REALM,
        client_id: "replay-validation",
        jti_digest: "a" * 64,
        expires_at: 1.minute.from_now,
        consumed_at: Time.current,
      }
      record = model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not_predicate duplicate, :valid?
      assert duplicate.errors.of_kind?(:jti_digest, :taken)
      assert_predicate record, :valid?

      %i(purpose issuer client_id jti_digest).each do |dimension|
        distinct = model.new(attributes.merge(dimension => "other"))

        assert_predicate distinct, :valid?, dimension.to_s
      end
    end
  end

  test "PostgreSQL rejects duplicate digests when validations are bypassed in either realm" do
    [OpAppConsumedJti, OpOrgConsumedJti].each do |model|
      attributes = {
        purpose: "logout_token",
        issuer: "https://op.example.test",
        realm: model::REALM,
        client_id: "replay-sql",
        jti_digest: "b" * 64,
        expires_at: 1.minute.from_now,
        consumed_at: Time.current,
      }
      model.insert_all!([attributes])

      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) { model.insert_all!([attributes]) }
      end
      assert_equal 1, model.where(client_id: "replay-sql").count
    end
  end

  test "consume rejects a replay but raises for invalid data in both realms" do
    [OpAppConsumedJti, OpOrgConsumedJti].each do |model|
      attributes = {
        purpose: "logout_token",
        issuer: "https://op.example.test",
        client_id: "replay-api",
        jti: "one-time",
        expires_at: 1.minute.from_now,
      }

      assert model.consume!(**attributes)
      assert_not model.consume!(**attributes)
      assert_raises(ActiveRecord::RecordInvalid) do
        model.consume!(**attributes.merge(issuer: "x" * 256))
      end
      assert_raises(ActiveRecord::RecordInvalid) do
        model.consume!(**attributes, consumed_at: nil)
      end
      assert_equal 1, model.where(client_id: "replay-api").count
    end
  end

  test "missing and empty replay inputs never consume authority in either realm" do
    [OpAppConsumedJti, OpOrgConsumedJti].each do |model|
      attributes = {
        purpose: "logout_token",
        issuer: "https://op.example.test",
        client_id: "missing-input",
        jti: "unused",
        expires_at: 1.minute.from_now,
      }
      attributes.each_key do |field|
        [nil, ""].each do |missing|
          assert_not model.consume!(**attributes.merge(field => missing)), field.to_s
        end
      end

      assert_not model.exists?(client_id: "missing-input")
    end
  end
end
