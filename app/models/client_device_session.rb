# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_device_sessions
# Database name: op_base_app
#
#  id                         :bigint           not null, primary key
#  dbsc_bound_at              :datetime
#  dbsc_public_key_thumbprint :string
#  dbsc_session_id_digest     :string
#  dpop_jkt                   :string
#  last_network_hmac          :string
#  last_seen_at               :datetime
#  revoke_reason              :string
#  revoked_at                 :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  current_refresh_token_id   :bigint
#  public_id                  :string(21)       not null
#  refresh_token_family_id    :string
#  status_id                  :bigint           default(1), not null
#  subject_public_id          :string           not null
#
# Indexes
#
#  index_client_device_sessions_on_current_refresh_token_id  (current_refresh_token_id)
#  index_client_device_sessions_on_dbsc_session_id_digest    (dbsc_session_id_digest)
#  index_client_device_sessions_on_public_id                 (public_id) UNIQUE
#  index_client_device_sessions_on_refresh_token_family_id   (refresh_token_family_id)
#  index_client_device_sessions_on_revoked_at                (revoked_at)
#
class ClientDeviceSession < OpBaseAppRecord
  include DeviceSessionable

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update

  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  validates :public_id, uniqueness: true, length: { maximum: 21 }
  validates :status_id, presence: true

  scope :active, -> { where(revoked_at: nil, status_id: DeviceSessionable::STATUS_ACTIVE) }

  attr_readonly :subject_public_id

  # Nullable in the schema and legitimately blank for fallback (non-DBSC)
  # sessions and before the first refresh rotation. Marking it required made
  # `revoke!` (an `update!`) fail validation on such sessions, so sign-out could
  # not revoke them -- the session stayed usable. Revocation must always succeed.
  belongs_to :current_refresh_token, class_name: "ClientToken", optional: true
  has_many :client_tokens, foreign_key: :device_session_id,
                           dependent: :restrict_with_exception,
                           inverse_of: :device_session
  has_many :op_app_grants, foreign_key: :device_session_id,
                           dependent: :restrict_with_exception,
                           inverse_of: :client_device_session

  validates :subject_public_id, presence: true, length: { maximum: 255 }

  # Unique indexes that include the primary key back composite references; checked only for an explicit id.
  validates :id, uniqueness: { scope: %i(subject_public_id) }, allow_nil: true, if: :will_save_change_to_id?
end
