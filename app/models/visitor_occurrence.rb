# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_occurrences
# Database name: occurrence
#
#  id           :bigint           not null, primary key
#  body         :string           default(""), not null
#  context      :jsonb            not null
#  discard_at :datetime         default(Infinity), not null
#  event_type   :string           default(""), not null
#  memo         :string           default(""), not null
#  purge_eligible_at    :datetime         default(Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string(21)       default(""), not null
#  status_id    :bigint           default(0), not null
#
# Indexes
#
#  index_visitor_occurrences_on_body                       (body) UNIQUE
#  index_visitor_occurrences_on_event_type_and_created_at  (event_type,created_at)
#  index_visitor_occurrences_on_public_id                  (public_id) UNIQUE
#  index_visitor_occurrences_on_purge_eligible_at                  (purge_eligible_at)
#  index_visitor_occurrences_on_status_id_and_created_at   (status_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => visitor_occurrence_statuses.id)
#
class VisitorOccurrence < OccurrenceRecord
  include Retainable

  attribute :discard_at, :datetime, default: -> { Retainable::SENTINEL }
  attribute :purge_eligible_at, :datetime, default: -> { Retainable::SENTINEL }

  validates :discard_at, presence: true
  validates :purge_eligible_at, presence: true
  validate :retention_order_valid
  validate :retention_times_not_before_created_at, on: :update

  Retainable.registry << self unless Retainable.registry.include?(self)
  include PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update

  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  include Occurrence

  validates :public_id,
            length: { is: 21 },
            format: { with: /\A[A-Za-z0-9_-]{21}\z/ },
            uniqueness: true
  validates :body, presence: true, uniqueness: true
  validates :memo, length: { maximum: 1024 }, allow_nil: true

  ACTIVE_STATUS_ID = VisitorOccurrenceStatus::ACTIVE
  INACTIVE_STATUS_ID = VisitorOccurrenceStatus::INACTIVE

  attribute :status_id, default: VisitorOccurrenceStatus::NOTHING

  belongs_to :visitor_occurrence_status, foreign_key: :status_id,
                                         inverse_of: :visitor_occurrences
  has_many :area_visitor_occurrences, dependent: :destroy, inverse_of: :visitor_occurrence
  has_many :area_occurrences, through: :area_visitor_occurrences
  has_many :email_visitor_occurrences, dependent: :destroy, inverse_of: :visitor_occurrence
  has_many :email_occurrences, through: :email_visitor_occurrences
  has_many :ip_visitor_occurrences, dependent: :destroy, inverse_of: :visitor_occurrence
  has_many :ip_occurrences, through: :ip_visitor_occurrences

  validates :body, length: { maximum: 36 }
  validates :status_id, numericality: { only_integer: true }
  validates :event_type, length: { maximum: 255 }, allow_nil: true

  scope :active, -> { where(status_id: ACTIVE_STATUS_ID) }
  scope :inactive, -> { where(status_id: INACTIVE_STATUS_ID) }
end
