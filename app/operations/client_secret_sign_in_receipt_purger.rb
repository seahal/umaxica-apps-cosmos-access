# frozen_string_literal: true

# Ticket commit evidence survives every live continuation and source reconciliation.
class ClientSecretSignInReceiptPurger
  class << self
    public

    def call!(receipt:, retention_after:)
      unless receipt.is_a?(ClientSecretSignInReceipt) && receipt.persisted? &&
          retention_after.is_a?(ActiveSupport::Duration) && retention_after.value.finite? &&
          retention_after.value.positive?
        raise ArgumentError, "Secret receipt collection requires a persisted receipt and explicit finite retention"
      end

      raise GovernanceLookupUnavailableError, "Governance receipt retention and credential lookup is unavailable"
    end
  end
end
