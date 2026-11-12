# frozen_string_literal: true

require "test_helper"

class RetiredPreferenceAuditBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "historical preference identity is immutable while metadata and retention remain usable" do
    [
      [AppPreferenceChronicle, AppPreferenceChronicleEvent, AppPreferenceChronicleLevel, "AppPreference"],
      [OrgPreferenceChronicle, OrgPreferenceChronicleEvent, OrgPreferenceChronicleLevel, "OrgPreference"],
      [ComPreferenceChronicle, ComPreferenceChronicleEvent, ComPreferenceChronicleLevel, "ComPreference"],
    ].each do |model, event_model, level_model, retired_type|
      event_model.ensure_defaults!
      level_model.ensure_defaults!
      created_at = 1.day.ago
      result = model.insert_all!(
        [{ subject_type: retired_type,
           subject_id: 987_654,
           actor_type: retired_type,
           actor_id: 876_543,
           event_id: event_model::CREATE_NEW_PREFERENCE_TOKEN,
           level_id: 0,
           occurred_at: created_at,
           created_at: created_at,
           discard_at: 1.year.from_now,
           purge_eligible_at: 2.years.from_now,
           context: {}, }],
        returning: %w(id),
      )
      row = model.find(result.rows.first.first)
      identity = row.attributes.slice("subject_type", "subject_id", "actor_type", "actor_id", "occurred_at")
      row.update!(context: { "retirement_review" => "preserved" })
      row.schedule_retention!(discard_at: 3.years.from_now, purge_eligible_at: 4.years.from_now)

      assert_equal identity, row.reload.attributes.slice(*identity.keys)
      assert_equal({ "retirement_review" => "preserved" }, row.context)
      assert_not row.purgeable?

      { subject_id: 987_655,
        subject_type: "UnrelatedHistoricalSubject",
        actor_id: 876_544,
        actor_type: "UnrelatedHistoricalActor", }.each do |field, value|
        assert_raises(ActiveRecord::ReadOnlyRecord) do
          model.transaction(requires_new: true) do
            row.assign_attributes(field => value)
            row.save!(validate: false)
          end
        end
        assert_equal identity, row.reload.attributes.slice(*identity.keys)
      end

      assert_raises(ActiveRecord::NotNullViolation) do
        model.transaction(requires_new: true) { model.where(id: row.id).update_all(subject_id: nil) }
      end
      assert_equal identity, row.reload.attributes.slice(*identity.keys)
      travel_to(5.years.from_now) do
        assert_predicate row, :purgeable?
        row.destroy!
      end

      assert_not model.exists?(row.id)
    end
  end

  test "retired preference references cannot be created and unrelated audit subjects remain valid" do
    [
      [AppPreferenceChronicle, AppPreferenceChronicleEvent, AppPreferenceChronicleLevel],
      [OrgPreferenceChronicle, OrgPreferenceChronicleEvent, OrgPreferenceChronicleLevel],
      [ComPreferenceChronicle, ComPreferenceChronicleEvent, ComPreferenceChronicleLevel],
    ].each do |model, event_model, level_model|
      event_model.ensure_defaults!
      level_model.ensure_defaults!
      %w(AppPreference OrgPreference ComPreference).each do |retired_type|
        %i(subject_type actor_type).each do |field|
          attributes = { subject_type: "HistoricalExternalSubject",
                         subject_id: 123,
                         actor_type: "",
                         actor_id: 0,
                         event_id: event_model::CREATE_NEW_PREFERENCE_TOKEN,
                         level_id: 0,
                         occurred_at: Time.current,
                         discard_at: 1.year.from_now,
                         purge_eligible_at: 2.years.from_now,
                         context: {}, }.merge(field => retired_type)
          assert_no_difference -> { model.count } do
            assert_raises(ActiveRecord::ReadOnlyRecord) { model.new(attributes).save!(validate: false) }
          end
        end
      end
      row = model.create!(
        subject_type: "HistoricalExternalSubject", subject_id: 123,
        event_id: event_model::CREATE_NEW_PREFERENCE_TOKEN, level_id: 0, occurred_at: Time.current,
        discard_at: 1.year.from_now, purge_eligible_at: 2.years.from_now,
        context: {},
      )

      assert_equal "HistoricalExternalSubject", row.reload.subject_type
      assert_equal 0, row.actor_id
      assert_raises(ActiveRecord::ReadOnlyRecord) { row.update!(subject_type: "AppPreference") }
      assert_equal "HistoricalExternalSubject", row.reload.subject_type
    end
  end
  test "historical operator and visitor actors remain scalar references" do
    [
      [OrgPreferenceChronicle, OrgPreferenceChronicleEvent, OrgPreferenceChronicleLevel, "Operator"],
      [ComPreferenceChronicle, ComPreferenceChronicleEvent, ComPreferenceChronicleLevel, "Visitor"],
    ].each do |model, event_model, level_model, actor_type|
      event_model.ensure_defaults!
      level_model.ensure_defaults!
      result = model.insert_all!(
        [{ subject_type: "HistoricalExternalSubject",
           subject_id: 42,
           actor_type: actor_type,
           actor_id: 123,
           event_id: event_model::CREATE_NEW_PREFERENCE_TOKEN,
           level_id: 0,
           occurred_at: Time.current,
           discard_at: 1.year.from_now,
           purge_eligible_at: 2.years.from_now,
           context: {}, }],
        returning: %w(id),
      )
      row = model.includes("#{model.model_name.singular}_event", "#{model.model_name.singular}_level")
        .find(result.rows.first.first)

      assert_nil model.reflect_on_association(:actor)
      assert_not_respond_to row, :actor
      assert_equal [actor_type, 123], [row.actor_type, row.actor_id]
      assert_not_nil row.public_send("#{model.model_name.singular}_event")
      assert_not_nil row.public_send("#{model.model_name.singular}_level")
    end
  end
end
