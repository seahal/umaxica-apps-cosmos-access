# typed: false
# frozen_string_literal: true

# Opaque WebAuthn user handle for a passkey-owning actor. Generated once at
# create and never rotated: authenticators associate stored credentials with
# this value, so changing it would orphan every credential minted under the
# old handle. It carries no PII and is independent per surface database.
module WebauthnUserHandleOwner
  extend ActiveSupport::Concern

  USER_HANDLE_RANDOM_BYTES = 32

  private

  def ensure_webauthn_user_handle
    self.webauthn_user_handle ||= SecureRandom.urlsafe_base64(WebauthnUserHandleOwner::USER_HANDLE_RANDOM_BYTES)
  end
end
