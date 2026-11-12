# frozen_string_literal: true

require "test_helper"

class OpActiveGrantUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "only one unrevoked grant exists for each device and client within a realm" do
    [
      [OpAppGrant, { client_token_id: client_tokens(:one).id }, "app-client"],
      [OpOrgGrant, { operator_token_id: operator_tokens(:one).id }, "org-client"],
    ].each do |model, parent, client_id|
      first = model.create!(**parent, authentication_epoch: 0, oidc_client_id: client_id)
      duplicate = model.new(**parent, authentication_epoch: 0, oidc_client_id: client_id)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:device_session_id, :taken)
      [:en, :ja].each do |locale|
        I18n.with_locale(locale) { assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! } }
      end
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) do
          model.insert_all!(
            [
              duplicate.attributes.except("id").merge(
                "public_id" => PublicId.generate, "created_at" => Time.current, "updated_at" => Time.current,
              ),
            ],
          )
        end
      end
      other_client = model.create!(**parent, authentication_epoch: 0, oidc_client_id: "other-client")
      historical = model.create!(**parent, authentication_epoch: 0, oidc_client_id: client_id, revoked_at: Time.current)

      assert_predicate other_client, :persisted?
      assert_predicate historical, :persisted?
      first.update!(revoked_at: Time.current)
      replacement = model.create!(**parent, authentication_epoch: 0, oidc_client_id: client_id)

      assert_predicate replacement, :persisted?
      assert_nil replacement.revoked_at
    end
  end
end
