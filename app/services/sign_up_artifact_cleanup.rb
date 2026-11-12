# frozen_string_literal: true

class SignUpArtifactCleanup
  BATCH_SIZE = 100

  def self.call(cycle:, now: Time.current)
    raise GovernanceLookupUnavailableError, "Governance sign-up artifact cleanup authority is unavailable"
  end

  def self.cleanup_pending!(now: nil, batch_size: BATCH_SIZE)
    raise GovernanceLookupUnavailableError, "Governance sign-up artifact cleanup authority is unavailable"
  end

  def self.cleanup_pending_for(_cycle_class, now:, batch_size:)
    raise GovernanceLookupUnavailableError, "Governance sign-up artifact cleanup authority is unavailable"
  end
end
