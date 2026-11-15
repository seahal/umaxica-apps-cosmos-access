# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: area_occurrences
# Database name: occurrence
#
#  id           :bigint           not null, primary key
#  body         :string           default(""), not null
#  discard_at :datetime         default(Infinity), not null
#  memo         :string           default(""), not null
#  purge_eligible_at    :datetime         default(Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string(21)       default(""), not null
#  status_id    :bigint           default(0), not null
#
# Indexes
#
#  index_area_occurrences_on_body       (body) UNIQUE
#  index_area_occurrences_on_public_id  (public_id) UNIQUE
#  index_area_occurrences_on_purge_eligible_at  (purge_eligible_at)
#  index_area_occurrences_on_status_id  (status_id)
#
# Foreign Keys
#
#  fk_area_occurrences_on_status_id  (status_id => area_occurrence_statuses.id)
#

class AreaOccurrence < OccurrenceRecord
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

  attribute :status_id, default: AreaOccurrenceStatus::NOTHING

  belongs_to :area_occurrence_status, foreign_key: :status_id, inverse_of: :area_occurrences
  has_many :area_domain_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :domain_occurrences, through: :area_domain_occurrences
  has_many :area_email_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :email_occurrences, through: :area_email_occurrences
  has_many :area_visitor_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :visitor_occurrences, through: :area_visitor_occurrences
  has_many :area_ip_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :ip_occurrences, through: :area_ip_occurrences
  has_many :area_staff_occurrences, class_name: "AreaOperatorOccurrence", dependent: :destroy,
                                    inverse_of: :area_occurrence
  has_many :staff_occurrences, through: :area_staff_occurrences
  has_many :area_telephone_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :telephone_occurrences, through: :area_telephone_occurrences
  has_many :area_user_occurrences, class_name: "AreaClientOccurrence", dependent: :destroy, inverse_of: :area_occurrence
  has_many :client_occurrences, through: :area_user_occurrences, source: :user_occurrence
  has_many :area_zip_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :zip_occurrences, through: :area_zip_occurrences

  validates :body, length: { maximum: 255 }
  validates :status_id, numericality: { only_integer: true }
end
