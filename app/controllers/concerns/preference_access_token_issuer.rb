# typed: false
# frozen_string_literal: true

module PreferenceAccessTokenIssuer
  extend ActiveSupport::Concern

  private

  def anonymous_preference_cookie_options(expires_at:, httponly: true)
    {
      domain: anonymous_preference_cookie_domain,
      path: "/",
      secure: true,
      httponly: httponly,
      same_site: :lax,
      expires: expires_at,
    }.compact
  end

  def anonymous_preference_cookie_domain
    labels = request.host.to_s.split(".")
    return nil if labels.length < 3

    ".#{labels.last(2).join(".")}"
  end

  def preference_jwt_issuer_id
    "preference_#{preference_realm_name}"
  end
end
