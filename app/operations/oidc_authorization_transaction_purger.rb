# typed: false
# frozen_string_literal: true

# Deletes authorization transactions whose expiry is at least RETENTION_PERIOD in the past.
# Secret-linked APP history remains held until Governance can verify its claim-retention facts.
# Independent OP history can still be collected; the unavailable hold is reported after that work.
class OidcAuthorizationTransactionPurger
  MODELS = {
    "app" => ClientOidcAuthorizationTransaction,
    "org" => OperatorOidcAuthorizationTransaction,
  }.freeze

  SESSION_LIMIT_RESOLUTION_MODELS = {
    ClientOidcAuthorizationTransaction => [ClientSessionLimitResolutionTransaction, ClientSignInFlow],
    OperatorOidcAuthorizationTransaction => [OperatorSessionLimitResolutionTransaction, OperatorSignInFlow],
  }.freeze

  class << self
    public

    def call(now: Time.current, retention_period: OidcAuthorizationTransactionable::RETENTION_PERIOD)
      new(now: now, retention_period: retention_period).call
    end
  end

  public

  def initialize(now: Time.current, retention_period: OidcAuthorizationTransactionable::RETENTION_PERIOD)
    @now = now
    @retention_period = retention_period
    validate_retention_period!
  end

  def call
    counts =
      MODELS.transform_values do |model|
        model.connection_owner.connected_to(role: :writing) do
          purge_transactions(model.purgeable_at(now, retention_period: retention_period), model)
        end
      end
    raise @governance_hold if @governance_hold

    counts
  end

  private

  attr_reader :now, :retention_period

  def purge_transactions(candidates, model)
    deleted = 0
    candidates.in_batches(of: 500) do |batch|
      batch.pluck(:id).each do |id|
        deleted += purge_candidate(model, id)
      rescue GovernanceLookupUnavailableError => e
        # This expected external-authority hold is surfaced after independent rows and realms finish.
        @governance_hold ||= e
      end
    end
    deleted
  end

  def purge_candidate(model, id)
    model.transaction do
      row = model.purgeable_at(now, retention_period: retention_period).lock.find_by(id: id)
      next 0 unless row

      if model == ClientOidcAuthorizationTransaction && row.secret_sign_in_flow_id
        # The existing optional historical link identifies Source-dependent ownership. No proof of
        # absence can be inferred after Zenith removal, even if a local receipt is not present.
        raise GovernanceLookupUnavailableError, "Governance credential-claim retention verification is unavailable"
      end
      next 0 unless purge_session_limit_resolutions_for!(row, model)
      next 0 unless AuthAdmissionBindingPurger.purge_for_parent!(parent: row, now:, retention_period:)

      model.where(id: row.id).delete_all
    end
  end

  def validate_retention_period!
    value =
      case retention_period
      when ActiveSupport::Duration then retention_period.value
      when Numeric then retention_period
      else raise ArgumentError, "retention period must be a duration or number"
      end
    raise ArgumentError, "retention period must be finite and positive" unless value.finite? && value.positive?
  end

  # Session-limit resolution rows are terminal audit facts, but their parent
  # authorization transaction has a restrictive FK. The resolution is
  # collected at the same parent-retention boundary, after open resolutions and
  # RESOLVED continuations that still lack a root token have been held. This
  # keeps child-before-parent ordering explicit without treating a terminal
  # resolution as an indefinite parent hold.
  def purge_session_limit_resolutions_for!(parent, authorization_model)
    resolution_model, flow_model = SESSION_LIMIT_RESOLUTION_MODELS.fetch(authorization_model)
    resolutions = resolution_model.where(oidc_authorization_transaction_id: parent.id).lock.to_a
    return true if resolutions.empty?

    flow_ids = resolutions.map(&:sign_in_flow_id)
    flow_ids.uniq!
    flows = flow_model.where(id: flow_ids).index_by(&:id)
    return false if resolutions.any? do |resolution|
      flow = flows[resolution.sign_in_flow_id]
      !flow || !resolution.state_id.in?(resolution_model::TERMINAL_STATES) ||
        (resolution.state_id == resolution_model::RESOLVED && flow.token_id.nil?)
    end

    resolution_model.where(id: resolutions.map(&:id)).delete_all
    true
  end
end
