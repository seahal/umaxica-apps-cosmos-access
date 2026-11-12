# typed: false
# frozen_string_literal: true

module SessionLimitResolutionTransactionable
  extend ActiveSupport::Concern

  PENDING = 10
  SESSION_SELECTED = 20
  RESOLVED = 100
  EXPIRED = 910
  CANCELLED = 920
  OPEN_STATES = [PENDING, SESSION_SELECTED].freeze
  TERMINAL_STATES = [RESOLVED, EXPIRED, CANCELLED].freeze
  WAITING_SLOT = 1
  TTL = 15.minutes

  TRANSITIONS = {
    PENDING => [SESSION_SELECTED, RESOLVED, EXPIRED, CANCELLED],
    SESSION_SELECTED => [RESOLVED, EXPIRED, CANCELLED],
    RESOLVED => [],
    EXPIRED => [],
    CANCELLED => [],
  }.freeze

  Issuance = Data.define(:transaction, :challenge)

  class WaitingSlotOccupied < StandardError; end

  def self.model_for(_actor)
    raise GovernanceLookupUnavailableError, "Governance session-limit authority is unavailable"
  end
  public_class_method :model_for

  class_methods do
    def resolution_actor_class
      raise GovernanceLookupUnavailableError, "Governance session-limit authority is unavailable"
    end

    def resolution_token_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientToken
      when "OperatorSessionLimitResolutionTransaction" then OperatorToken
      else
        raise FlowConfigurationError, "#{name} has no resolution token class"
      end
    end

    def resolution_device_session_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientDeviceSession
      when "OperatorSessionLimitResolutionTransaction" then OperatorDeviceSession
      else
        raise FlowConfigurationError, "#{name} has no resolution device-session class"
      end
    end

    def resolution_sign_in_flow_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientSignInFlow
      when "OperatorSessionLimitResolutionTransaction" then OperatorSignInFlow
      else
        raise FlowConfigurationError, "#{name} has no resolution sign-in-flow class"
      end
    end

    def resolution_oidc_authorization_transaction_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientOidcAuthorizationTransaction
      when "OperatorSessionLimitResolutionTransaction" then OperatorOidcAuthorizationTransaction
      else
        raise FlowConfigurationError, "#{name} has no resolution authorization-transaction class"
      end
    end

    def resolution_state_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientSessionLimitResolutionState
      when "OperatorSessionLimitResolutionTransaction" then OperatorSessionLimitResolutionState
      else
        raise FlowConfigurationError, "#{name} has no resolution state class"
      end
    end

    def database_now
      lease_connection.select_value("SELECT CURRENT_TIMESTAMP").to_time
    end

    def open
      where(state_id: OPEN_STATES)
    end

    def active_at
      open.where(arel_table[:expires_at].gt(database_now))
    end

    def issue!(sign_in_flow:, actor:, browser_binding_digest:, oidc_authorization_transaction: nil,
               audit_context: {})
      raise GovernanceLookupUnavailableError, "Governance session-limit authority is unavailable"
    end

    def find_active_by_challenge(challenge)
      active_at.find_by(challenge_digest: digest_challenge(challenge))
    end

    def find_by_challenge(challenge)
      find_by(challenge_digest: digest_challenge(challenge))
    end

    def digest_challenge(challenge)
      OpenSSL::Digest::SHA256.hexdigest(challenge.to_s)
    end

    def expire_elapsed_for_actor!(_actor, writer_now:)
      raise GovernanceLookupUnavailableError, "Governance session-limit authority is unavailable"
    end
  end

  public

  def pending?
    state_id == PENDING
  end

  def session_selected?
    state_id == SESSION_SELECTED
  end

  def resolved?
    state_id == RESOLVED
  end

  def expired?
    state_id == EXPIRED
  end

  def cancelled?
    state_id == CANCELLED
  end

  def open?
    OPEN_STATES.include?(state_id) && waiting_slot == WAITING_SLOT && expires_at.present? &&
      expires_at > self.class.database_now
  end

  def terminal?
    TERMINAL_STATES.include?(state_id)
  end

  def expired_at?
    expires_at.present? && expires_at <= self.class.database_now
  end

  def select_session!(actor:, challenge:, session_ref:, browser_binding_digest:)
    raise GovernanceLookupUnavailableError, "Governance session-limit authority is unavailable"
  end

  def resolve!(actor:, challenge:, browser_binding_digest:)
    raise GovernanceLookupUnavailableError, "Governance session-limit authority is unavailable"
  end

  def finalize_for_session_issuance!(actor:, parent:, challenge:, browser_binding_digest:,
                                     authorization_transaction: nil)
    raise GovernanceLookupUnavailableError, "Governance session-limit authority is unavailable"
  end

  def cancel!(actor:, challenge:, browser_binding_digest:)
    raise GovernanceLookupUnavailableError, "Governance session-limit authority is unavailable"
  end

  def expire!
    raise GovernanceLookupUnavailableError, "Governance session-limit authority is unavailable"
  end

  private

  def waiting_slot_matches_state
    if OPEN_STATES.include?(state_id) && waiting_slot != WAITING_SLOT
      errors.add(:waiting_slot, "must be 1 for an open resolution")
    elsif TERMINAL_STATES.include?(state_id) && waiting_slot.present?
      errors.add(:waiting_slot, "must be empty for a terminal resolution")
    end
  end
end
