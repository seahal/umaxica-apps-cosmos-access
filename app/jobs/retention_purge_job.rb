# typed: false
# frozen_string_literal: true

# Periodic physical deletion of records past their `purge_eligible_at` window.
#
# The set-based `delete_all` here is the Accepted, ADR-sanctioned exception to
# the forbidden-method rule on `delete_all`: see
# `adr/retainable-concern-and-retention-purge.md` and the "ADR-sanctioned
# data-retention exceptions" section of `docs/reference/forbidden-rails-methods.md`.
# Identifier retirement belongs to Governance. This job processes only its explicit local models.
class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  class AuthorityUnavailableError < StandardError; end

  DEFAULT_BATCH_SIZE = 500
  MAX_BATCH_SIZE = 500

  # Rows are deleted with `delete_all`, which applies database-level FK actions
  # but not AR callbacks. Sign-up flows retain their token references until
  # their own retention window is complete; the corresponding FKs are
  # ON DELETE RESTRICT, so a parent token cannot silently delete a child.
  # Child-before-parent ordering remains explicit for retention readability and
  # for any independently cascading relations that are added under review.
  RETAINABLE_MODELS = [
    AppPreferenceChronicle, OrgPreferenceChronicle,
    ClientChronicle, OperatorChronicle,
    ClientSessionLimitResolutionTransaction, OperatorSessionLimitResolutionTransaction,
    ClientSignInFlow, OperatorSignInFlow,
    ClientSignUpFlow, OperatorSignUpFlow,
    ClientToken, OperatorToken,
    ClientVerification, OperatorVerification,
    ClientStepUpSession, OperatorStepUpSession,
    AreaOccurrence, ClientOccurrence, VisitorOccurrence, OperatorOccurrence, ZipOccurrence,
    DomainOccurrence, IpOccurrence, EmailOccurrence, JwtOccurrence, TelephoneOccurrence,
  ].freeze

  # Operational kill switch, not a retention rule: the flag exists so an
  # operator can stop irreversible deletion during an incident, a data
  # migration, or a legal hold that is not yet expressed as a hold record.
  # Every unit of work below is selected by a time window (`purge_eligible_at: ..now`),
  # so a skipped run is inherently catch-up safe -- the next unsuspended run
  # processes the accumulated backlog. Returning normally keeps the recurring
  # schedule (config/recurring.yml, every 15 minutes) as the retry mechanism;
  # raising would only requeue work that is deliberately paused.
  FEATURE_NAME = :retention_purge_suspended

  def perform(batch_size: DEFAULT_BATCH_SIZE)
    limit = normalized_batch_size(batch_size)
    unless limit&.between?(1, MAX_BATCH_SIZE)
      raise ArgumentError, "batch_size must be between 1 and #{MAX_BATCH_SIZE}"
    end

    if FeatureFlags.enabled?(FEATURE_NAME)
      Rails.logger.warn(JitLogEvent.format("retention.purge.suspended"))
      return
    end

    failures = []
    RETAINABLE_MODELS.each do |klass|
      purge_retained_model(klass, batch_size: limit)
    rescue StandardError => e
      failures << e
      Rails.error.report(
        e,
        handled: false,
        context: { job: self.class.name, retained_model: klass.name, batch_size: limit },
      )
    end

    raise failures.first if failures.any?
  end

  private

  def purge_retained_model(klass, batch_size:)
    now = klass.database_now
    return if purge_special_retained_model(klass, now: now, batch_size: batch_size)
    return purge_root_tokens(klass, now: now, batch_size: batch_size) if klass == OperatorToken

    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size).delete_all
  end

  # Authority-stop records referencing a root go first (D-172 S-2); a root whose stop still has an
  # undelivered participant stays until the next run.
  def purge_root_tokens(klass, now:, batch_size:)
    realm = { OperatorToken => "org" }.fetch(klass)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      ids = batch.pluck(:id)
      held = OpAuthorityStopPurger.release_roots!(realm:, root_ids: ids)
      klass.where(id: ids - held).delete_all
    end
  end

  def purge_special_retained_model(klass, now:, batch_size:)
    if [ClientSignInFlow, OperatorSignInFlow].include?(klass)
      purge_sign_in_flows(klass, now: now, batch_size: batch_size)
    elsif klass == ClientSignUpFlow
      purge_client_authentication_flows(klass, now: now, batch_size: batch_size)
    elsif klass == ClientToken
      purge_client_tokens(klass, now: now, batch_size: batch_size)
    elsif [ClientSessionLimitResolutionTransaction, OperatorSessionLimitResolutionTransaction].include?(klass)
      purge_session_limit_resolutions(klass, now: now, batch_size: batch_size)
    else
      return false
    end
    true
  end

  def purge_client_authentication_flows(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      klass.transaction do
        batch.lock.to_a.each do |flow|
          next unless flow.purge_eligible_at <= klass.database_now
          next if sign_up_flow_retention_hold?(flow)

          # Source holds and secret/audit dependencies now belong to Governance. A missing
          # authority is a refusal, never evidence that this flow has no retention hold.
          raise AuthorityUnavailableError, "Governance retention authority is unavailable for APP sign-up flows"
        end
      end
    end
  end

  def purge_client_tokens(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      klass.transaction do
        batch.lock.to_a.each do |token|
          next unless token.purge_eligible_at <= klass.database_now

          # Refuse before releasing authority-stop records or deleting a root. Local expiry
          # alone does not prove the external source retention constraints are satisfied.
          raise AuthorityUnavailableError, "Governance retention authority is unavailable for APP root sessions"
        end
      end
    end
  end

  def sign_up_flow_retention_hold?(flow)
    !flow.sign_up_completed? && (!flow.sign_up_terminal? || !flow.cleanup_completed?)
  end

  def purge_sign_in_flows(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      klass.transaction do
        batch.lock.to_a.each do |flow|
          next if klass == ClientSignInFlow &&
            ClientOidcAuthorizationTransaction.exists?(secret_sign_in_flow_id: flow.id)

          klass.where(id: flow.id).delete_all
        end
      end
    end
  end

  def purge_session_limit_resolutions(klass, now:, batch_size:)
    flow_class =
      case klass.name
      when "ClientSessionLimitResolutionTransaction" then ClientSignInFlow
      when "OperatorSessionLimitResolutionTransaction" then OperatorSignInFlow
      else
        raise FlowConfigurationError, "unsupported session-limit resolution class: #{klass.name}"
      end
    terminal_states = [klass::RESOLVED, klass::EXPIRED, klass::CANCELLED]
    parent_ids = flow_class.where(purge_eligible_at: ..now).select(:id)
    klass.where(state_id: terminal_states, sign_in_flow_id: parent_ids, purge_eligible_at: ..now)
      .in_batches(of: batch_size).delete_all
  end

  def normalized_batch_size(value)
    return value if value.is_a?(Integer)
    return Integer(value) if value.is_a?(String)

    nil
  rescue ArgumentError, TypeError
    nil
  end
end
