# frozen_string_literal: true

require "test_helper"

class OpAuthorityStopDeliveryUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "each realm keeps exactly one epoch cutoff per stop while allowing different stops" do
    [
      ["app", client_tokens(:one).device_session.principal_public_id, OpAppAuthorityStopEpochCutoff],
      ["org", operator_tokens(:one).device_session.principal_public_id, OpOrgAuthorityStopEpochCutoff],
    ].each do |realm, principal_public_id, model|
      stops =
        %w(first second).map do |event|
          OpAuthorityStopCommitter.stop_principal(
            realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
            authority_evidence_ref: "epoch-uniqueness-#{event}", cutoff_epoch: 1,
          ).stop
        end
      original = model.find_by!(stop_id: stops.first.id)

      assert_predicate original, :valid?
      assert_predicate model.find_by!(stop_id: stops.second.id), :valid?

      duplicate = model.new(stop: stops.first, cutoff_epoch: 2)

      assert_not_predicate duplicate, :valid?
      assert duplicate.errors.of_kind?(:stop_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_equal 2, model.where(stop_id: stops.map(&:id)).count
    end
  end

  test "delivery participants are unique by stop and grant on each realm" do
    [
      ["app", client_tokens(:one).device_session.principal_public_id, client_tokens(:one), OpAppGrant, :client_token_id,
       OpAppAuthorityStopParticipant, %w(core-app-jp warp-app-jp),],
      ["org", operator_tokens(:one).device_session.principal_public_id, operator_tokens(:one), OpOrgGrant, :operator_token_id,
       OpOrgAuthorityStopParticipant, %w(core-org-jp warp-org-jp),],
    ].each do |realm, principal_public_id, root, grant_model, parent_key, model, client_ids|
      grants =
        client_ids.map do |client_id|
          grant_model.create!(**{ parent_key => root.id }, authentication_epoch: 0, oidc_client_id: client_id)
        end
      stop = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [root], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "participant-uniqueness", cutoff_epoch: 1,
      ).stop
      original = model.find_by!(stop_id: stop.id, grant_id: grants.first.id)
      sibling = model.find_by!(stop_id: stop.id, grant_id: grants.second.id)

      assert_predicate original, :valid?
      assert_predicate sibling, :valid?

      duplicate = original.dup

      assert_not_predicate duplicate, :valid?
      assert duplicate.errors.of_kind?(:grant_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }

      other_stop = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "another-participant-stop", cutoff_epoch: 1,
      ).stop
      other_owner = original.dup
      other_owner.stop = other_stop
      other_owner.save!

      assert_predicate other_owner, :persisted?
      assert_equal 3, model.where(stop_id: [stop.id, other_stop.id]).count
    end
  end

  test "epoch and participant database uniqueness and required references survive bypassed validations" do
    [
      ["app", client_tokens(:one).device_session.principal_public_id, client_tokens(:one), OpAppGrant, :client_token_id,
       OpAppAuthorityStopEpochCutoff, OpAppAuthorityStopParticipant, "core-app-jp",],
      ["org", operator_tokens(:one).device_session.principal_public_id, operator_tokens(:one), OpOrgGrant, :operator_token_id,
       OpOrgAuthorityStopEpochCutoff, OpOrgAuthorityStopParticipant, "core-org-jp",],
    ].each do |realm, principal_public_id, root, grant_model, parent_key, epoch_model, participant_model, client_id|
      grant_model.create!(**{ parent_key => root.id }, authentication_epoch: 0, oidc_client_id: client_id)
      stop = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [root], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "delivery-database-boundaries", cutoff_epoch: 1,
      ).stop
      epoch = epoch_model.find_by!(stop_id: stop.id)
      participant = participant_model.find_by!(stop_id: stop.id)

      [
        [epoch_model, epoch, [:stop_id]],
        [participant_model, participant, %i(stop_id grant_id status_id)],
      ].each do |model, record, reference_keys|
        attributes = record.attributes.except("id", "created_at", "updated_at")
        relation = model.where(id: record.id)

        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { model.insert_all!([attributes]) }
        end
        reference_keys.each do |key|
          assert_raises(ActiveRecord::NotNullViolation) do
            model.transaction(requires_new: true) { relation.update_all(key => nil) }
          end
          assert_raises(ActiveRecord::InvalidForeignKey) do
            model.transaction(requires_new: true) { relation.update_all(key => -1) }
          end
        end
        assert_equal 1, model.where(stop_id: stop.id).count
      end
    end
  end
end
