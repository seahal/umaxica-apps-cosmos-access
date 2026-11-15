# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: email_occurrences
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
#  index_email_occurrences_on_body             (body) UNIQUE
#  index_email_occurrences_on_body_created_at  (body,created_at)
#  index_email_occurrences_on_public_id        (public_id) UNIQUE
#  index_email_occurrences_on_purge_eligible_at        (purge_eligible_at)
#  index_email_occurrences_on_status_id        (status_id)
#
# Foreign Keys
#
#  fk_email_occurrences_on_status_id  (status_id => email_occurrence_statuses.id)
#

class EmailOccurrence < OccurrenceRecord
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

  attribute :status_id, default: EmailOccurrenceStatus::NOTHING

  belongs_to :email_occurrence_status, foreign_key: :status_id, inverse_of: :email_occurrences
  has_many :area_email_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :area_occurrences, through: :area_email_occurrences
  has_many :domain_email_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :domain_occurrences, through: :domain_email_occurrences
  has_many :email_visitor_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :visitor_occurrences, through: :email_visitor_occurrences
  has_many :email_ip_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :ip_occurrences, through: :email_ip_occurrences
  has_many :email_staff_occurrences, class_name: "EmailOperatorOccurrence", dependent: :destroy,
                                     inverse_of: :email_occurrence
  has_many :staff_occurrences, through: :email_staff_occurrences
  has_many :email_telephone_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :telephone_occurrences, through: :email_telephone_occurrences
  has_many :email_user_occurrences, class_name: "EmailClientOccurrence", dependent: :destroy,
                                    inverse_of: :email_occurrence
  has_many :client_occurrences, through: :email_user_occurrences, source: :user_occurrence
  has_many :email_zip_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :zip_occurrences, through: :email_zip_occurrences

  validates :body, length: { maximum: 255 }
  validates :status_id, numericality: { only_integer: true }
end
