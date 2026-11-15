# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_oidc_connections
# Database name: op_base_app
#
#  id           :bigint           not null, primary key
#  last_used_at :datetime
#  revoked_at   :datetime
#  scope        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  client_id    :string(64)       not null
#  public_id    :string(21)       not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_client_oidc_connections_on_public_id              (public_id) UNIQUE
#  index_client_oidc_connections_on_user_id_and_client_id  (user_id,client_id) UNIQUE
#
class ClientOidcConnection < OpBaseAppRecord
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

  has_many :user_tokens,
           class_name: "ClientToken",
           foreign_key: :oidc_connection_id,
           dependent: :nullify,
           inverse_of: :oidc_connection

  validates :user_id, presence: true
  validates :client_id, uniqueness: { scope: :user_id }

  def self.actor_foreign_key = :user_id

  public

  def active_tokens
    user_tokens.session_inventory
  end
  public_class_method :actor_foreign_key
end
