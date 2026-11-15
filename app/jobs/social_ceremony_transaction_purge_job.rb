# typed: false
# frozen_string_literal: true

class SocialCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  public

  def perform
    IdentitySocialCeremonyTransactionPurger.call
  end
end
