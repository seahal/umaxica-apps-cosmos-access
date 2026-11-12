# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: com_preference_chronicles
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
#  level_id       :bigint           default(0), not null
#  subject_id     :bigint           not null
#
# Indexes
#
#  idx_on_subject_type_subject_id_occurred_at_com_pref          (subject_type,subject_id,occurred_at)
#  index_com_preference_chronicles_on_actor_id_and_occurred_at  (actor_id,occurred_at)
#  index_com_preference_chronicles_on_actor_type_and_actor_id   (actor_type,actor_id)
#  index_com_preference_chronicles_on_event_id                  (event_id)
#  index_com_preference_chronicles_on_level_id                  (level_id)
#  index_com_preference_chronicles_on_occurred_at               (occurred_at)
#  index_com_preference_chronicles_on_purge_eligible_at                 (purge_eligible_at)
#  index_com_preference_chronicles_on_subject_id                (subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => com_preference_chronicle_events.id)
#  fk_rails_...  (level_id => com_preference_chronicle_levels.id)
#

class ComPreferenceChronicle < ChronicleRecord
  include Retainable

  belongs_to :com_preference_chronicle_level, foreign_key: :level_id, inverse_of: :com_preference_chronicles
  belongs_to :com_preference_chronicle_event,
             class_name: "ComPreferenceChronicleEvent",
             foreign_key: "event_id",
             primary_key: "id",
             inverse_of: :com_preference_chronicles
  validates :subject_type, presence: true

  validates :event_id, length: { maximum: 255 }
  validates :level_id, length: { maximum: 255 }
  validates :subject_id, exclusion: { in: [nil] }
  before_create :reject_retired_preference_identity!
  before_update :reject_retired_preference_identity!, if: :preference_reference_changing?

  private

  def preference_reference_changing?
    will_save_change_to_subject_id? || will_save_change_to_subject_type? ||
      will_save_change_to_actor_id? || will_save_change_to_actor_type?
  end

  def reject_retired_preference_identity!
    # Inspect historical and proposed types so changing a type cannot escape the guard.
    types = [subject_type, actor_type, subject_type_in_database, actor_type_in_database]
    return unless types.any? { |type| %w(AppPreference OrgPreference ComPreference).include?(type) }

    raise ActiveRecord::ReadOnlyRecord, "retired preference audit identity is immutable"
  end
end
