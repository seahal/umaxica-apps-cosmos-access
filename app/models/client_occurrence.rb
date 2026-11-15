# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_occurrences
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
#  index_client_occurrences_on_body                       (body) UNIQUE
#  index_client_occurrences_on_event_type_and_created_at  (event_type,created_at)
#  index_client_occurrences_on_public_id                  (public_id) UNIQUE
#  index_client_occurrences_on_purge_eligible_at                  (purge_eligible_at)
#  index_client_occurrences_on_status_id_and_created_at   (status_id,created_at)
#
# Foreign Keys
#
#  fk_user_occurrences_on_status_id  (status_id => client_occurrence_statuses.id)
#

class ClientOccurrence < OccurrenceRecord
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

  ACTIVE_STATUS_ID = 1
  EXPIRED_STATUS_ID = 2

  attribute :status_id, default: ClientOccurrenceStatus::NOTHING

  belongs_to :user_occurrence_status, class_name: "ClientOccurrenceStatus", foreign_key: :status_id,
                                      inverse_of: :client_occurrences
  has_many :area_user_occurrences, class_name: "AreaClientOccurrence", dependent: :destroy,
                                   inverse_of: :user_occurrence
  has_many :area_occurrences, through: :area_user_occurrences
  has_many :domain_user_occurrences, class_name: "DomainClientOccurrence", dependent: :destroy,
                                     inverse_of: :user_occurrence
  has_many :domain_occurrences, through: :domain_user_occurrences
  has_many :email_user_occurrences, class_name: "EmailClientOccurrence", dependent: :destroy,
                                    inverse_of: :user_occurrence
  has_many :email_occurrences, through: :email_user_occurrences
  has_many :ip_user_occurrences, class_name: "IpClientOccurrence", dependent: :destroy,
                                 inverse_of: :user_occurrence
  has_many :ip_occurrences, through: :ip_user_occurrences
  has_many :staff_user_occurrences, class_name: "OperatorClientOccurrence", dependent: :destroy,
                                    inverse_of: :user_occurrence
  has_many :staff_occurrences, through: :staff_user_occurrences
  has_many :telephone_user_occurrences, class_name: "TelephoneClientOccurrence", dependent: :destroy,
                                        inverse_of: :user_occurrence
  has_many :telephone_occurrences, through: :telephone_user_occurrences
  has_many :client_zip_occurrences, dependent: :destroy, inverse_of: :user_occurrence
  has_many :zip_occurrences, through: :client_zip_occurrences

  validates :body, length: { maximum: 36 }
  validates :status_id, numericality: { only_integer: true }
  validates :event_type, length: { maximum: 255 }, allow_nil: true

  scope :active, -> { where(status_id: ACTIVE_STATUS_ID) }
  scope :expired, -> { where(status_id: EXPIRED_STATUS_ID) }
end
