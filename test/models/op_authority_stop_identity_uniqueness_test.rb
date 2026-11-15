# frozen_string_literal: true

require "test_helper"

class OpAuthorityStopIdentityUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "a binary idempotency digest identifies one stop within its realm" do
    [
      ["app", client_tokens(:one).device_session.subject_public_id, OpAppAuthorityStop],
      ["org", operator_tokens(:one).device_session.subject_public_id, OpOrgAuthorityStop],
    ].each do |realm, principal_public_id, model|
      result = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "stop-identity", cutoff_epoch: 1,
      )
      original = result.stop
      expected_digest = Digest::SHA256.digest("#{realm}:principal:#{principal_public_id}:stop-identity")

      assert_predicate original, :valid?
      assert_equal expected_digest.bytes, original.reload.idempotency_digest.bytes

      duplicate = original.dup
      duplicate.public_id = PublicId.generate

      assert_not_predicate duplicate, :valid?
      assert duplicate.errors.of_kind?(:idempotency_digest, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }

      public_identity_duplicate = original.dup
      public_identity_duplicate.idempotency_digest = Digest::SHA256.digest("another-business-key")

      assert_not_predicate public_identity_duplicate, :valid?
      assert public_identity_duplicate.errors.of_kind?(:public_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { public_identity_duplicate.save! }

      other = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "other-stop-identity", cutoff_epoch: 1,
      )

      assert_not_equal original.id, other.stop.id
      assert_not_equal original.idempotency_digest, other.stop.idempotency_digest
      assert_predicate other.stop, :valid?
      assert_equal 2, model.where(id: [original.id, other.stop.id]).count
    end
  end

  test "binary digest bytes are preserved and independently owned by each realm database" do
    bytes = "\x00\xff".b * 16
    [
      ["app", client_tokens(:one).device_session.subject_public_id, OpAppAuthorityStop],
      ["org", operator_tokens(:one).device_session.subject_public_id, OpOrgAuthorityStop],
    ].each do |realm, principal_public_id, _model|
      stop = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "realm-binary-identity", cutoff_epoch: 1,
      ).stop
      candidate = stop.dup
      candidate.public_id = PublicId.generate
      candidate.idempotency_digest = bytes
      candidate.save!

      assert_equal bytes.bytes, candidate.reload.idempotency_digest.bytes

      candidate.realm = (realm == "app") ? "org" : "app"

      assert_not_predicate candidate, :valid?
      assert candidate.errors.of_kind?(:realm, :inclusion)
    end
  end

  test "database uniqueness rejects duplicate public identities and binary digest keys independently" do
    [
      ["app", client_tokens(:one).device_session.subject_public_id, OpAppAuthorityStop],
      ["org", operator_tokens(:one).device_session.subject_public_id, OpOrgAuthorityStop],
    ].each do |realm, principal_public_id, model|
      stop = OpAuthorityStopCommitter.stop_principal(
        realm: realm, roots: [], cause: "identity_stop", principal_public_id: principal_public_id,
        authority_evidence_ref: "identity-database-constraints", cutoff_epoch: 1,
      ).stop
      attributes = stop.attributes.except("id", "created_at", "updated_at")

      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) do
          model.insert_all!([attributes.merge("public_id" => PublicId.generate)])
        end
      end
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) do
          model.insert_all!([attributes.merge("idempotency_digest" => "\x00\xff".b * 16)])
        end
      end
      assert_equal 1, model.where(idempotency_digest: stop.idempotency_digest).count
    end
  end
end
