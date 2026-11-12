# frozen_string_literal: true

# Successful Ticket commit evidence; failed attempts remain SignInFlow facts.
# This record does not authorize a claim or replace the canonical login boundary.
class ClientSecretSignInReceipt < OpBaseAppRecord
  class InvalidCommit < StandardError; end

  belongs_to :sign_in_flow, class_name: "ClientSignInFlow"

  attr_readonly :operation_id, :credential_ref, :client_ref, :sign_in_flow_id,
                :root_token_ref, :committed_at

  before_create :verify_successful_commit!

  validates :client_ref, :credential_ref, :root_token_ref, length: { maximum: 21 }
  validates :client_ref, :committed_at, :credential_ref, :operation_id, :root_token_ref, exclusion: { in: [nil] }
  validates :credential_ref, :operation_id, :root_token_ref, uniqueness: true

  private

  def verify_successful_commit!
    raise GovernanceLookupUnavailableError, "Governance credential commit verification is unavailable"
  end
end
