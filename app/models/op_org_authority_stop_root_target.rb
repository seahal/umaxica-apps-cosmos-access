# typed: false
# frozen_string_literal: true

class OpOrgAuthorityStopRootTarget < OpBaseOrgRecord
  belongs_to :stop, class_name: "OpOrgAuthorityStop", inverse_of: :root_targets
  belongs_to :root, class_name: "OperatorToken"

  validates :root_id, uniqueness: { scope: :stop_id }
end
