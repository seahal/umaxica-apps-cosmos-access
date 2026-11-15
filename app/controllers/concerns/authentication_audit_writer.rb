# typed: false
# frozen_string_literal: true

# Writes OP Chronicle records using scalar references to Governance-owned
# identities. Direct writes preserve those references without loading actor
# records. Best-effort writes store a sanitized Chronicle outbox payload when
# the direct projection fails.
class AuthenticationAuditWriter
  WRITE_FAILED_EVENT = "authentication.audit.write_failed"
  OUTBOX_UNAVAILABLE_EVENT = "authentication.audit.outbox_unavailable"
  OUTBOX_STATUS_PENDING = "pending"

  # OP sessions retain the external identity reference after its owning database leaves Access.
  # These events must persist without reloading a Governance-owned actor.
  def self.write_reference!(audit_class, event_id, subject_type:, subject_id:, actor_type:, actor_id:, context: {})
    raise ArgumentError, "unsupported OP audit model" unless [ClientChronicle, OperatorChronicle].include?(audit_class)

    ChronicleRecord.connected_to(role: :writing) do
      audit_class.create!(
        event_id: event_id,
        subject_type: subject_type,
        subject_id: subject_id,
        actor_type: actor_type,
        actor_id: actor_id,
        occurred_at: audit_class.database_now,
        context: context,
      )
    end
  end

  # A failed Chronicle projection must not undo an authoritative OP revocation.
  # Keep the existing recovery payload without reconstructing an external actor.
  def self.write_reference(audit_class, event_id, subject_type:, subject_id:, actor_type:, actor_id:, context: {})
    write_reference!(
      audit_class, event_id, subject_type: subject_type, subject_id: subject_id,
                             actor_type: actor_type, actor_id: actor_id, context: context,
    )
    true
  rescue StandardError => e
    event_uuid = SecureRandom.uuid
    notify_write_failed(event_uuid: event_uuid, error_class: e.class.name)
    enqueue_reference_recovery(
      event_uuid: event_uuid, audit_class: audit_class, event_id: event_id,
      subject_type: subject_type, subject_id: subject_id, actor_type: actor_type,
      actor_id: actor_id, context: context, error: e,
    )
    false
  end

  def self.enqueue_reference_recovery(event_uuid:, audit_class:, event_id:, subject_type:, subject_id:,
                                      actor_type:, actor_id:, context:, error:)
    ChronicleRecord.connected_to(role: :writing) do
      ChronicleOutboxEntry.create!(
        event: WRITE_FAILED_EVENT, event_uuid: event_uuid, status: OUTBOX_STATUS_PENDING,
        payload: {
          audit_class: audit_class.name,
          event_id: event_id.to_s,
          resource_type: subject_type,
          resource_id: subject_id,
          actor_type: actor_type,
          actor_id: actor_id,
          context: ChronicleRecordPolicy.sanitize(context),
          error_class: error.class.name,
        },
      )
    end
  rescue StandardError => e
    notify_write_failed(
      event: OUTBOX_UNAVAILABLE_EVENT, event_uuid: event_uuid,
      error_class: e.class.name, manual_recovery_required: true,
    )
    false
  end
  private_class_method :enqueue_reference_recovery

  def self.notify_write_failed(payload)
    Rails.logger.info(JitLogEvent.format(WRITE_FAILED_EVENT, payload))
  rescue StandardError
    false
  end

  private_class_method :notify_write_failed
  public_class_method :write_reference!, :write_reference
end
