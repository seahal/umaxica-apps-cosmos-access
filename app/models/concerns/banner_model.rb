# typed: false
# frozen_string_literal: true

module BannerModel
  extend ActiveSupport::Concern

  DISTANT_ENDS_AT = -> { Time.zone.local(9999, 12, 31, 23, 59, 59) }

  public

  def actor
    nil
  end

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, :invalid)
  end
end
