# frozen_string_literal: true

require "test_helper"

class PublicMethodContractsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class AdministrativeAccessRecord < OpBaseAppRecord
    self.table_name = ClientToken.table_name

    include AdministrativeAccessLockable

    attribute :access_state, :string, default: AdministrativeAccessLockable::ACCESS_STATE_ENABLED

    validates :access_state, presence: true, inclusion: { in: AdministrativeAccessLockable::ACCESS_STATES }
    validates :admin_locked_reason_code,
              inclusion: { in: AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES },
              allow_nil: true,
              if: :admin_locked_reason_code_column?
    validate :administrative_lock_columns_are_consistent

    attribute :admin_locked_at, :datetime
    attribute :admin_locked_by_operator_id, :integer
    attribute :admin_locked_reason_code, :string
    attribute :admin_locked_reason_note, :string
    attribute :token_valid_after_at, :datetime
  end

  class SecurityModeRecord
    include ActiveModel::Model
    include SecurityModeConfigurable

    attr_accessor :security_mode_id
  end

  class CoreRpBridgeRecord < OpBaseAppRecord
    self.table_name = ClientToken.table_name

    attribute :rp_client_id, :string
    attribute :audience, :string
    attribute :host, :string
    attribute :client_id, :integer
    attribute :public_id, :string
    attr_accessor :client

    include CoreRpBridge

    before_create :generate_public_id
    before_validation :generate_public_id, on: :create
    before_validation :refresh_generated_public_id_after_collision, on: :create
    around_create :retry_public_id_collision
    validate :public_id_immutable_after_create, on: :update

    validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    class_attribute :core_actor_association_name, instance_accessor: false
    class_attribute :core_actor_foreign_key, instance_accessor: false
    class_attribute :core_default_client_id, instance_accessor: false
    class_attribute :core_default_audience, instance_accessor: false
    class_attribute :core_default_host, instance_accessor: false
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    before_validation :assign_core_rp_defaults

    validates :rp_client_id, presence: true, length: { maximum: 64 }
    validates :audience, presence: true, length: { maximum: 128 }
    validates :host, presence: true, length: { maximum: 255 }

    core_rp_bridge(
      actor_association_name: :client,
      actor_foreign_key: :client_id,
      client_id: "core-app-client",
      audience: "core-app-audience",
      host: "core-app.example",
    )
  end

  class OrganizationRecord < OpBaseAppRecord
    self.table_name = ClientToken.table_name

    attribute :name, :string
    attribute :title, :string

    include Organization

    organization_interface_validations
  end

  class SignUpTicketWithoutCleanupStatus < OpBaseAppRecord
    self.table_name = ClientSignUpFlow.table_name

    include SignUpFlowTicket
  end

  class OtpPolicyRecord
    attr_accessor :locked_at, :otp_attempts_count, :otp_last_sent_at
    attr_reader :lock_calls, :saved_validation_option

    def initialize(locked_at: nil, otp_attempts_count: nil, otp_last_sent_at: nil)
      @locked_at = locked_at
      @otp_attempts_count = otp_attempts_count
      @otp_last_sent_at = otp_last_sent_at
    end

    def self.database_now = Time.zone.local(2026, 11, 13, 12, 0, 0)

    def with_lock
      @lock_calls = lock_calls.to_i + 1
      yield
    end

    def save!(validate: true)
      @saved_validation_option = validate
      true
    end

    def reload = self
  end

  class EmailOtpPolicyRecord < OtpPolicyRecord
    include EmailOtpPolicy
  end

  class TelephoneOtpPolicyRecord < OtpPolicyRecord
    include TelephoneOtpPolicy
  end

  test "administrative access predicates and token cutoff preserve the configured lock boundary" do
    now = Time.zone.local(2026, 11, 13, 12, 0, 0)
    record = AdministrativeAccessRecord.new

    assert_predicate record, :access_enabled?
    assert_not_predicate record, :admin_locked?
    assert_not_predicate record, :access_locked?

    record.access_state = AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED

    assert_predicate record, :admin_locked?
    assert_predicate record, :access_locked?

    record.token_valid_after_at = now

    assert record.access_token_stale_for_administrative_lock?("iat" => now.to_i - 1)
    assert_not record.access_token_stale_for_administrative_lock?("iat" => now.to_i)
    assert record.access_token_stale_for_administrative_lock?({})

    record.token_valid_after_at = nil

    assert_not record.access_token_stale_for_administrative_lock?("iat" => now.to_i - 1)
  end

  test "security mode accepts only the two declared authentication modes" do
    record = SecurityModeRecord.new(security_mode_id: SecurityModeConfigurable::NORMAL)

    assert_predicate record, :security_mode_valid?
    assert_predicate record, :security_mode_normal?
    assert_not_predicate record, :security_mode_advanced?

    record.security_mode_id = SecurityModeConfigurable::ADVANCED

    assert_predicate record, :security_mode_valid?
    assert_predicate record, :security_mode_advanced?
    assert_not_predicate record, :security_mode_normal?

    record.security_mode_id = nil

    assert_not_predicate record, :security_mode_valid?
  end

  test "core RP bridge binds its configured client, audience, host, and actor subject" do
    actor = Struct.new(:public_id).new("client-public-reference")
    record = CoreRpBridgeRecord.new(
      rp_client_id: "core-app-client", audience: "core-app-audience", host: "core-app.example",
      client_id: 17, public_id: "bridge-public-reference",
    )
    record.client = actor

    assert_same actor, record.actor
    assert_equal "client-public-reference", record.subject
    assert_predicate record, :core?

    record.audience = "other-audience"

    assert_not_predicate record, :core?
  end

  test "organization interface validations apply only to present attributes" do
    invalid = OrganizationRecord.new

    assert_not invalid.valid?
    assert_includes invalid.errors.attribute_names, :name
    assert_includes invalid.errors.attribute_names, :title

    valid = OrganizationRecord.new(name: "Example", title: "Org01")

    assert_predicate valid, :valid?
  end

  test "sign up cleanup status lookup fails when a ticket has no owning status table" do
    assert_nil SignUpTicketWithoutCleanupStatus.cleanup_status_class
    error =
      assert_raises(NotImplementedError) do
        SignUpTicketWithoutCleanupStatus.cleanup_status_id_for(:idle)
      end
    assert_includes error.message, "must declare cleanup_status_class"
  end

  [EmailOtpPolicyRecord, TelephoneOtpPolicyRecord].each do |model|
    test "#{model.name} exposes the same lockout and re-registration boundaries" do
      now = model.database_now
      record = model.new(
        locked_at: now + 1.minute,
        otp_last_sent_at: now - 1.second,
        otp_attempts_count: model::MAX_OTP_ATTEMPTS - 1,
      )

      assert_predicate record, :locked?
      assert_predicate record, :lockout_active?
      assert_equal now + 1.minute, record.lockout_expires_at
      assert_predicate record, :reregistration_window_active?

      record.locked_at = now - 1.second

      assert_not_predicate record, :lockout_active?
      record.otp_last_sent_at = now - model::REREGISTRATION_OVERWRITE_WINDOW

      assert_not_predicate record, :reregistration_window_active?

      record.locked_at = nil
      record.otp_last_sent_at = now - model::OTP_ATTEMPT_WINDOW + 1.second
      record.otp_attempts_count = model::MAX_OTP_ATTEMPTS

      assert_predicate record, :locked?

      record.otp_attempts_count = model::MAX_OTP_ATTEMPTS - 1
      record.otp_last_sent_at = now
      record.increment_attempts!

      assert_equal model::MAX_OTP_ATTEMPTS, record.otp_attempts_count
      assert_equal now + model::OTP_LOCKOUT_DURATION, record.locked_at
      assert_equal 1, record.lock_calls
      assert_not record.saved_validation_option
    end
  end
end
