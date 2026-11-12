# typed: false
# frozen_string_literal: true

require "test_helper"

class ModelOnlyLineCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens client_device_sessions)

  test "actor configuration null values and dynamic access preserve value semantics" do
    null_value = Actor::Configuration::NULL_VALUE
    configuration = Actor::Configuration.new(feature: "enabled")
    same = Actor::Configuration.new(feature: "enabled")

    assert_withheld { null_value.nil? }
    assert_equal null_value, Actor::Configuration::NullValue.new
    assert_respond_to null_value, :anything
    assert_same null_value, null_value.anything.deeply.missing
    assert_equal "enabled", configuration[:feature]
    assert_equal "enabled", configuration.feature
    assert_respond_to configuration, :feature
    assert_equal configuration, same
    assert_equal configuration.hash, same.hash
  end

  test "actor preferences decode the realm snapshot and cookie input forms" do
    preference = Actor::Preference.from_jwt(
      {
        "language" => "en",
        "region" => "us",
        "timezone" => "Etc/UTC",
        "theme" => "dark",
        "currency" => "usd",
        "date_format" => "us",
        "time_format" => "12",
        "motion" => "reduced",
        "density" => "compact",
        "page_size" => "infinity",
      },
    )
    same = Actor::Preference.from_jwt(
      {
        "language" => "en",
        "region" => "us",
        "timezone" => "Etc/UTC",
        "theme" => "dark",
        "currency" => "usd",
        "date_format" => "us",
        "time_format" => "12",
        "motion" => "reduced",
        "density" => "compact",
        "page_size" => "infinity",
      },
    )

    assert_equal "en", preference.language
    assert_equal "us", preference.region
    assert_equal "dr", preference.theme
    assert_equal preference, same
    assert_equal preference.hash, same.hash

    cookie = Actor::Preference::Cookie.new(
      consented: true, functional: true, performant: false, targetable: false,
      consent_version: 1, consented_at: Time.zone.parse("2026-07-18 08:00:00"),
    )

    assert_same cookie, Actor::Preference.cookie_from(cookie)

    from_hash = preference.with_cookie(
      consented: true,
      functional: true,
      performant: false,
      targetable: false,
      consent_version: 1,
      consented_at: Time.zone.parse("2026-07-18 08:00:00"),
    )

    assert_predicate from_hash.cookie, :consented?
    assert_predicate from_hash.cookie, :functional?
  end

  test "retainable discard now validates duration and clamps to persisted creation" do
    record = AppPreferenceChronicle.new(created_at: 1.minute.from_now)

    assert_raises(ArgumentError) { record.discard_now!(purge_after: 10) }

    updates = []
    record.stub(:update!, ->(attributes) { updates << attributes }) do
      now = Time.current
      record.discard_now!(purge_after: 1.day, now: now)
    end

    assert_equal record.created_at, updates.last[:discard_at]
    assert_operator updates.last[:purge_eligible_at], :>, updates.last[:discard_at]
  end

  test "session limit resolution fails closed until Governance lookup exists" do
    assert_raises(GovernanceLookupUnavailableError) do
      ClientSessionLimitResolutionTransaction.issue!(
        sign_in_flow: Object.new,
        actor: Object.new,
        browser_binding_digest: "browser-binding-digest",
      )
    end
  end

  test "oidc token usage scope and rotation update the refresh token family" do
    assert_kind_of ActiveRecord::Relation, OpAppGrant.currently_usable_at(Time.current)
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    usage = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token_id: root.id, oidc_client_id: "base-app-ww", oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: OpAppGrant.database_now,
      refresh_token_expires_at: OpAppGrant.database_now + 10.minutes,
    )
    previous = usage.issue_refresh_token!
    digest = usage.refresh_token_digest
    generation = usage.refresh_generation
    root_generation = root.reload.refresh_token_generation
    rotated = usage.rotate_refresh_token!(expires_at: OpAppGrant.database_now + 10.minutes)

    assert_not_equal previous, rotated
    assert_equal digest, usage.reload.previous_refresh_token_digest
    assert_not_equal digest, usage.refresh_token_digest
    assert_equal generation + 1, usage.refresh_generation
    assert_equal root_generation, root.reload.refresh_token_generation
  end

  test "dbsc model mappings and downgrade use auth token reference classes" do
    assert_equal ClientTokenBindingMethod, ClientToken.dbsc_binding_method_classes.fetch("ClientToken")
    assert_equal ClientTokenDbscStatus, ClientToken.dbsc_status_classes.fetch("ClientToken")
  end

  test "sign in flow recognizes historical state but refuses transition without Governance" do
    flow = ClientSignInFlow.new(state_id: ClientSignInFlowState::PRIMARY_PENDING)

    assert_predicate flow, :sign_in_primary_pending?
    assert_not_respond_to flow, :sign_in_dashboard_pending?
    assert_not_respond_to flow, :sign_in_return_pending?
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      state_id: ClientSignInFlowState::CHECKPOINT_PENDING, issued_at: now, expires_at: now + 5.minutes,
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
    )
    assert_raises(GovernanceLookupUnavailableError) { flow.advance_sign_in_to_selector! }

    assert_equal ClientSignInFlowState::CHECKPOINT_PENDING, flow.reload.state_id
  end

  test "step up purge scope and connection owners cover every store" do
    now = Time.zone.parse("2026-07-18 08:00:00")

    assert_kind_of ActiveRecord::Relation, ClientStepUpCeremonyTransaction.purgeable_at(now)
    assert_equal OpBaseOrgRecord, OperatorStepUpCeremonyTransaction.connection_owner
  end

  test "preference chronicle event defaults remain in the Chronicle audit store" do
    [AppPreferenceChronicleEvent, ComPreferenceChronicleEvent, OrgPreferenceChronicleEvent].each do |event_class|
      event_class.ensure_defaults!

      assert_equal event_class::DEFAULTS.sort, event_class.where(id: event_class::DEFAULTS).pluck(:id).sort
    end
  end

  test "identity social ceremony candidate validation covers valid and invalid shapes" do
    valid = IdentitySocialCeremonyCandidate.new(
      auth_hash: {
        "principal" => {
          "provider" => "google",
          "subject" => "uid",
          "issuer" => "https://accounts.google.com",
          "audience" => "client-id",
          "verified_at" => Time.current.iso8601,
          "verification_authority" => "google",
        },
      },
    )
    valid.valid?

    assert_empty valid.errors.details[:auth_hash]

    invalid = IdentitySocialCeremonyCandidate.new(auth_hash: {})

    assert_not invalid.valid?
    assert_includes invalid.errors.details[:auth_hash], { error: "is invalid" }
  end

  test "signup social-entry predicates use their configured entry state" do
    flow = ClientSignUpFlow.new(entry_method: "google")

    assert_includes ClientSignUpFlow.social_entry_methods, "google"
    assert_predicate flow, :social_entry_method?
  end

  test "client sign in flow current scope remains queryable" do
    assert_kind_of ActiveRecord::Relation, ClientSignInFlow.current
  end

  test "step up transaction exposes scopes claims and valid state transitions" do
    now = ClientStepUpCeremonyTransaction.database_now
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "actor-model-coverage",
      session_ref: "session-model-coverage",
      required_scope: "settings_email",
      required_aal: "none",
      allowed_methods: %w(totp totp passkey),
      resource_ref: "resource-model-coverage",
      return_to: "/settings/email",
      transaction_id: "model-coverage-step-up",
      grant_jti: "model-coverage-grant",
      now: now,
    )

    assert_equal %w(totp passkey), transaction.allowed_methods_array
    assert_equal "model-coverage-step-up", transaction.grant_claims(now: now)["transaction_id"]
    assert_not transaction.expired?(now: now)
    assert_includes ClientStepUpCeremonyTransaction.active_at(now), transaction
    assert_includes ClientStepUpCeremonyTransaction.pending, transaction
    assert_equal transaction,
                 ClientStepUpCeremonyTransaction.latest_pending_for(
                   actor_ref: transaction.actor_ref,
                   session_ref: transaction.session_ref,
                   required_scope: transaction.required_scope,
                   now: now,
                 )

    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: now, verified_credential_ref: SecureRandom.uuid,
    )
    transaction.with_lock { transaction.commit_consumption!(now: ClientStepUpCeremonyTransaction.database_now) }

    assert_predicate transaction.reload, :consumed?
    assert_includes ClientStepUpCeremonyTransaction.consumed, transaction
  end

  test "step up cancellation scopes and validations reject invalid state" do
    now = Time.zone.parse("2026-07-18 08:00:00")
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "actor-model-cancel",
      session_ref: "session-model-cancel",
      required_scope: "settings_email",
      required_aal: "none",
      allowed_methods: %w(totp),
      transaction_id: "model-coverage-cancel",
      grant_jti: "model-coverage-cancel-grant",
      expires_at: now + 1.minute,
      now: now,
    )

    transaction.commit_cancellation!(now: now)

    assert_predicate transaction.reload, :canceled?
    assert_includes ClientStepUpCeremonyTransaction.canceled, transaction

    invalid = ClientStepUpCeremonyTransaction.new(
      surface: "com",
      status: "consumed",
      allowed_methods: "invalid",
      expires_at: now,
    )

    assert_not invalid.valid?
    assert_includes invalid.errors.details[:surface], { error: "does not match transaction store" }
    assert_includes invalid.errors.details[:allowed_methods], { error: "contains invalid methods" }
    assert_includes invalid.errors.details[:result_jti], { error: "is required for consumed transaction" }
    assert_includes invalid.errors.details[:method], { error: "is required for consumed transaction" }
    assert_includes invalid.errors.details[:aal], { error: "is required for consumed transaction" }
    assert_includes invalid.errors.details[:verified_at], { error: "is required for consumed transaction" }
  end

  test "identity ceremony candidates reject missing consumed and expired records then consume active records" do
    now = Time.zone.parse("2026-07-18 08:00:00")
    error_class = Class.new(StandardError)
    consumed = Struct.new(:consumed_at, :expires_at).new(now, now + 1.minute)
    expired = Struct.new(:consumed_at, :expires_at).new(nil, now - 1.minute)
    active = Struct.new(:consumed_at, :expires_at).new(nil, now + 1.minute)

    IdentitySocialCeremonyCandidate.stub(:find_by, nil) do
      assert_raises(error_class) do
        IdentitySocialCeremonyCandidate.find_active_by_ref!(
          "missing", now: now, error_class: error_class,
                     not_found_message: "missing", expired_message: "expired",
        )
      end
    end
    IdentitySocialCeremonyCandidate.stub(:find_by, consumed) do
      assert_raises(error_class) do
        IdentitySocialCeremonyCandidate.find_active_by_ref!(
          "consumed", now: now, error_class: error_class,
                      not_found_message: "missing", expired_message: "expired",
        )
      end
    end
    IdentitySocialCeremonyCandidate.stub(:find_by, expired) do
      assert_raises(error_class) do
        IdentitySocialCeremonyCandidate.find_active_by_ref!(
          "expired", now: now, error_class: error_class,
                     not_found_message: "missing", expired_message: "expired",
        )
      end
    end
    IdentitySocialCeremonyCandidate.stub(:find_by, active) do
      assert_same active,
                  IdentitySocialCeremonyCandidate.find_active_by_ref!(
                    "active", now: now, error_class: error_class,
                              not_found_message: "missing", expired_message: "expired",
                  )
    end

    locked = Struct.new(:consumed_at, :expires_at) do
      attr_reader :updates

      def update!(attributes)
        @updates = attributes
        self
      end
    end.new(nil, now + 1.minute)
    lock_relation = Object.new
    lock_relation.define_singleton_method(:find_by) { |ref:| (ref == "candidate") ? locked : nil }
    candidate = IdentitySocialCeremonyCandidate.new(ref: "candidate")

    IdentitySocialCeremonyCandidate.stub(:lock, lock_relation) do
      assert_same locked,
                  candidate.consume!(
                    now: now, error_class: error_class,
                    not_found_message: "missing", expired_message: "expired",
                  )
    end
    assert_equal({ consumed_at: now }, locked.updates)
  end
end
