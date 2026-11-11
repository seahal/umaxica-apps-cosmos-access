# typed: false
# frozen_string_literal: true

# Host-only browser binding cookie that makes stored anonymous consent readable.
#
# - The cookie value is a 32-byte CSPRNG value, URL-safe-base64, 43 characters. The DB stores only
#   its SHA-256 digest; the raw value never reaches a record or a log line.
# - Minting happens on the browser's own explicit write when consent is enabled and no well-formed
#   binding value is being presented. A well-formed presented value is re-bound to the row as-is,
#   so the same browser keeps its binding across row generation changes.
# - Reads are constant-time: a presented value matches only when its digest equals the stored
#   digest. A missing or mismatched cookie means "no consent readable", and a read never mints,
#   extends, or deletes the binding.
module PreferenceBrowserBinding
  extend ActiveSupport::Concern

  VALUE_FORMAT = /\A[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]\z/
  COOKIE_NAME = PreferenceCookieName.binding
  class MismatchError < StandardError; end

  class << self
    public

    # True when the presented raw value is well formed and digests exactly to the stored digest.
    def matches?(raw_value, digest)
      return false if raw_value.blank? || digest.blank?
      return false unless valid_value?(raw_value)

      ActiveSupport::SecurityUtils.secure_compare(digest_for(raw_value), digest)
    end

    # The digest stored for a raw value; the only shape the DB is allowed to see.
    def digest_for(raw_value)
      Digest::SHA256.hexdigest(raw_value)
    end

    def mint_value
      SecureRandom.urlsafe_base64(32)
    end

    def valid_value?(raw_value)
      raw_value.is_a?(String) && VALUE_FORMAT.match?(raw_value)
    end
  end

  private

  def readable_cookie_state(cookie_record)
    %i(consented functional performant targetable).index_with do |field|
      !!cookie_record.public_send(field)
    end
  end

  def write_browser_binding_cookie(raw_value, expires_at:)
    cookies[COOKIE_NAME] = CoreCookieOptions.for(
      request: request, expires: expires_at, httponly: true, secure: true, same_site: :lax, path: "/",
    ).merge(value: raw_value)
  end

  def clear_browser_binding_cookie!
    options = CoreCookieOptions.for(
      request: request, httponly: true, secure: true, same_site: :lax, path: "/",
    )
    cookies.delete(COOKIE_NAME, **options)
  end
end
