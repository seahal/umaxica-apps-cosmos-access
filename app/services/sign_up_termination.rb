# frozen_string_literal: true

class SignUpTermination
  PHYSICAL_PURGE_DELAY = 30.minutes

  def self.call(cycle:, event:, actor_context: nil)
    raise GovernanceLookupUnavailableError, "Governance sign-up termination authority is unavailable"
  end

  public_class_method :call

  def self.halt_if_phase_violation(cycle:)
    raise GovernanceLookupUnavailableError, "Governance sign-up termination authority is unavailable"
  end
  public_class_method :halt_if_phase_violation
end
