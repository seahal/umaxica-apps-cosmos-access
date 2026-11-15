# typed: false
# frozen_string_literal: true

require "test_helper"

class TokenStatusManagementTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  def setup
    @token = ClientToken.create!(
      authentication_epoch: 0,
      subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ),
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
    )
  end

  test "defines status constants" do
    assert_equal 1, TokenStatusManagement::STATUS_ACTIVE
    assert_equal 102, TokenStatusManagement::STATUS_EXPIRED
    assert_equal 103, TokenStatusManagement::STATUS_RESTRICTED
    assert_equal 104, TokenStatusManagement::STATUS_REVOKED
    assert_equal [1, 102, 103, 104], TokenStatusManagement::VALID_STATUSES
  end

  test "strict issuance context maps absent columns and NULL to Normal and rejects corrupt values" do
    operator_token = OperatorToken.create!(
      authentication_epoch: 0, subject_public_id: "refresh-operator",
      device_session: OperatorDeviceSession.create!(
        subject_public_id: "refresh-operator",
      ), authentication_context: nil,
    )

    assert_predicate @token.strict_authentication_context_value, :normal?
    assert_predicate operator_token.strict_authentication_context_value, :normal?

    operator_token.update!(authentication_context: AuthenticationContextValue::NORMAL_KEY)

    assert_predicate operator_token.strict_authentication_context_value, :normal?

    operator_token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)

    assert_predicate operator_token.strict_authentication_context_value, :standby?

    ["", "future-context"].each do |stored_value|
      corrupt_token = OperatorToken.new(
        subject_public_id: "refresh-operator",
        device_session: OperatorDeviceSession.create!(
          subject_public_id: "refresh-operator",
        ), authentication_context: stored_value,
      )

      assert_raises(AuthenticationContextValue::UnknownContextError) do
        corrupt_token.strict_authentication_context_value
      end
    end
  end

  test "active_status scope returns only active usable tokens" do
    @token.update!(user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now)
    restricted = ClientToken.create!(
      authentication_epoch: 0,
      subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), user_token_status_id: ClientTokenStatus::RESTRICTED, discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    )
    revoked = ClientToken.create!(
      authentication_epoch: 0, subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), discard_at: Time.current,
      purge_eligible_at: 1.day.from_now,
    )
    refresh_expired = ClientToken.create!(
      authentication_epoch: 0,
      subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.minute.ago,
      purge_eligible_at: 1.day.from_now,
    )
    rotated_source = ClientToken.create!(
      authentication_epoch: 0,
      subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    )
    rotated_refresh = rotated_source.rotate_refresh_token!
    AuthRefreshTokenIssuer.call(resource_type: "client", refresh_token: rotated_refresh)

    results = ClientToken.active_status

    assert_includes results, @token
    assert_not_includes results, restricted
    assert_not_includes results, revoked
    assert_not_includes results, refresh_expired
    assert_not_includes results, rotated_source.reload
  end

  test "restricted_status scope returns only restricted usable tokens" do
    active = ClientToken.create!(
      authentication_epoch: 0,
      subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now, purge_eligible_at: 2.days.from_now,
    )
    @token.update!(user_token_status_id: ClientTokenStatus::RESTRICTED, discard_at: 1.day.from_now)
    revoked = ClientToken.create!(
      authentication_epoch: 0,
      subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), user_token_status_id: ClientTokenStatus::RESTRICTED,
      discard_at: Time.current, purge_eligible_at: 1.day.from_now,
    )
    refresh_expired = ClientToken.create!(
      authentication_epoch: 0,
      subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), user_token_status_id: ClientTokenStatus::RESTRICTED, discard_at: 1.minute.ago,
      purge_eligible_at: 1.day.from_now,
    )

    results = ClientToken.restricted_status

    assert_includes results, @token
    assert_not_includes results, active
    assert_not_includes results, revoked
    assert_not_includes results, refresh_expired
  end

  test "not_revoked scope returns only usable tokens" do
    @token.update!(discard_at: 1.day.from_now)
    revoked = ClientToken.create!(
      authentication_epoch: 0, subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), discard_at: Time.current,
      purge_eligible_at: 1.day.from_now,
    )
    refresh_expired = ClientToken.create!(
      authentication_epoch: 0, subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), discard_at: 1.minute.ago,
      purge_eligible_at: 1.day.from_now,
    )
    rotated_source = ClientToken.create!(
      authentication_epoch: 0, subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    )
    rotated_refresh = rotated_source.rotate_refresh_token!
    AuthRefreshTokenIssuer.call(resource_type: "client", refresh_token: rotated_refresh)

    results = ClientToken.not_revoked

    assert_includes results, @token
    assert_not_includes results, revoked
    assert_not_includes results, refresh_expired
    assert_not_includes results, rotated_source.reload
  end

  test "future discard_at stays valid until due and past discard_at is excluded" do
    future_token = ClientToken.create!(
      authentication_epoch: 0, subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), discard_at: 10.minutes.from_now,
      purge_eligible_at: 1.day.from_now,
    )
    past_token = ClientToken.create!(
      authentication_epoch: 0, subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), discard_at: 10.minutes.ago,
      purge_eligible_at: 1.day.from_now,
    )

    results = ClientToken.not_revoked

    assert_includes results, future_token
    assert_not_includes results, past_token
    assert_not future_token.expired?
    assert_predicate past_token, :expired?
  end

  test "positive infinity is not a usable absolute session deadline" do
    @token.update!(discard_at: Float::INFINITY, purge_eligible_at: Float::INFINITY)

    assert_predicate @token.reload, :expired?
    assert_not_predicate @token, :currently_usable?
    assert_not ClientToken.currently_usable_at.exists?(id: @token.id)
  end

  test "instance expiry and the SQL scope use the same supplied evaluation time" do
    evaluation_time = Time.utc(2040, 1, 1, 12)
    token = ClientToken.create!(
      authentication_epoch: 0,
      subject_public_id: "refresh-principal", device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ),
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: evaluation_time - 1.minute,
      purge_eligible_at: evaluation_time + 1.day,
    )

    assert token.expired?(evaluation_time)
    assert_not ClientToken.currently_usable_at(evaluation_time).exists?(id: token.id)
  end

  test "restricted? returns true when status is restricted" do
    @token.update!(user_token_status_id: ClientTokenStatus::RESTRICTED)

    assert_predicate @token, :restricted?

    @token.update!(user_token_status_id: ClientTokenStatus::ACTIVE)

    assert_not_predicate @token, :restricted?
  end

  test "active_status? returns true only when active and currently usable" do
    @token.update!(
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      purge_eligible_at: 1.day.from_now,
    )

    assert_predicate @token, :active_status?

    @token.update!(user_token_status_id: ClientTokenStatus::RESTRICTED)

    assert_not_predicate @token, :active_status?

    @token.update!(
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: Time.current,
      purge_eligible_at: 1.day.from_now,
    )

    assert_not_predicate @token, :active_status?
  end

  test "revoked? returns true when status is revoked" do
    @token.update!(user_token_status_id: ClientTokenStatus::REVOKED)

    assert_predicate @token, :revoked?

    @token.update!(user_token_status_id: ClientTokenStatus::ACTIVE)

    assert_not_predicate @token, :revoked?
  end

  test "scheduled_revocation_due? tracks past discard_at" do
    token = ClientToken.new(
      subject_public_id: "refresh-principal",
      device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ), user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    token.define_singleton_method(:discard_at) { 1.minute.ago }

    assert_predicate token, :scheduled_revocation_due?
    assert_predicate token, :expired?
  end

  test "currently_usable? returns false for rotated and expired tokens" do
    @token.update!(
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      purge_eligible_at: 1.day.from_now,
    )

    assert_predicate @token, :currently_usable?

    @token.update!(rotated_at: Time.current)

    assert_not_predicate @token, :currently_usable?

    @token.update!(rotated_at: nil, discard_at: 1.minute.from_now)

    assert_predicate @token, :currently_usable?

    travel 2.minutes do
      assert_not_predicate @token.reload, :currently_usable?
    end
  end

  test "negative infinity or nil expiry cannot make a token usable" do
    @token.update_columns(
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: -Float::INFINITY,
      purge_eligible_at: 1.day.from_now,
    )

    assert_not_predicate @token.reload, :currently_usable?
    assert_not_predicate ClientToken.currently_usable_at(Time.current).where(id: @token.id), :exists?

    @token.define_singleton_method(:discard_at) { nil }

    assert_not_predicate @token, :currently_usable?
  end

  test "status transitions use one writer database time for the state and timestamp" do
    database_time = 1.hour.from_now

    @token.update!(user_token_status_id: ClientTokenStatus::RESTRICTED)
    ClientToken.stub(:database_now, database_time) do
      @token.revoke!
    end

    revoked = @token.reload

    assert_equal ClientTokenStatus::REVOKED, revoked.user_token_status_id
    assert_equal database_time.to_i, revoked.discard_at.to_i
    assert_equal database_time.to_i, revoked.updated_at.to_i
  end

  test "expiry_column returns discard_at when present" do
    assert_equal :discard_at, ClientToken.expiry_column
  end

  test "revoke! sets expiry and revoked status at the supplied instant" do
    freeze_time do
      revocation_time = Time.current
      @token.revoke!(now: revocation_time)

      assert_predicate @token.discard_at, :present?
      assert_equal revocation_time.to_i, @token.discard_at.to_i
      assert_equal ClientTokenStatus::REVOKED, @token.user_token_status_id
    end
  end

  test "revoke! restores missing revoked status reference" do
    ClientTokenStatus.find(ClientTokenStatus::REVOKED).destroy!

    @token.revoke!

    assert ClientTokenStatus.exists?(id: ClientTokenStatus::REVOKED)
    assert_equal ClientTokenStatus::REVOKED, @token.reload.user_token_status_id
  end

  test "default token status is active" do
    token = ClientToken.new(
      subject_public_id: "refresh-principal",
      device_session: ClientDeviceSession.create!(
        subject_public_id: "refresh-principal",
      ),
    )

    assert_equal ClientTokenStatus::ACTIVE, token.user_token_status_id
  end

  test "expiry_column raises when model has no expiry columns" do
    klass =
      Class.new do
        extend TokenStatusManagement::ClassMethods

        define_singleton_method(:column_names) do
          []
        end

        define_singleton_method(:name) do
          "NoExpiryToken"
        end
      end

    assert_raises(ArgumentError) { klass.expiry_column }
  end

  test "token_status_model raises for unknown token class" do
    klass =
      Class.new do
        extend TokenStatusManagement::ClassMethods

        define_singleton_method(:name) do
          "UnknownToken"
        end
      end

    assert_raises(ArgumentError) { klass.token_status_model }
  end

  test "works with OperatorToken as well" do
    token = OperatorToken.create!(
      authentication_epoch: 0, subject_public_id: "refresh-operator",
      device_session: OperatorDeviceSession.create!(
        subject_public_id: "refresh-operator",
      ),
    )

    assert_predicate token, :active_status?

    token.update!(staff_token_status_id: OperatorTokenStatus::RESTRICTED)

    assert_predicate token, :restricted?

    token.update!(staff_token_status_id: OperatorTokenStatus::ACTIVE)

    assert_predicate token, :active_status?

    token.revoke!

    assert_equal OperatorTokenStatus::REVOKED, token.reload.staff_token_status_id
  end
end
