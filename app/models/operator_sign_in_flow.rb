# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_sign_in_flows
# Database name: op_base_org
#
#  id                    :bigint           not null, primary key
#  completed_at          :datetime
#  discard_at          :datetime         default(Infinity), not null
#  expires_at            :datetime         not null
#  issued_at             :datetime         not null
#  nonce_digest          :string           not null
#  purge_eligible_at             :datetime         default(Infinity), not null
#  return_to             :text
#  selector_completed_at :datetime
#  session_issued_at     :datetime
#  state_id              :bigint           default(10), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  principal_id          :bigint
#  public_id             :string(21)       not null
#  selected_persona_id   :bigint
#  selected_region_id    :bigint
#  token_id              :bigint
#
# Indexes
#
#  index_operator_sign_in_flows_on_discard_at         (discard_at)
#  index_operator_sign_in_flows_on_expires_at           (expires_at)
#  index_operator_sign_in_flows_on_principal_id         (principal_id)
#  index_operator_sign_in_flows_on_public_id            (public_id) UNIQUE
#  index_operator_sign_in_flows_on_selected_persona_id  (selected_persona_id)
#  index_operator_sign_in_flows_on_selected_region_id   (selected_region_id)
#  index_operator_sign_in_flows_on_state_id             (state_id)
#  index_operator_sign_in_flows_on_token_id             (token_id)
#
# Foreign Keys
#
#  fk_rails_...  (state_id => operator_sign_in_flow_states.id)
#  fk_rails_...  (token_id => operator_tokens.id) ON DELETE => cascade
#
class OperatorSignInFlow < OpBaseOrgRecord
  include SignInFlow

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_validation :assign_default_state_id
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update

  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
  attribute :discard_at, :datetime, default: -> { Retainable::SENTINEL }
  attribute :purge_eligible_at, :datetime, default: -> { Retainable::SENTINEL }

  validates :discard_at, presence: true
  validates :purge_eligible_at, presence: true
  validate :retention_order_valid
  validate :retention_times_not_before_created_at, on: :update

  Retainable.registry << self unless Retainable.registry.include?(self)
  attribute :issued_at, :datetime, default: -> { Time.current }
  attribute :expires_at, :datetime, default: -> { default_ttl.from_now }

  validates :nonce_digest, presence: true
  validates :issued_at, :expires_at, presence: true
  validate :expires_after_issued_at

  scope :recent_first, -> { order(created_at: :desc) }
  scope :current,
        -> do
          where(arel_table[:discard_at].gt(Time.current))
            .where(arel_table[:expires_at].gt(Time.current))
        end
  include FlowSignIn

  cycle_status_column :state_id

  STATE_MODEL = OperatorSignInFlowState
  STATES = {
    "PRIMARY_PENDING" => STATE_MODEL::PRIMARY_PENDING,
    "MFA_PENDING" => STATE_MODEL::MFA_PENDING,
    "GUARDRAIL_PENDING" => STATE_MODEL::GUARDRAIL_PENDING,
    "SESSION_ISSUANCE_PENDING" => STATE_MODEL::SESSION_ISSUANCE_PENDING,
    "CHECKPOINT_PENDING" => STATE_MODEL::CHECKPOINT_PENDING,
    "SELECTOR_PENDING" => STATE_MODEL::SELECTOR_PENDING,
    "COMPLETED" => STATE_MODEL::COMPLETED,
    "FAILED" => STATE_MODEL::FAILED,
    "EXPIRED" => STATE_MODEL::EXPIRED,
    "CANCELLED" => STATE_MODEL::CANCELLED,
    "HALTED" => STATE_MODEL::HALTED,
  }.freeze
  HISTORICAL_STATES = {
    "SESSION_LIMIT_PENDING" => STATE_MODEL::SESSION_LIMIT_PENDING,
    "DASHBOARD_PENDING" => STATE_MODEL::DASHBOARD_PENDING,
    "RETURN_PENDING" => STATE_MODEL::RETURN_PENDING,
  }.freeze
  STATE_NAMES = STATES.merge(HISTORICAL_STATES).invert.freeze
  STATE_IDS = (STATES.values + HISTORICAL_STATES.values).freeze
  TRANSITIONS = {
    STATE_MODEL::PRIMARY_PENDING => [
      STATE_MODEL::MFA_PENDING,
      STATE_MODEL::GUARDRAIL_PENDING,
      STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED,
    ],
    STATE_MODEL::MFA_PENDING => [
      STATE_MODEL::GUARDRAIL_PENDING,
      STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED,
    ],
    STATE_MODEL::GUARDRAIL_PENDING => [STATE_MODEL::CHECKPOINT_PENDING, STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED],
    STATE_MODEL::CHECKPOINT_PENDING => [STATE_MODEL::SELECTOR_PENDING, STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED],
    STATE_MODEL::SELECTOR_PENDING => [STATE_MODEL::SESSION_ISSUANCE_PENDING, STATE_MODEL::EXPIRED,
                                      STATE_MODEL::CANCELLED, STATE_MODEL::HALTED,],
    STATE_MODEL::SESSION_ISSUANCE_PENDING => [STATE_MODEL::COMPLETED, STATE_MODEL::EXPIRED, STATE_MODEL::CANCELLED, STATE_MODEL::HALTED],
    STATE_MODEL::COMPLETED => [],
    STATE_MODEL::FAILED => [],
    STATE_MODEL::EXPIRED => [],
    STATE_MODEL::CANCELLED => [],
    STATE_MODEL::HALTED => [],
  }.freeze

  # A sign-in flow exists before its root token is issued and is deleted with that token afterward.
  belongs_to :token, class_name: "OperatorToken", optional: true
  belongs_to :state, class_name: "OperatorSignInFlowState"
  has_many :session_limit_resolution_transactions,
           class_name: "OperatorSessionLimitResolutionTransaction",
           foreign_key: :sign_in_flow_id,
           inverse_of: :sign_in_flow,
           dependent: :restrict_with_error

  validates :state_id, inclusion: { in: ->(record) { record.class::STATE_IDS } }
  validates :token_id, uniqueness: true, allow_nil: true, if: :will_save_change_to_token_id?
  validate :completed_state_has_completed_at
  validates :result_digest, length: { maximum: 64 }
  validates :result_digest, uniqueness: true, allow_nil: true

  public

  def record_authentication_evidence!(method:, authenticated_at: nil,
                                      authentication_context: AuthenticationContextValue::NORMAL_KEY)
    raise GovernanceLookupUnavailableError, "Governance authentication evidence verification is unavailable"
  end

  private

  def transition_sign_in_to!(next_status_name, changes: {}, timestamp_fields: [])
    unless %w(EXPIRED CANCELLED HALTED).include?(next_status_name)
      raise GovernanceLookupUnavailableError, "Governance sign-in authority is unavailable"
    end

    super
  end
end
