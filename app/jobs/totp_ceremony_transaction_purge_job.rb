# typed: false
# frozen_string_literal: true

class TotpCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  public

  def perform
    IdentityTotpCeremonyTransactionPurger.new.call
  end
end
