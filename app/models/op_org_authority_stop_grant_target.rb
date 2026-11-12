# typed: false
# frozen_string_literal: true

class OpOrgAuthorityStopGrantTarget < OpBaseOrgRecord
  belongs_to :stop, class_name: "OpOrgAuthorityStop", inverse_of: :grant_targets
  belongs_to :grant, class_name: "OpOrgGrant"

  validates :grant_id, uniqueness: { scope: :stop_id }
end
