# frozen_string_literal: true

require "test_helper"

class OpActorAuditReferenceTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "client audit event UUID rejects duplicates while historical rows without UUID remain valid" do
    attributes = {
      subject_type: "Client",
      subject_id: "123",
      actor_type: "Client",
      actor_id: "123",
      event_id: ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
      occurred_at: Time.current,
    }
    event_uuid = SecureRandom.uuid
    ClientChronicle.create!(**attributes, event_uuid: event_uuid)
    duplicate = ClientChronicle.new(**attributes, event_uuid: event_uuid)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:event_uuid, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientChronicle.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
    2.times { assert_predicate ClientChronicle.create!(**attributes, event_uuid: nil), :persisted? }
  end

  test "refresh reuse keeps both realms' historical actor references without resolving retired actors" do
    [
      [ClientToken, ClientChronicle, ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED, "Client", :user_id],
      [OperatorToken, OperatorChronicle, OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED, "Operator", :staff_id],
    ].each do |token_class, audit_class, event_id, historical_type, foreign_key|
      token = token_class.find(ActiveRecord::FixtureSet.identify(:one))
      before = audit_class.where(event_id: event_id).count

      RefreshTokenReuseActivityRecorder.call(token: token, result: "rp_session_revoked")

      assert_equal before + 1, audit_class.where(event_id: event_id).count
      audit = audit_class.where(event_id: event_id).order(id: :desc).first!

      assert_equal token[foreign_key].to_s, audit.subject_id.to_s
      assert_equal historical_type, audit.subject_type
      assert_equal token[foreign_key].to_s, audit.actor_id.to_s
      assert_equal historical_type, audit.actor_type
      assert_equal "rp_session_revoked", audit.context.fetch("result")
    end
  end

  test "scalar audit identities remain mandatory after actor navigation is removed" do
    [
      [ClientChronicle, ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED],
      [OperatorChronicle, OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED],
    ].each do |audit_class, event_id|
      audit = audit_class.new(event_id: event_id, subject_id: "", subject_type: "", actor_id: nil, actor_type: "")

      assert_not audit.valid?
      assert_includes audit.errors.attribute_names, :subject_id
      assert_includes audit.errors.attribute_names, :subject_type
      assert_includes audit.errors.attribute_names, :actor_id
      assert_includes audit.errors.attribute_names, :actor_type
    end
  end

  test "Chronicle projection failure cannot roll back the authoritative refresh reuse stop" do
    root = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    grant = OpAppGrant.create!(
      client_token_id: root.id, device_session_id: root.device_session_id,
      authentication_epoch: root.authentication_epoch,
      oidc_client_id: "core-app-jp", refresh_token_expires_at: 1.hour.from_now,
    )
    original = grant.issue_refresh_token!

    rotation = OidcRefreshTokenIssuer.call(refresh_token: original, resource_type: "client")

    assert_equal :rotated, rotation.success? ? :rotated : :refused
    pending_before = ChronicleOutboxEntry.where(event: AuthenticationAuditWriter::WRITE_FAILED_EVENT).count
    result =
      AuthenticationAuditWriter.stub(
        :write_reference!, ->(*, **) { raise ActiveRecord::ConnectionNotEstablished, "Chronicle unavailable" },
      ) do
        OidcRefreshTokenIssuer.call(refresh_token: original, resource_type: "client")
      end

    assert_not result.success?
    assert_equal :refresh_token_reuse_detected, result.reason
    assert_predicate grant.reload, :revoked?
    assert_equal pending_before + 1,
                 ChronicleOutboxEntry.where(event: AuthenticationAuditWriter::WRITE_FAILED_EVENT).count
  end
end
