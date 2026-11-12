# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RetentionPurgeJobTest < ActiveJob::TestCase
  self.fixture_table_names = []

  teardown { Flipper.disable(RetentionPurgeJob::FEATURE_NAME) }

  test "generic retention preserves com preference audit history" do
    ComPreferenceChronicleEvent.ensure_defaults!
    ComPreferenceChronicleLevel.ensure_defaults!
    result = ComPreferenceChronicle.insert_all!(
      [{ subject_type: "ComPreference",
         subject_id: 987_654,
         actor_type: "",
         actor_id: 0,
         event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
         level_id: ComPreferenceChronicleLevel::INFO,
         occurred_at: 3.days.ago,
         created_at: 3.days.ago,
         context: {},
         discard_at: 2.days.ago,
         purge_eligible_at: 1.day.ago, }],
      returning: %w(id),
    )
    audit = ComPreferenceChronicle.find(result.rows.first.first)
    snapshot = audit.attributes

    RetentionPurgeJob.perform_now

    assert_predicate ComPreferenceChronicle.where(id: audit.id), :exists?
    assert_equal snapshot, audit.reload.attributes
  end

  test "rejects a retention batch size outside the bounded execution range" do
    error =
      assert_raises(ArgumentError) do
        RetentionPurgeJob.perform_now(batch_size: 501)
      end

    assert_equal "batch_size must be between 1 and 500", error.message
  end

  test "rejects fractional retention batch sizes instead of truncating them" do
    error =
      assert_raises(ArgumentError) do
        RetentionPurgeJob.perform_now(batch_size: 1.5)
      end

    assert_equal "batch_size must be between 1 and 500", error.message
  end

  test "rejects zero negative and missing retention batch sizes" do
    [0, -1, nil].each do |batch_size|
      error =
        assert_raises(ArgumentError) do
          RetentionPurgeJob.perform_now(batch_size: batch_size)
        end

      assert_equal "batch_size must be between 1 and 500", error.message
    end
  end

  test "accepts both inclusive retention batch-size boundaries before work" do
    FeatureFlags.stub(:enabled?, true) do
      [1, 500].each do |batch_size|
        assert_nothing_raised { RetentionPurgeJob.perform_now(batch_size:) }
      end
    end
  end

  test "accepts an integral string batch size through the public job interface" do
    FeatureFlags.stub(:enabled?, true) do
      # The validation is exercised before any destructive work is reached. The kill-switch stub
      # keeps this boundary test independent of retention rows while still using the public job
      # entrypoint.
      assert_nothing_raised { RetentionPurgeJob.perform_now(batch_size: "1") }
    end
  end

  test "continues after one retained model fails and re-raises the failure" do
    processed = []
    reported = []
    first_model = RetentionPurgeJob::RETAINABLE_MODELS.first
    failure = ActiveRecord::RecordNotDestroyed.new("retention target failed")
    job = RetentionPurgeJob.new

    # Retain the existing orchestration spy to prove every independent owner is attempted;
    # the separate PostgreSQL boundary tests exercise actual deletion and refusal behavior.
    job.stub(
      :purge_retained_model,
      lambda { |klass, batch_size:|
        processed << [klass, batch_size]
        raise failure if klass == first_model
      },
    ) do
      Rails.error.stub(:report, lambda { |error, **context| reported << [error, context] }) do
        assert_raises(ActiveRecord::RecordNotDestroyed) { job.perform(batch_size: 1) }
      end
    end

    assert_equal RetentionPurgeJob::RETAINABLE_MODELS.length, processed.length
    assert_equal failure, reported.fetch(0).fetch(0)
    assert_equal first_model.name, reported.fetch(0).fetch(1).fetch(:context).fetch(:retained_model)
  end

  test "purges visitor occurrences where purge_eligible_at is in the past" do
    VisitorOccurrenceStatus.ensure_defaults!
    occurrence_to_purge = VisitorOccurrence.create!(body: "purge-#{SecureRandom.hex(8)}")
    occurrence_to_keep = VisitorOccurrence.create!(body: "keep-#{SecureRandom.hex(8)}")

    occurrence_to_purge.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)
    occurrence_to_keep.update_columns(discard_at: Retainable::SENTINEL, purge_eligible_at: Retainable::SENTINEL)

    assert_difference -> { VisitorOccurrence.count }, -1 do
      RetentionPurgeJob.perform_now
    end

    assert_not VisitorOccurrence.exists?(occurrence_to_purge.id)
    assert VisitorOccurrence.exists?(occurrence_to_keep.id)
  end

  test "retention purge registers client sign-up flows and tokens independently" do
    models = RetentionPurgeJob::RETAINABLE_MODELS

    assert_includes models, ClientSignUpFlow
    assert_includes models, ClientToken
  end

  # Every generally purgeable Retainable model must be registered with RetentionPurgeJob so the
  # worker actually purges its rows. Forgetting to add a new model is silent --
  # `purge_eligible_at` ticks past forever with no one cleaning up. Compare against
  # the Retainable.registry that models populate on `included`.
  test "all generally purgeable Retainable models are registered in RETAINABLE_MODELS" do
    # Force eager load so every Retainable include block runs and registers.
    Rails.application.eager_load!

    # Com preference history needs lifecycle-specific audit and hold checks before deletion.
    specialized_models = [ComPreferenceChronicle]
    missing =
      (Retainable.registry - RetentionPurgeJob::RETAINABLE_MODELS - specialized_models).reject do |model|
        model.name.to_s.match?(/\A(?:CycleBaseTest|RetainableTest|SecretCredentialConcernTest)::/) ||
          !model.table_exists?
      end

    assert_empty missing,
                 "Models include Retainable but are absent from RetentionPurgeJob::RETAINABLE_MODELS -- " \
                 "rows in these tables will never be physically purged: #{missing.map(&:name).sort.join(", ")}"
  end

  # The kill switch is operational, not a retention rule: a suspended run must
  # leave every due row exactly as it found it, finish without raising (a raise
  # would requeue deliberately paused work), and stay catch-up safe so the next
  # unsuspended run completes the deletion.
end
