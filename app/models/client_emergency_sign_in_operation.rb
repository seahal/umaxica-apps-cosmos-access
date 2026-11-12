# typed: false
# frozen_string_literal: true

# Proof, committed with the ClientToken it names, that an Emergency Secret Credential sign-in
# operation created its app session. adr/emergency-secret-credential-commit-acknowledgement.md
class ClientEmergencySignInOperation < OpBaseAppRecord
  belongs_to :client_token, inverse_of: :emergency_sign_in_operation

  validates :operation_id, presence: true
  validates :operation_id, :credential_public_id, :client_token_id, uniqueness: true
  validates :credential_public_id, presence: true, length: { maximum: 21 }
end
