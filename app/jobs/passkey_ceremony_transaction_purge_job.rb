# typed: false
# frozen_string_literal: true

class PasskeyCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  public

  def perform
    IdentityPasskeyCeremonyTransactionPurger.call
  end
end
