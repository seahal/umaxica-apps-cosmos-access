# frozen_string_literal: true

require "test_helper"

class OpAuthorityStopTargetUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "target uniqueness is scoped to its owning stop on each surface" do
    [
      ["app", client_tokens(:one).device_session.principal_public_id, client_tokens(:one), client_tokens(:two), OpAppGrant,
       OpAppAuthorityStopRootTarget, OpAppAuthorityStopGrantTarget, :client_token_id, "base-app-ww",],
      ["org", operator_tokens(:one).device_session.principal_public_id, operator_tokens(:one), operator_tokens(:two), OpOrgGrant,
       OpOrgAuthorityStopRootTarget, OpOrgAuthorityStopGrantTarget, :operator_token_id, "base-org-ww",],
    ].each do |realm, principal_public_id, root, other_root, grant_model, root_target, grant_target, parent_key, client_id|
      stops =
        %w(first second).map do |event|
          OpAuthorityStopCommitter.stop_principal(
            realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
            authority_evidence_ref: "target-uniqueness-#{event}", cutoff_epoch: 1,
          ).stop
        end
      grant = grant_model.create!(parent_key => root.id, :authentication_epoch => 0, :oidc_client_id => client_id)
      other_grant = grant_model.create!(
        parent_key => other_root.id, :authentication_epoch => 0,
        :oidc_client_id => client_id,
      )

      [
        [root_target, :root_id, { root: root }, { root: other_root }],
        [grant_target, :grant_id, { grant: grant }, { grant: other_grant }],
      ].each do |model, target_key, target, other_target|
        original = model.create!(stop: stops.first, **target)

        assert_predicate original, :valid?

        duplicate = model.new(stop: stops.first, **target)

        assert_not_predicate duplicate, :valid?
        assert duplicate.errors.of_kind?(target_key, :taken)
        assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
        assert_predicate model.create!(stop: stops.first, **other_target), :persisted?
        assert_predicate model.create!(stop: stops.second, **target), :persisted?
        assert_equal 3, model.where(stop_id: stops.map(&:id)).count
      end
    end
  end

  test "target uniqueness and required foreign keys survive direct inserts on each surface" do
    [
      ["app", client_tokens(:one).device_session.principal_public_id, client_tokens(:one), OpAppGrant,
       OpAppAuthorityStopRootTarget, OpAppAuthorityStopGrantTarget, :client_token_id, "base-app-ww",],
      ["org", operator_tokens(:one).device_session.principal_public_id, operator_tokens(:one), OpOrgGrant,
       OpOrgAuthorityStopRootTarget, OpOrgAuthorityStopGrantTarget, :operator_token_id, "base-org-ww",],
    ].each do |realm, principal_public_id, root, grant_model, root_target, grant_target, parent_key, client_id|
      stop = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "target-database-boundaries", cutoff_epoch: 1,
      ).stop
      grant = grant_model.create!(parent_key => root.id, :authentication_epoch => 0, :oidc_client_id => client_id)

      [[root_target, :root_id, root.id], [grant_target, :grant_id, grant.id]].each do |model, target_key, target_id|
        attributes = { :stop_id => stop.id, target_key => target_id }
        model.insert_all!([attributes])

        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { model.insert_all!([attributes]) }
        end
        [:stop_id, target_key].each do |key|
          assert_raises(ActiveRecord::NotNullViolation) do
            model.transaction(requires_new: true) { model.insert_all!([attributes.merge(key => nil)]) }
          end
          assert_raises(ActiveRecord::InvalidForeignKey) do
            model.transaction(requires_new: true) { model.insert_all!([attributes.merge(key => -1)]) }
          end
        end
        assert_equal 1, model.where(stop_id: stop.id).count
      end
    end
  end
end
