# typed: false
# frozen_string_literal: true

# FIXME: omniauth-apple 1.4.0 calls `id_token.verify!(jwk)` without an algorithm allowlist, so
# json-jwt accepts any RSA or RSA-PSS `alg` (RS384, RS512, PS256, PS384, PS512) correctly signed with
# Apple's key, although Apple publishes RS256 only. `none` is refused explicitly and HMAC fails
# because the key arrives as an RSA object, but the policy depends on json-jwt's key typing, not on
# an explicit list. Pin RS256 here by overriding `verify_signature!` (pass `[:RS256]` as a symbol)
# and propose the same fix upstream (owner, 2026-11-10;
# docs/backlog/2026-11-10-core-security-review-followups.md).
module ExternalAuthenticationInfrastructureOmniauthAppleNonceEnforcement
  private

  # omniauth-apple 1.4.0 verifies nonce only when the ID token asserts
  # nonce_supported. This application always sends nonce, so its absence must
  # fail authentication even when that nonstandard claim is absent.
  def verify_claims!(id_token)
    super
    verify_nonce!(id_token) unless id_token[:nonce_supported]
  end
end
