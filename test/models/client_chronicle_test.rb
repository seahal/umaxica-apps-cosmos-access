# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_chronicles
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
#  level_id       :bigint           default(4), not null
#  subject_id     :bigint           not null
#
# Indexes
#
#  idx_on_subject_type_subject_id_occurred_at_a29eb711dd  (subject_type,subject_id,occurred_at)
#  index_client_chronicles_on_actor_id_and_occurred_at    (actor_id,occurred_at)
#  index_client_chronicles_on_event_id                    (event_id)
#  index_client_chronicles_on_level_id                    (level_id)
#  index_client_chronicles_on_occurred_at                 (occurred_at)
#  index_client_chronicles_on_purge_eligible_at                   (purge_eligible_at)
#  index_client_chronicles_on_subject_id                  (subject_id)
#  index_user_activities_on_actor                         (actor_type,actor_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => client_chronicle_events.id)
#  fk_rails_...  (level_id => client_chronicle_levels.id)
#

require "test_helper"

class ClientChronicleTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens client_device_sessions client_chronicle_events client_chronicle_levels)

  def setup
    @subject_id = client_tokens(:one).user_id
    @audit_event = ClientChronicleEvent.find(ClientChronicleEvent::LOGIN_SUCCESS)
    @level = ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::INFO)
    @audit = ClientChronicle.create!(
      subject_type: "Client", subject_id: @subject_id,
      user_chronicle_level: @level, user_chronicle_event: @audit_event,
      timestamp: Time.current, ip_address: "192.168.1.1",
    )
  end

  test "uses bigint primary key" do
    assert_kind_of Integer, @audit.id
  end

  test "inherits from ChronicleRecord" do
    assert_operator ClientChronicle, :<, ChronicleRecord
  end

  test "ip_address can be stored" do
    assert_equal "192.168.1.1", @audit.ip_address.to_s
  end

  test "subject identity is required" do
    audit = ClientChronicle.new(user_chronicle_event: @audit_event)

    assert_not audit.valid?
    assert_not_empty audit.errors[:subject_id]
    assert_not_empty audit.errors[:subject_type]
  end

  test "the default event remains valid for a scalar subject" do
    audit = ClientChronicle.new(subject_type: "Client", subject_id: @subject_id)

    assert_predicate audit, :valid?
  end

  test "invalid event references fail both model validation and PostgreSQL foreign key" do
    audit = ClientChronicle.new(
      subject_type: "Client", subject_id: @subject_id, event_id: 9999,
      timestamp: Time.current,
    )

    assert_not audit.valid?
    assert_includes audit.errors[:event_id], "must reference a valid user audit event"
    attributes = @audit.attributes.except("id").merge("event_id" => 9999)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientChronicle.transaction(requires_new: true) { ClientChronicle.insert_all!([attributes]) }
    end
  end

  test "historical actor and subject remain scalar references without cross-database navigation" do
    assert_nil ClientChronicle.reflect_on_association(:actor)
    assert_nil ClientChronicle.reflect_on_association(:user)
    assert_equal @subject_id.to_s, @audit.subject_id
    assert_equal "Client", @audit.subject_type
    assert_equal @subject_id, @audit.actor_id
    assert_equal "Client", @audit.actor_type
  end

  test "Client and Operator actor references remain distinguishable on historical audit rows" do
    ["Client", "Operator"].each_with_index do |type, index|
      audit = ClientChronicle.create!(
        subject_type: "Client", subject_id: @subject_id, actor_type: type, actor_id: index + 100,
        user_chronicle_event: @audit_event,
      )

      assert_equal type, audit.reload.actor_type
      assert_equal index + 100, audit.actor_id
    end
    assert_equal 2, ClientChronicle.where(subject_type: "Client", subject_id: @subject_id, actor_id: [100, 101]).count
  end

  test "blank event id does not produce an invalid event reference error" do
    audit = ClientChronicle.new(subject_type: "Client", subject_id: @subject_id, event_id: nil)
    audit.valid?

    assert_not_includes audit.errors[:event_id], "must reference a valid user audit event"
  end

  test "occurred_at alias works" do
    assert_equal @audit.timestamp, @audit.occurred_at
  end

  test "timestamp defaults to current time" do
    audit = ClientChronicle.create!(subject_type: "Client", subject_id: @subject_id, user_chronicle_event: @audit_event)

    assert_not_nil audit.timestamp
  end

  test "actor defaults to the scalar subject if blank" do
    audit = ClientChronicle.create!(subject_type: "Client", subject_id: @subject_id, user_chronicle_event: @audit_event)

    assert_equal @subject_id, audit.actor_id
    assert_equal "Client", audit.actor_type
  end
end
