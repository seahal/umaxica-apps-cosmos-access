# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_oidc_connections
# Database name: op_base_org
#
#  id           :bigint           not null, primary key
#  last_used_at :datetime
#  revoked_at   :datetime
#  scope        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  client_id    :string(64)       not null
#  public_id    :string(21)       not null
#  staff_id     :bigint           not null
#
# Indexes
#
#  index_operator_oidc_connections_on_public_id               (public_id) UNIQUE
#  index_operator_oidc_connections_on_staff_id_and_client_id  (staff_id,client_id) UNIQUE
#
class OperatorOidcConnection < OpBaseOrgRecord
  include OidcConnectionRecord

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update

  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  validates :client_id, presence: true
  validates :client_id, length: { maximum: 64 }

  scope :recent_first, -> { order(Arel.sql("COALESCE(last_used_at, updated_at, created_at) DESC")) }
  scope :active, -> { where(revoked_at: nil) }

  has_many :staff_tokens,
           class_name: "OperatorToken",
           foreign_key: :oidc_connection_id,
           dependent: :nullify,
           inverse_of: :oidc_connection

  validates :staff_id, presence: true
  validates :client_id, uniqueness: { scope: :staff_id }

  def self.actor_foreign_key = :staff_id

  public

  def active_tokens
    staff_tokens.session_inventory
  end
  public_class_method :actor_foreign_key
end
