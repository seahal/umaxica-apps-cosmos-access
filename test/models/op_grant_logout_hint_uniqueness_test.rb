# frozen_string_literal: true

require "test_helper"

class OpGrantLogoutHintUniquenessTest < ActiveSupport::TestCase
  test "each surface saves one encrypted logout hint per grant and rejects model duplicates" do
    [
      [OpAppGrant, OpAppGrantLogoutHint, { client_token_id: client_tokens(:one).id }, "base-app-ww"],
      [OpOrgGrant, OpOrgGrantLogoutHint, { operator_token_id: operator_tokens(:one).id }, "base-org-ww"],
    ].each do |grant_model, hint_model, parent, client_id|
      grant = grant_model.create!(**parent, authentication_epoch: 0, oidc_client_id: client_id)
      hint = hint_model.create!(grant: grant, id_token: "verified-id-token")

      assert_equal "verified-id-token", hint.reload.id_token
      assert_not_equal "verified-id-token", hint.id_token_before_type_cast
      assert_predicate hint, :valid?

      duplicate = hint_model.new(grant: grant, id_token: "another-id-token")

      assert_not_predicate duplicate, :valid?
      assert duplicate.errors.of_kind?(:grant_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_equal 1, hint_model.where(grant_id: grant.id).count
    end
  end

  test "each surface enforces hint uniqueness and required grant references when validations are bypassed" do
    [
      [OpAppGrant, OpAppGrantLogoutHint, { client_token_id: client_tokens(:one).id }, "base-app-ww"],
      [OpOrgGrant, OpOrgGrantLogoutHint, { operator_token_id: operator_tokens(:one).id }, "base-org-ww"],
    ].each do |grant_model, hint_model, parent, client_id|
      grant = grant_model.create!(**parent, authentication_epoch: 0, oidc_client_id: client_id)
      hint_model.create!(grant: grant, id_token: "verified-id-token")

      assert_raises(ActiveRecord::RecordNotUnique) do
        hint_model.transaction(requires_new: true) do
          hint_model.insert_all!([{ grant_id: grant.id, id_token: "duplicate-id-token" }])
        end
      end
      assert_raises(ActiveRecord::NotNullViolation) do
        hint_model.transaction(requires_new: true) do
          hint_model.insert_all!([{ grant_id: nil, id_token: "missing-grant-token" }])
        end
      end
      assert_raises(ActiveRecord::InvalidForeignKey) do
        hint_model.transaction(requires_new: true) do
          hint_model.insert_all!([{ grant_id: -1, id_token: "unknown-grant-token" }])
        end
      end
      assert_equal 1, hint_model.where(grant_id: grant.id).count
    end
  end

  test "each surface destroys its encrypted hint with its owning grant" do
    [
      [OpAppGrant, OpAppGrantLogoutHint, { client_token_id: client_tokens(:one).id }, "base-app-ww"],
      [OpOrgGrant, OpOrgGrantLogoutHint, { operator_token_id: operator_tokens(:one).id }, "base-org-ww"],
    ].each do |grant_model, hint_model, parent, client_id|
      grant = grant_model.create!(**parent, authentication_epoch: 0, oidc_client_id: client_id)
      hint = hint_model.create!(grant: grant, id_token: "verified-id-token")

      grant.destroy!

      assert_not hint_model.exists?(hint.id)
    end
  end
end
