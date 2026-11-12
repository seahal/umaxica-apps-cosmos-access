# frozen_string_literal: true

# Immutable command evidence, committed in the same transaction as the APP authority stops.
class OpAppGovernanceRevocationReceipt < OpBaseAppRecord
  self.implicit_order_column = "committed_at"

  validates :command_id, :issuer, :command_digest, :command, :committed_at, presence: true
  validates :command_id, format: { with: GovernanceRevocationCommandValue::UUID_PATTERN }
  validates :issuer, length: { maximum: 255 }
  validates :command_digest, length: { is: 32 }

  public

  def readonly? = persisted?
end
