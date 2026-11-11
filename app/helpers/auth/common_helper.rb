# typed: false
# frozen_string_literal: true

module Auth::CommonHelper
  # Official Apple logo artwork, one file per button appearance: the white logo
  # for the black button, the black logo for the white button. Each is the
  # unmodified 31x44 left-aligned medium SVG from Apple Design Resources, whose
  # complete download is archived under src/assets/brand/sign-in-with-apple.
  # Presence is resolved once at load rather than per request: it is a
  # deployment fact, not request state.
  APPLE_SIGN_IN_LOGOS = {
    white: "/images/social/apple_logo_white.svg",
    black: "/images/social/apple_logo_black.svg",
  }.freeze

  APPLE_SIGN_IN_LOGOS_PRESENT =
    APPLE_SIGN_IN_LOGOS.values.all? { |path| Rails.root.join("public#{path}").file? }

  # Nil if the artwork is missing from a deployment. The caller then renders a
  # title-only Apple button; it must not substitute a redrawn logo.
  def apple_sign_in_logo_paths
    return nil unless APPLE_SIGN_IN_LOGOS_PRESENT

    APPLE_SIGN_IN_LOGOS
  end

  def get_language
    I18n.locale.to_s.start_with?("en") ? "en" : "ja"
  end

  def sign_up_birthdate_date_format
    value = Actor.preferences.date_format if defined?(Actor)
    normalized = value.to_s.downcase
    return "us" if normalized == "us"
    return "uk" if normalized == "uk"

    "iso"
  end

  def sign_up_birthdate_part_order(format = sign_up_birthdate_date_format)
    case format.to_s
    when "us"
      %w(month day year)
    when "uk"
      %w(day month year)
    else
      %w(year month day)
    end
  end

  # The birthdate parts serialized for an Inertia page. One implementation of the ordering, bounds
  # and labels serves the Auth sign-up flow.
  def sign_up_birthdate_prop_parts(value)
    parts = sign_up_birthdate_value_parts(value)

    sign_up_birthdate_part_order.map do |part|
      {
        part: part,
        label: sign_up_birthdate_part_label(part),
        placeholder: sign_up_birthdate_part_placeholder(part),
        value: parts[part],
        min: sign_up_birthdate_part_min(part),
        max: sign_up_birthdate_part_max(part),
      }
    end
  end

  def sign_up_birthdate_prop_separator(format = sign_up_birthdate_date_format)
    sign_up_birthdate_separator(format)
  end

  private

  def sign_up_birthdate_value_parts(value)
    match = /\A(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})\z/.match(value.to_s)
    return sign_up_birthdate_today_parts unless match

    {
      "year" => match[:year],
      "month" => match[:month],
      "day" => match[:day],
    }
  end

  # Today's date is a typing convenience only. It is never eligible: the checkpoint rejects it via
  # SignUpEligibilityPolicy.eligible? and HasBirthdate#birthdate_not_future rejects it on persist.
  def sign_up_birthdate_today_parts
    today = Time.zone.today
    {
      "year" => format("%04d", today.year),
      "month" => format("%02d", today.month),
      "day" => format("%02d", today.day),
    }
  end

  def sign_up_birthdate_part_label(part)
    t("sign.common.birthdate_parts." + part)
  end

  def sign_up_birthdate_part_placeholder(part)
    sign_up_birthdate_part_label(part)
  end

  def sign_up_birthdate_part_min(part)
    case part
    when "year" then 1900
    else 1
    end
  end

  def sign_up_birthdate_part_max(part)
    case part
    when "year" then Time.zone.today.year
    when "month" then 12
    else 31
    end
  end

  def sign_up_birthdate_separator(format)
    case format.to_s
    when "us", "uk" then " / "
    else " - "
    end
  end
end
