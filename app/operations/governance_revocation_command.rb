# frozen_string_literal: true

# A receipt and every selected authority stop share the realm's OP transaction. Inserting the
# command UUID first serializes duplicates; a replay never selects sessions created afterward.
class GovernanceRevocationCommand
  class Conflict < StandardError; end

  class NotFound < StandardError; end

  class Forbidden < StandardError; end

  class InconsistentAuthority < StandardError; end

  REALMS = {
    "app" => {
      owner: OpBaseAppRecord,
      receipt: OpAppGovernanceRevocationReceipt,
      device: ClientDeviceSession,
      root: ClientToken,
      grant: OpAppGrant,
      receipt_primary_key: "op_app_governance_revocation_receipts_pkey",
    }.freeze,
    "org" => {
      owner: OpBaseOrgRecord,
      receipt: OpOrgGovernanceRevocationReceipt,
      device: OperatorDeviceSession,
      root: OperatorToken,
      grant: OpOrgGrant,
      receipt_primary_key: "op_org_governance_revocation_receipts_pkey",
    }.freeze,
  }.freeze

  class << self
    public

    def call(command:)
      new(command:).call
    end
  end

  def initialize(command:)
    @command = command
    @config = REALMS.fetch(command.realm)
  end

  public

  def call
    config.fetch(:owner).connected_to(role: :writing) do
      receipt_class.transaction do
        receipt, replayed = insert_receipt_or_replay
        revoke_selected_authority! unless replayed
        receipt
      end
    end
  end

  private

  attr_reader :command, :config

  def receipt_class = config.fetch(:receipt)

  def insert_receipt_or_replay
    prior = receipt_class.lock.find_by(command_id: command.command_id)
    return [matching_receipt!(prior), true] if prior

    receipt =
      receipt_class.transaction(requires_new: true) do
        receipt_class.create!(
          command_id: command.command_id, issuer: command.issuer, command_digest: command.digest,
          command: command.snapshot, committed_at: receipt_class.database_now,
        )
      end
    [receipt, false]
  rescue ActiveRecord::RecordNotUnique => e
    native = e.cause
    raise unless native.is_a?(PG::UniqueViolation) && native.result &&
      native.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) == config.fetch(:receipt_primary_key)

    [matching_receipt!(receipt_class.lock.find(command.command_id)), true]
  end

  def matching_receipt!(receipt)
    raise Conflict, "command identifier conflicts with a prior command" unless
      receipt.issuer == command.issuer && receipt.command_digest == command.digest &&
        receipt.command == command.snapshot

    receipt
  end

  def revoke_selected_authority!
    devices, roots = lock_targets!
    assert_no_unowned_live_grants!(devices, roots)
    roots.each do |root|
      OpAuthorityStopCommitter.stop_root(
        root:, cause: "administrative", principal_public_id: command.principal_public_id,
        authority_evidence_ref: "governance:#{command.command_id}",
      )
    end
    devices.each { |device| device.revoke!(reason: "governance_revocation", now: receipt_class.database_now) }
    assert_stopped!(devices, roots)
  end

  def lock_targets!
    case command.scope
    when "all_sessions"
      devices = config.fetch(:device).where(principal_public_id: command.principal_public_id).order(:id).lock.to_a
      roots = config.fetch(:root).where(device_session_id: devices.map(&:id)).order(:id).lock.to_a
      [devices, roots]
    when "session"
      candidate = config.fetch(:root).find_by(public_id: command.session_public_id)
      raise NotFound, "requested session is unavailable" unless candidate

      device = config.fetch(:device).lock.find(candidate.device_session_id)
      raise Forbidden, "requested session does not belong to the command subject" unless
        device.principal_public_id == command.principal_public_id

      # A device is the stable parent of its grants. Ending one root ends the authority of that
      # device, so lock every root of the device before the existing stop primitive takes grants.
      roots = config.fetch(:root).where(device_session_id: device.id).order(:id).lock.to_a
      raise NotFound, "requested session is unavailable" unless roots.any? { |root| root.id == candidate.id }

      [[device], roots]
    else
      raise ArgumentError, "unsupported command scope"
    end
  end

  def assert_no_unowned_live_grants!(devices, roots)
    grants = config.fetch(:grant).where(device_session_id: devices.map(&:id), revoked_at: nil)
    # D3: a grant's original rotating root may already be purged. Authority and revocation
    # follow its stable device parent and an existing root of that device, not that audit reference.
    root_device_ids = roots.map(&:device_session_id)
    root_device_ids.uniq!
    return unless grants.where.not(device_session_id: root_device_ids).exists?

    raise InconsistentAuthority, "a live grant has no revocable root"
  end

  def assert_stopped!(devices, roots)
    raise InconsistentAuthority, "selected root authority was not stopped" unless
      roots.all? { |root| root.reload.revoked? }
    raise InconsistentAuthority, "selected device authority was not stopped" unless
      devices.all? { |device| device.reload.revoked? }
    return unless config.fetch(:grant).exists?(device_session_id: devices.map(&:id), revoked_at: nil)

    raise InconsistentAuthority, "selected grant authority was not stopped"
  end
end
