# typed: false
# frozen_string_literal: true

# Closes expired OP sign-up tickets locally. Artifact cleanup remains held until
# Governance can verify its authority; this job exposes that unavailable boundary.
class SignUpExpiryJob < ApplicationJob
  queue_as :retention

  TICKET_CLASSES = [ClientSignUpFlow].freeze

  public

  def perform(batch_size: 100)
    raise ArgumentError, "batch_size must be positive" unless batch_size.to_i.positive?

    first_failure = nil
    TICKET_CLASSES.each do |ticket_class|
      now = ticket_class.database_now
      expired_scope(ticket_class, now: now).in_batches(of: batch_size) do |batch|
        batch.each do |ticket|
          begin
            expire_ticket(ticket)
          rescue ActiveRecord::Deadlocked
            raise
          rescue StandardError => e
            first_failure ||= e
          end
        end
      end
    end
    raise first_failure if first_failure
  end

  private

  def expired_scope(ticket_class, now:)
    ticket_class
      .where(status_id: ticket_class.sign_up_in_progress_status_ids)
      .where(ticket_class.arel_table[:expires_at].lteq(now))
  end

  def expire_ticket(ticket)
    ticket.expire_sign_up!
    raise GovernanceLookupUnavailableError, "Governance sign-up artifact cleanup verification is unavailable"
  rescue ActiveRecord::Deadlocked
    raise
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "sign_up.expiry.failed",
        ticket_public_id: ticket.public_id,
        error_class: e.class.name,
      ),
    )
    raise
  end
end
