# frozen_string_literal: true

require "test_helper"

class OpAuthorityStopPublicIdCollisionTest < ActiveSupport::TestCase
  test "a native public identity collision after preflight retries after its savepoint is rolled back" do
    [["app", PublicId.generate, OpAppAuthorityStop],
     ["org", PublicId.generate, OpOrgAuthorityStop],].each do |realm, principal_public_id, model|
      original = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "native-collision-template", cutoff_epoch: 1,
      ).stop
      first_id = PublicId.generate
      fresh_id = PublicId.generate
      generated = [first_id, fresh_id]
      attributes = original.attributes.except("id", "created_at", "updated_at").merge(
        "public_id" => first_id, "idempotency_digest" => Digest::SHA256.digest("competing-public-identity"),
      )
      inserted = false
      result = nil
      # Insert after the actual preflight query returns: the next INSERT must hit PostgreSQL's
      # identity constraint. The fixture row is inside the candidate savepoint and rolls back too.
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload[:sql]
          if !inserted && sql.start_with?("SELECT \"#{model.table_name}\".\"id\" FROM") &&
              sql.include?("\"public_id\"")
            inserted = true
            model.insert_all!([attributes])
          end
        end

      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        PublicId.stub(:generate, -> { generated.shift }) do
          result = OpAuthorityStopCommitter.stop_principal(
            realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
            authority_evidence_ref: "native-collision-request", cutoff_epoch: 1,
          )
        end
      end

      assert inserted
      assert_empty generated
      assert_equal fresh_id, result.stop.public_id
      assert_not model.exists?(public_id: first_id)
      assert model.exists?(original.id)
    end
  end

  test "a native business uniqueness failure is propagated without generating another identity" do
    [["app", PublicId.generate, OpAppAuthorityStop],
     ["org", PublicId.generate, OpOrgAuthorityStop],].each do |realm, principal_public_id, model|
      original = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "business-collision-template", cutoff_epoch: 1,
      ).stop
      fresh_id = PublicId.generate
      digest = Digest::SHA256.digest("#{realm}:principal:#{principal_public_id}:business-collision-request")
      attributes = original.attributes.except("id", "created_at", "updated_at").merge(
        "public_id" => PublicId.generate, "idempotency_digest" => digest,
      )
      inserted = false
      calls = 0
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload[:sql]
          if !inserted && sql.start_with?("SELECT \"#{model.table_name}\".\"id\" FROM") &&
              sql.include?("\"idempotency_digest\"")
            inserted = true
            model.insert_all!([attributes])
          end
        end
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
            PublicId.stub(
              :generate, -> {
                           calls += 1
                           fresh_id
                         },
            ) do
              model.transaction(requires_new: true) do
                OpAuthorityStopCommitter.stop_principal(
                  realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
                  authority_evidence_ref: "business-collision-request", cutoff_epoch: 1,
                )
              end
            end
          end
        end

      assert inserted
      assert_equal 1, calls
      assert_equal "index_#{model.table_name}_on_realm_and_idempotency_digest",
                   error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      assert_not model.exists?(idempotency_digest: digest)
    end
  end

  test "generated public identity preflight collisions permit success below and at the retry limit" do
    [
      ["app", PublicId.generate, OpAppAuthorityStop, OpAppAuthorityStopEpochCutoff],
      ["org", PublicId.generate, OpOrgAuthorityStop, OpOrgAuthorityStopEpochCutoff],
    ].each do |realm, principal_public_id, model, epoch_model|
      original = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "original-identity", cutoff_epoch: 1,
      ).stop
      [PublicId::MAX_COLLISION_RETRIES - 1, PublicId::MAX_COLLISION_RETRIES].each do |collisions|
        fresh_id = PublicId.generate
        generated = Array.new(collisions, original.public_id) + [fresh_id]
        result = nil

        PublicId.stub(:generate, -> { generated.shift }) do
          result = OpAuthorityStopCommitter.stop_principal(
            realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
            authority_evidence_ref: "fresh-identity-#{collisions}", cutoff_epoch: 1,
          )
        end

        assert_empty generated
        assert_equal fresh_id, result.stop.public_id
        assert_not_predicate result, :replayed?
        assert_equal 2, model.where(id: [original.id, result.stop.id]).count
        assert_equal 1, epoch_model.where(stop_id: result.stop.id).count
      end
    end
  end

  test "exhausted generated public identity collisions roll back roots grants and stop children" do
    [
      ["app", PublicId.generate, ClientToken, ClientDeviceSession, :user_id, :client_token_id,
       OpAppGrant, :client_token_id,
       OpAppAuthorityStop, OpAppAuthorityStopEpochCutoff, OpAppAuthorityStopRootTarget,
       OpAppAuthorityStopGrantTarget, OpAppAuthorityStopParticipant, "core-app-jp",],
      ["org", PublicId.generate, OperatorToken, OperatorDeviceSession, :staff_id, :operator_token_id,
       OpOrgGrant, :operator_token_id,
       OpOrgAuthorityStop, OpOrgAuthorityStopEpochCutoff, OpOrgAuthorityStopRootTarget,
       OpOrgAuthorityStopGrantTarget, OpOrgAuthorityStopParticipant, "core-org-jp",],
    ].each do |realm, principal_public_id, token_model, device_model, actor_key, root_key, grant_model,
               _parent_key, model, epoch_model,
               root_target, grant_target, participant, client_id|
      original = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "retained-identity", cutoff_epoch: 1,
      ).stop
      actor_id = SecureRandom.random_number(1_000_000) + 9_300_000
      device = device_model.create!(:subject_public_id => principal_public_id)
      root = token_model.create!(
        :subject_public_id => device.subject_public_id, :device_session => device, :authentication_epoch => 0,
      )
      grant = grant_model.create!(
        root_key => root.id, :device_session_id => device.id,
        :authentication_epoch => 0, :oidc_client_id => client_id,
      )
      deadline = root.discard_at
      before_counts = [model, epoch_model, root_target, grant_target, participant].map(&:count)
      calls = 0

      PublicId.stub(
        :generate, -> {
                     calls += 1
                     original.public_id
                   },
      ) do
        error =
          assert_raises(ActiveRecord::RecordInvalid) do
            OpAuthorityStopCommitter.stop_root(
              root: root, cause: "browser_logout", principal_public_id: principal_public_id,
              authority_evidence_ref: "collision-exhausted",
            )
          end

        assert error.record.errors.of_kind?(:public_id, :taken)
      end

      assert_equal PublicId::MAX_COLLISION_RETRIES + 1, calls
      assert_equal before_counts, [model, epoch_model, root_target, grant_target, participant].map(&:count)
      assert_not_predicate root.reload, :revoked?
      assert_equal deadline, root.discard_at
      assert_nil grant.reload.revoked_at
    end
  end

  test "non collision validation failures never spend the generated identity retry budget" do
    [["app", PublicId.generate, OpAppAuthorityStop],
     ["org", PublicId.generate, OpOrgAuthorityStop],].each do |realm, principal_public_id, model|
      calls = 0
      original_count = model.count

      PublicId.stub(
        :generate, -> {
                     calls += 1
                     ""
                   },
      ) do
        error =
          assert_raises(ActiveRecord::RecordInvalid) do
            OpAuthorityStopCommitter.stop_principal(
              realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
              authority_evidence_ref: "blank-generated-value", cutoff_epoch: 1,
            )
          end

        assert error.record.errors.of_kind?(:public_id, :blank)
      end

      assert_equal 1, calls
      assert_equal original_count, model.count

      template = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "mixed-validation-template", cutoff_epoch: 1,
      ).stop
      original_count = model.count
      calls = 0
      PublicId.stub(
        :generate, -> {
                     calls += 1
                     template.public_id
                   },
      ) do
        error =
          assert_raises(ActiveRecord::RecordInvalid) do
            OpAuthorityStopCommitter.stop_principal(
              realm: realm, roots: [], cause: "identity_stop", principal_public_id: "p" * 256,
              authority_evidence_ref: "mixed-validation-failure", cutoff_epoch: 1,
            )
          end

        assert error.record.errors.of_kind?(:public_id, :taken)
        assert error.record.errors.of_kind?(:principal_public_id, :too_long)
      end

      assert_equal 1, calls
      assert_equal original_count, model.count

      fresh_id = PublicId.generate
      calls = 0
      PublicId.stub(
        :generate, -> {
                     calls += 1
                     fresh_id
                   },
      ) do
        error =
          assert_raises(ActiveRecord::RecordInvalid) do
            OpAuthorityStopCommitter.stop_principal(
              realm: realm, roots: [], cause: "identity_stop", principal_public_id: "p" * 256,
              authority_evidence_ref: "invalid-principal-reference", cutoff_epoch: 1,
            )
          end

        assert error.record.errors.of_kind?(:principal_public_id, :too_long)
      end

      assert_equal 1, calls
      assert_equal original_count, model.count
    end
  end
end
