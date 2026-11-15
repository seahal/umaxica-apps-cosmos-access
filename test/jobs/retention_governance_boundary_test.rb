# frozen_string_literal: true

require "test_helper"

class RetentionGovernanceBoundaryTest < ActiveJob::TestCase
  self.fixture_table_names = []

  teardown { Flipper.disable(RetentionPurgeJob::FEATURE_NAME) }

  test "unavailable APP retention authority preserves roots while independent occurrences keep exact time boundaries" do
    [ClientTokenStatus, ClientTokenKind, ClientTokenBindingMethod, ClientTokenDbscStatus].each(&:ensure_defaults!)
    VisitorOccurrenceStatus.ensure_defaults!
    device = ClientDeviceSession.insert_all!(
      [{ user_id: 987_654_321, public_id: "a" * 21, principal_public_id: "retention-test-principal" }],
      returning: %w(id),
    ).rows.first.first
    now = ClientToken.database_now
    ids = ClientToken.insert_all!(
      [-1, 0, 1].each_with_index.map do |offset, index|
        { user_id: 987_654_321,
          device_session_id: device,
          public_id: ("b" * 20) + index.to_s,
          authentication_epoch: 0,
          created_at: now - 1.day,
          updated_at: now - 1.day,
          discard_at: now - 1.hour,
          purge_eligible_at: now + Rational(offset, 1_000_000), }
      end,
      returning: %w(id),
    ).rows.flatten
    snapshot = ClientToken.where(id: ids).order(:id).map(&:attributes)
    occurrence_now = VisitorOccurrence.database_now
    occurrence_ids = VisitorOccurrence.insert_all!(
      [-1, 0, 1].each_with_index.map do |offset, index|
        { body: "retention-boundary-#{index}",
          public_id: ("c" * 20) + index.to_s,
          status_id: VisitorOccurrenceStatus::NOTHING,
          context: {},
          discard_at: occurrence_now - 1.hour,
          purge_eligible_at: occurrence_now + Rational(offset, 1_000_000), }
      end,
      returning: %w(id),
    ).rows.flatten
    stop_calls = []
    reported = []
    ClientToken.stub(:database_now, now) do
      VisitorOccurrence.stub(:database_now, occurrence_now) do
        OpAuthorityStopPurger.stub(
          :release_roots!, ->(**arguments) {
                             stop_calls << arguments
                             []
                           },
        ) do
          Rails.error.stub(:report, ->(error, **context) { reported << [error, context] }) do
            error = assert_raises(StandardError) { RetentionPurgeJob.perform_now(batch_size: 1) }
            assert_equal "RetentionPurgeJob::AuthorityUnavailableError", error.class.name
          end
        end
      end
    end

    assert_equal snapshot, ClientToken.where(id: ids).order(:id).map(&:attributes)
    assert_empty stop_calls
    assert_not VisitorOccurrence.exists?(occurrence_ids[0])
    assert_not VisitorOccurrence.exists?(occurrence_ids[1])
    assert VisitorOccurrence.exists?(occurrence_ids[2])
    assert reported.any? { |error, _context| error.class.name == "RetentionPurgeJob::AuthorityUnavailableError" }
  end

  test "local unfinished sign-up retention and unavailable source authority preserve both flow kinds" do
    [ClientOidcAuthorizationTransactionStatus, ClientAuthAdmissionBindingStatus,
     ClientSignUpFlowStatus, ClientSignUpFlowCleanupStatus,].each(&:ensure_defaults!)
    now = ClientSignUpFlow.database_now
    cases = [
      [ClientSignUpFlowStatus::STARTED, ClientSignUpFlowCleanupStatus::IDLE, "start", false],
      [ClientSignUpFlowStatus::CANCELLED, ClientSignUpFlowCleanupStatus::PENDING, "cancelled", false],
      [ClientSignUpFlowStatus::CANCELLED, ClientSignUpFlowCleanupStatus::COMPLETED, "cancelled", true],
      [ClientSignUpFlowStatus::COMPLETED, ClientSignUpFlowCleanupStatus::IDLE, "completed", true],
    ]
    parents = ClientOidcAuthorizationTransaction.insert_all!(
      cases.each_index.map do |index|
        { transaction_id: "retention-transaction-#{index}",
          surface: "app",
          intent: "sign_up",
          client_id: "retention-test-client",
          redirect_uri: "https://example.com/callback",
          response_type: "code",
          scope: "openid",
          state: "retention-state",
          nonce: "retention-nonce",
          login_challenge: "retention-login-#{index}",
          login_challenge_expires_at: now + 1.hour,
          expires_at: now + 1.hour,
          status_id: ClientOidcAuthorizationTransactionStatus::PENDING, }
      end,
      returning: %w(id),
    ).rows.flatten
    bindings = ClientAuthAdmissionBinding.insert_all!(
      parents.each_with_index.map do |parent, index|
        { entry_ref: "00000000-0000-4000-8000-00000000000#{index}",
          purpose: "authentication_handoff",
          authorization_transaction_id: parent,
          base_browser_digest: "e" * 64,
          entry_intent: "sign_up",
          expires_at: now + 1.hour,
          curfew_at: now + 1.hour,
          status_id: AuthAdmissionBinding::ISSUED_STATUS_ID, }
      end,
      returning: %w(id),
    ).rows.flatten
    cases.each_with_index do |(status, cleanup_status, step, source_required), index|
      result = ClientSignUpFlow.insert_all!(
        [{ public_id: ("f" * 20) + index.to_s,
           auth_admission_binding_id: bindings[index],
           principal_id: 987_654_321,
           status_id: status,
           state: ClientSignUpFlow::STATUS_NAMES.fetch(status),
           step: step,
           entry_method: "email",
           nonce_digest: "f" * 64,
           issued_at: now - 2.hours,
           expires_at: now - 1.hour,
           completed_requirements: {},
           completed_at: (now - 90.minutes if status == ClientSignUpFlowStatus::COMPLETED),
           created_at: now - 3.hours,
           updated_at: now - 1.hour,
           cancelled_at: (now - 90.minutes if status == ClientSignUpFlowStatus::CANCELLED),
           cleanup_status_id: cleanup_status,
           discard_at: now - 1.hour,
           purge_eligible_at: now - 1.hour, }],
        returning: %w(id),
      )
      id = result.rows.first.first
      snapshot = ClientSignUpFlow.find(id).attributes
      if source_required
        error = assert_raises(StandardError) { RetentionPurgeJob.perform_now(batch_size: 1) }
        assert_equal "RetentionPurgeJob::AuthorityUnavailableError", error.class.name
      else
        assert_nothing_raised { RetentionPurgeJob.perform_now(batch_size: 1) }
      end

      assert_equal snapshot, ClientSignUpFlow.find(id).attributes
      # Delete only this isolated fixture after proving the application retained its exact history.
      ClientSignUpFlow.where(id: id).delete_all
    end
  end

  test "historical preference audit purge retains its inclusive writer-clock boundary" do
    AppPreferenceChronicleEvent.ensure_defaults!
    AppPreferenceChronicleLevel.ensure_defaults!
    now = AppPreferenceChronicle.database_now
    ids = AppPreferenceChronicle.insert_all!(
      [-1, 0, 1].map do |offset|
        { subject_type: "AppPreference",
          subject_id: 987_654,
          actor_type: "",
          actor_id: 0,
          event_id: AppPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
          level_id: 0,
          occurred_at: now - 1.day,
          context: {},
          discard_at: now - 1.hour,
          purge_eligible_at: now + Rational(offset, 1_000_000), }
      end,
      returning: %w(id),
    ).rows.flatten
    AppPreferenceChronicle.stub(:database_now, now) { RetentionPurgeJob.perform_now(batch_size: 2) }

    assert_not AppPreferenceChronicle.exists?(ids[0])
    assert_not AppPreferenceChronicle.exists?(ids[1])
    assert AppPreferenceChronicle.exists?(ids[2])
  end

  test "batch bounds and suspension remain effective before destructive work" do
    VisitorOccurrenceStatus.ensure_defaults!
    result = VisitorOccurrence.insert_all!(
      [{ body: "retention-suspended",
         public_id: "d" * 21,
         status_id: VisitorOccurrenceStatus::NOTHING,
         context: {},
         discard_at: 2.hours.ago,
         purge_eligible_at: 1.hour.ago, }],
      returning: %w(id),
    )
    id = result.rows.first.first
    Flipper.enable(RetentionPurgeJob::FEATURE_NAME)
    [-1, 0, 501, nil, 1.5, "1.5", ""].each do |invalid|
      assert_raises(ArgumentError) { RetentionPurgeJob.perform_now(batch_size: invalid) }
      assert VisitorOccurrence.exists?(id)
    end
    [1, 2, 499, 500, "1"].each do |valid|
      assert_nothing_raised { RetentionPurgeJob.perform_now(batch_size: valid) }
      assert VisitorOccurrence.exists?(id)
    end
    Flipper.disable(RetentionPurgeJob::FEATURE_NAME)
    RetentionPurgeJob.perform_now(batch_size: 1)

    assert_not VisitorOccurrence.exists?(id)
    assert_no_difference -> { VisitorOccurrence.count } do
      RetentionPurgeJob.perform_now(batch_size: 1)
    end
  end
end
