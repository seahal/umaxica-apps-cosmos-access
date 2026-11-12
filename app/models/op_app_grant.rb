# typed: false
# frozen_string_literal: true

class OpAppGrant < OpBaseAppRecord
  include RpSession

  has_many :step_up_contexts, class_name: "ClientStepUpContext", foreign_key: :grant_id,
                              inverse_of: :grant, dependent: :restrict_with_error
  has_many :step_up_commits, class_name: "ClientStepUpCommit", foreign_key: :grant_id,
                             inverse_of: :grant, dependent: :restrict_with_error

  has_one :logout_hint, class_name: "OpAppGrantLogoutHint", foreign_key: :grant_id, inverse_of: :grant,
                        dependent: :destroy

  belongs_to :client_device_session, class_name: "ClientDeviceSession", foreign_key: :device_session_id,
                                     inverse_of: :op_app_grants
  # Historical issuance reference. The root may be physically purged while this grant remains;
  # the device session is the live authority and the root/device match is checked at creation.

  attr_readonly :client_token_id, :device_session_id
  validates :client_token_id, presence: true
  validate :creating_root_matches_device, on: :create

  validates :public_id, presence: true, uniqueness: true, length: { maximum: 21 }
  # WU-17: written at issuance from the actor (roots) or the root (grants); never defaulted.
  validates :authentication_epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :oidc_client_id, presence: true, length: { maximum: 64 }
  validates :device_session_id, uniqueness: { scope: :oidc_client_id, conditions: -> { where(revoked_at: nil) } },
                                if: -> { revoked_at.nil? }
  validates :last_logout_status, inclusion: { in: RpSession::LOGOUT_STATUSES }, allow_nil: true
  validates :refresh_token_digest, uniqueness: true, allow_nil: true

  before_validation :bind_device_session_from_parent_token, on: :create

  before_validation :ensure_public_id, on: :create

  scope :currently_usable_at,
        ->(now = Time.current) do
          where(revoked_at: nil)
            .where(arel_table[:refresh_token_expires_at].eq(nil).or(arel_table[:refresh_token_expires_at].gt(now)))
        end

  private

  def creating_root_matches_device
    return if client_token_id.blank?

    root = ClientToken.find_by(id: client_token_id)
    return errors.add(:client_token_id, :invalid) unless root
    return if root.device_session_id == device_session_id

    errors.add(:device_session_id, :invalid)
  end

  def bind_device_session_from_parent_token
    return if device_session_id.present?

    token = ClientToken.find_by(id: client_token_id)
    self.device_session_id = token&.device_session_id
  end

  def parent_association_name
    :client_device_session
  end
end
