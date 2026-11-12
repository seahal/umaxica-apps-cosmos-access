# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpExpiryJobTest < ActiveJob::TestCase
  setup do
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
  end

  test "expires overdue in-progress tickets on the app ticket database" do
    now = Time.current.change(usec: 0)
    expired_client = create_flow(ClientSignUpFlow, now: now, expires_at: now - Rational(1, 1_000_000))
    boundary_client = create_flow(ClientSignUpFlow, now: now, expires_at: now)
    active_client = create_flow(ClientSignUpFlow, now: now, expires_at: now + Rational(1, 1_000_000))

    travel_to now do
      # Freeze the owning database clock for nearest-microsecond expiry boundaries.
      ClientSignUpFlow.stub(:database_now, now) do
        assert_raises(GovernanceLookupUnavailableError) { SignUpExpiryJob.perform_now(batch_size: 1) }
      end
    end

    assert_equal ClientSignUpFlowStatus::EXPIRED, expired_client.reload.status_id
    assert_not expired_client.reload.cleanup_completed?
    assert_predicate boundary_client.reload, :sign_up_expired?
    assert_not boundary_client.cleanup_completed?
    assert_predicate active_client.reload, :sign_up_in_progress?
  end

  test "keeps terminal and not-yet-expired tickets unchanged" do
    now = Time.current.change(usec: 0)
    active = create_flow(ClientSignUpFlow, now: now, expires_at: now + 1.minute)
    completed = create_flow(
      ClientSignUpFlow,
      now: now,
      status_id: ClientSignUpFlowStatus::COMPLETED,
      step: "completed",
      expires_at: now - 1.second,
      completed_at: now - 2.seconds,
    )

    travel_to now do
      SignUpExpiryJob.perform_now
    end

    assert_equal ClientSignUpFlowStatus::STARTED, active.reload.status_id
    assert_equal ClientSignUpFlowStatus::COMPLETED, completed.reload.status_id
  end

  test "an inaccessible historical ticket does not prevent local expiry of other tickets" do
    now = Time.current.change(usec: 0)
    failing = create_flow(ClientSignUpFlow, now: now, expires_at: now - 1.second)
    other = create_flow(ClientSignUpFlow, now: now, expires_at: now - 1.second)
    failing.update!(discard_at: failing.created_at)
    logged = []

    Rails.logger.stub(:error, ->(message) { logged << message }) do
      travel_to now do
        assert_raises(FlowInvalidTransition, GovernanceLookupUnavailableError) { SignUpExpiryJob.perform_now }
      end
    end

    assert_predicate failing.reload, :sign_up_in_progress?
    assert_equal ClientSignUpFlowStatus::EXPIRED, other.reload.status_id
    assert_not other.cleanup_completed?
    assert logged.any? { |line|
      line.include?("sign_up.expiry.failed") && line.include?(failing.public_id) &&
        line.include?("FlowInvalidTransition")
    }
  end

  test "lets a database-clock deadlock escape so the job is retried" do
    ClientSignUpFlow.stub(:database_now, -> { raise ActiveRecord::Deadlocked, "deadlock detected" }) do
      assert_enqueued_with(job: SignUpExpiryJob) { SignUpExpiryJob.perform_now }
    end
  end

  test "expiry closes every local ticket but exposes unavailable Governance cleanup" do
    now = Time.current.change(usec: 0)
    tickets = Array.new(2) { create_flow(ClientSignUpFlow, now: now, expires_at: now - 1.second) }

    travel_to now do
      assert_raises(GovernanceLookupUnavailableError) { SignUpExpiryJob.perform_now }
    end

    tickets.each do |ticket|
      assert_predicate ticket.reload, :sign_up_expired?
      assert_not ticket.cleanup_completed?
    end
  end

  test "uses the retention queue" do
    assert_equal "retention", SignUpExpiryJob.queue_name
  end

  private

  def create_flow(model, now:, expires_at:, status_id: nil, step: "start", completed_at: nil)
    model.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(model),
      principal_id: nil,
      status_id: status_id || model::STATUS_MODEL::STARTED,
      step: step,
      nonce_digest: model.digest_nonce(SecureRandom.hex(16)),
      issued_at: now - 1.minute,
      expires_at: expires_at,
      completed_at: completed_at,
      entry_method: "email",
    )
  end
end
