# typed: false
# frozen_string_literal: true

class OpOrgGrant < OpBaseOrgRecord
  include RpSession

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :bind_device_session_from_parent_token, on: :create
  before_validation :bind_subject_from_parent_token, on: :create
  before_validation :ensure_public_id, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update

  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true

  has_many :step_up_contexts, class_name: "OperatorStepUpContext", foreign_key: :grant_id,
                              inverse_of: :grant, dependent: :restrict_with_error
  has_many :step_up_commits, class_name: "OperatorStepUpCommit", foreign_key: :grant_id,
                             inverse_of: :grant, dependent: :restrict_with_error
  has_many :authority_stop_participants,
           class_name: "OpOrgAuthorityStopParticipant",
           foreign_key: :grant_id,
           inverse_of: :grant,
           dependent: :restrict_with_error
  has_many :authority_stop_grant_targets,
           class_name: "OpOrgAuthorityStopGrantTarget",
           foreign_key: :grant_id,
           inverse_of: :grant,
           dependent: :restrict_with_error

  has_one :logout_hint, class_name: "OpOrgGrantLogoutHint", foreign_key: :grant_id, inverse_of: :grant,
                        dependent: :destroy

  belongs_to :operator_device_session, class_name: "OperatorDeviceSession", foreign_key: :device_session_id,
                                       inverse_of: :op_org_grants
  # Historical issuance reference. The root may be physically purged while this grant remains;
  # the device session is the live authority and the root/device match is checked at creation.

  attr_readonly :operator_token_id, :device_session_id
  validates :operator_token_id, presence: true
  validates :subject_public_id, presence: true, length: { maximum: 255 }
  validate :creating_root_matches_device, on: :create

  validates :public_id, presence: true, uniqueness: true, length: { maximum: 21 }
  # WU-17: written at issuance from the actor (roots) or the root (grants); never defaulted.
  validates :authentication_epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :oidc_client_id, presence: true, length: { maximum: 64 }
  validates :device_session_id, uniqueness: { scope: :oidc_client_id, conditions: -> { where(revoked_at: nil) } },
                                if: -> { revoked_at.nil? }
  validates :last_logout_status, inclusion: { in: RpSession::LOGOUT_STATUSES }, allow_nil: true
  validates :refresh_token_digest, uniqueness: true, allow_nil: true

  scope :currently_usable_at,
        ->(now = Time.current) do
          where(revoked_at: nil)
            .where(arel_table[:refresh_token_expires_at].eq(nil).or(arel_table[:refresh_token_expires_at].gt(now)))
        end

  private

  def creating_root_matches_device
    return if operator_token_id.blank?

    root = OperatorToken.find_by(id: operator_token_id)
    return errors.add(:operator_token_id, :invalid) unless root
    return if root.device_session_id == device_session_id

    errors.add(:device_session_id, :invalid)
  end

  def bind_device_session_from_parent_token
    return if device_session_id.present?

    token = OperatorToken.find_by(id: operator_token_id)
    self.device_session_id = token&.device_session_id
  end

  # The grant's subject is its root's; the composite foreign key admits no other value.
  def bind_subject_from_parent_token
    self.subject_public_id = OperatorToken.find_by(id: operator_token_id)&.subject_public_id
  end

  def parent_association_name
    :operator_device_session
  end
end
