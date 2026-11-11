# typed: false
# frozen_string_literal: true

module Auth::Org::SignUpsHelper
  def auth_org_recruit_contact_url
    safe_recruit_contact_url(ENV["ORG_SIGN_UP_DIRECT_MESSAGE_URL"])
  end

  private

  def safe_recruit_contact_url(value)
    raw = value.to_s.strip
    return nil if raw.blank?
    return nil if raw.match?(/[\x00-\x1F\x7F]/)

    uri = URI.parse(raw)
    return nil unless uri.is_a?(URI::HTTP)
    return nil unless uri.scheme == "https" || local_http_url?(uri)
    return nil if uri.host.blank?
    return nil if uri.userinfo.present?

    uri.scheme = uri.scheme.downcase
    uri.host = uri.host.downcase
    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  def local_http_url?(uri)
    Rails.env.local? && uri.scheme == "http" && (uri.host == "localhost" || uri.host.end_with?(".localhost"))
  end
end
