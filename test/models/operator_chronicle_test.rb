# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_chronicles
# Database name: chronicle
#
#  id             :bigint           not null, primary key
#  actor_type     :text             default(""), not null
#  context        :jsonb            not null
#  current_value  :text             default(""), not null
#  discard_at   :datetime         default(Infinity), not null
#  ip_address     :inet             default(#<IPAddr: IPv4:0.0.0.0/255.255.255.255>), not null
#  occurred_at    :datetime         not null
#  previous_value :text             default(""), not null
#  purge_eligible_at      :datetime         not null
#  subject_type   :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  actor_id       :bigint           default(0), not null
#  event_id       :bigint           default(0), not null
#  level_id       :bigint           default(1), not null
#  subject_id     :bigint           not null
#
# Indexes
#
#  idx_on_subject_type_subject_id_occurred_at_2e96c29236  (subject_type,subject_id,occurred_at)
#  index_operator_chronicles_on_actor_id_and_occurred_at  (actor_id,occurred_at)
#  index_operator_chronicles_on_event_id                  (event_id)
#  index_operator_chronicles_on_level_id                  (level_id)
#  index_operator_chronicles_on_occurred_at               (occurred_at)
#  index_operator_chronicles_on_purge_eligible_at                 (purge_eligible_at)
#  index_operator_chronicles_on_subject_id                (subject_id)
#  index_staff_activities_on_actor                        (actor_type,actor_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => operator_chronicle_events.id)
#  fk_rails_...  (level_id => operator_chronicle_levels.id)
#

require "test_helper"

class OperatorChronicleTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(operator_chronicle_events operator_chronicle_levels)

  def setup
    @subject_id = 123_456
    @audit_event = OperatorChronicleEvent.find(OperatorChronicleEvent::LOGIN_SUCCESS)
    @audit_level = OperatorChronicleLevel.find(OperatorChronicleLevel::NOTHING)
    @audit = OperatorChronicle.create!(
      subject_type: "Operator", subject_id: @subject_id,
      staff_chronicle_event: @audit_event, staff_chronicle_level: @audit_level,
      actor_type: "Client", actor_id: 123, timestamp: Time.current, ip_address: "192.168.1.1",
    )
  end

  test "uses bigint primary key" do
    assert_kind_of Integer, @audit.id
  end

  test "inherits from ChronicleRecord" do
    assert_operator OperatorChronicle, :<, ChronicleRecord
  end

  test "ip_address can be stored" do
    assert_equal "192.168.1.1", @audit.ip_address.to_s
  end

  test "subject identity is required" do
    audit = OperatorChronicle.new(staff_chronicle_event: @audit_event, staff_chronicle_level: @audit_level)

    assert_not audit.valid?
    assert_not_empty audit.errors[:subject_id]
    assert_not_empty audit.errors[:subject_type]
  end

  test "the default event remains valid for a scalar subject" do
    audit = OperatorChronicle.new(
      subject_type: "Operator", subject_id: @subject_id,
      staff_chronicle_level: @audit_level,
    )

    assert_predicate audit, :valid?
  end

  test "historical actor and subject stay scalar references without cross-database navigation" do
    assert_nil OperatorChronicle.reflect_on_association(:actor)
    assert_nil OperatorChronicle.reflect_on_association(:staff)
    assert_equal @subject_id, @audit.subject_id
    assert_equal "Operator", @audit.subject_type
    assert_equal 123, @audit.actor_id
    assert_equal "Client", @audit.actor_type
  end

  test "Client and Operator actor references remain distinguishable on historical audit rows" do
    ["Client", "Operator"].each_with_index do |type, index|
      audit = OperatorChronicle.create!(
        subject_type: "Operator", subject_id: @subject_id, actor_type: type, actor_id: index + 100,
        staff_chronicle_event: @audit_event, staff_chronicle_level: @audit_level,
      )

      assert_equal type, audit.reload.actor_type
      assert_equal index + 100, audit.actor_id
    end
    assert_equal 2,
                 OperatorChronicle.where(subject_type: "Operator", subject_id: @subject_id, actor_id: [100, 101]).count
  end

  test "level defaults to NOTHING when omitted" do
    audit = OperatorChronicle.create!(
      subject_type: "Operator", subject_id: @subject_id,
      staff_chronicle_event: @audit_event,
    )

    assert_equal OperatorChronicleLevel::NOTHING, audit.level_id
    assert_equal OperatorChronicleLevel::NOTHING, audit.staff_chronicle_level.id
  end

  test "timestamp defaults to current time" do
    audit = OperatorChronicle.create!(
      subject_type: "Operator", subject_id: @subject_id,
      staff_chronicle_event: @audit_event,
    )

    assert_not_nil audit.timestamp
  end

  test "blank event id does not produce an invalid event reference error" do
    audit = OperatorChronicle.new(subject_type: "Operator", subject_id: @subject_id, event_id: nil)
    audit.valid?

    assert_not_includes audit.errors[:event_id], "must reference a valid staff audit event"
  end

  test "unknown event is rejected by model validation and PostgreSQL foreign key" do
    audit = OperatorChronicle.new(
      subject_type: "Operator", subject_id: @subject_id,
      staff_chronicle_level: @audit_level, event_id: 999_999,
    )

    assert_not audit.valid?
    assert_includes audit.errors[:event_id], "must reference a valid staff audit event"
    attributes = @audit.attributes.except(
      "id", "sign_flow_halted_generation", "sign_flow_halted_transaction_public_id",
    ).merge("event_id" => 999_999)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      OperatorChronicle.transaction(requires_new: true) { OperatorChronicle.insert_all!([attributes]) }
    end
  end

  test "occurred_at aliases timestamp" do
    assert_equal @audit.timestamp, @audit.occurred_at
  end

  test "actor defaults to the scalar subject if blank" do
    audit = OperatorChronicle.create!(
      subject_type: "Operator", subject_id: @subject_id,
      staff_chronicle_event: @audit_event,
    )

    assert_equal @subject_id, audit.actor_id
    assert_equal "Operator", audit.actor_type
  end
end
