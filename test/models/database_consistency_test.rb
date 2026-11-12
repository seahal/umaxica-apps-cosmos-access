# typed: false
# frozen_string_literal: true

require "test_helper"

class DatabaseConsistencyTest < ActiveSupport::TestCase
  fixtures :client_occurrence_statuses, :zip_occurrence_statuses

  setup do
    I18n.locale = I18n.default_locale # rubocop:disable Rails/I18nLocaleAssignment
  end

  test "ClientZipOccurrence requires a unique combination of user_occurrence_id and zip_occurrence_id" do
    user_occurrence = ClientOccurrence.first || ClientOccurrence.create!(
      body: "user_occ_#{SecureRandom.hex(6)}",
      status_id: ClientOccurrenceStatus::NOTHING,
    )
    zip_occurrence = ZipOccurrence.first || ZipOccurrence.create!(
      body: "zip_#{SecureRandom.hex(4)}",
      status_id: ZipOccurrenceStatus::NOTHING,
    )

    ClientZipOccurrence.create!(
      user_occurrence_id: user_occurrence.id,
      zip_occurrence_id: zip_occurrence.id,
    )

    duplicate = ClientZipOccurrence.new(
      user_occurrence_id: user_occurrence.id,
      zip_occurrence_id: zip_occurrence.id,
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_occurrence_id], "はすでに存在します"
  end
end
