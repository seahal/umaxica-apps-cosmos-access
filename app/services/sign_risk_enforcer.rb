# typed: false
# frozen_string_literal: true

class SignRiskEnforcer
  def self.call(root)
    configuration_for(root)
    return unless feature_enabled?

    score =
      case root
      when OperatorToken then SignRiskEngine.score(staff_id: root.subject_public_id)
      when ClientToken then SignRiskEngine.score(user_id: root.subject_public_id)
      end

    if score >= 100
      stop_principal_roots!(root)
    elsif score >= 60
      require_step_up!(root)
    end
  end

  def self.stop_principal_roots!(root)
    with_principal_roots(root) do |roots, devices|
      roots.each do |target|
        OpAuthorityStopCommitter.stop_root(
          root: target, cause: "risk", principal_public_id: root.subject_public_id,
          authority_evidence_ref: "sign_risk:#{root.public_id}",
        )
        raise OpAuthorityStopCommitter::Refused, "risk stop did not revoke its root" unless target.reload.revoked?
      end
      devices.each { |device| device.revoke!(reason: "sign_risk") }
    end
  end

  def self.require_step_up!(root)
    with_principal_roots(root, usable_only: true) do |roots, _devices|
      roots.each { |token| IdentityStepUpCeremonyFreshnessRevoker.call!(token) }
    end

    Rails.logger.info(
      JitLogEvent.format(
        "sign.risk.enforcer.step_up_required",
        realm: OpAuthorityStopCommitter.realm_for_root(root),
      ),
    )
  end

  def self.with_principal_roots(root, usable_only: false)
    owner, device_class = configuration_for(root)
    owner.connected_to(role: :writing) do
      owner.transaction do
        devices = device_class.where(principal_public_id: root.subject_public_id).order(:id).lock.to_a
        scope = root.class.where(device_session_id: devices.map(&:id))
        scope = scope.currently_usable_at(root.class.database_now) if usable_only
        roots = scope.order(:id).lock.to_a
        yield roots, devices
      end
    end
  end

  def self.configuration_for(root)
    case root
    when ClientToken then [OpBaseAppRecord, ClientDeviceSession]
    when OperatorToken then [OpBaseOrgRecord, OperatorDeviceSession]
    else raise ArgumentError, "risk enforcement requires an OP root session"
    end
  end

  def self.feature_enabled?
    return false if ENV["RISK_ENFORCEMENT_DISABLED"] == "true"

    enabled_config = Rails.configuration.try(:x).try(:risk_enforcement).try(:enabled)
    enabled_config || ENV["RISK_ENFORCEMENT_ENABLED"] == "true" || Rails.env.production?
  end

  private_class_method :with_principal_roots, :configuration_for
  public_class_method :call, :stop_principal_roots!, :require_step_up!, :feature_enabled?
end
