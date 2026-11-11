# Passkey Authenticator Compatibility Experiments (2026-11-11)

Owner: Access (owner runs the experiments). Status: queued; manual, development environment and test
accounts only.

## Why

Reports say some security keys work on some sites and not others. The usual causes are old U2F-only
keys (no FIDO2, so no discoverable credentials or PIN), the limited number of discoverable
credentials a key can store, PIN not set, and site settings that require a resident key or user
verification. Access currently appears to work with iPhone, Android and Google Titan; nothing has
been checked systematically.

## Authenticators available (owner)

- iPhone (iCloud Keychain passkey; synced, expected BE=1)
- Android (Google Password Manager passkey; synced, expected BE=1)
- Google Titan Security Key (device-bound, expected BE=0, BS=0)
- Kensington VeriMark Guard USB-A (fingerprint key; supports FIDO2 and U2F; with Access's required
  discoverable credential and user verification it must run as FIDO2, using the fingerprint as user
  verification; expected BE=0, BS=0). Check that a fingerprint is enrolled first, and record whether
  registration fails when the key's discoverable-credential storage is full.
- a U2F-only device (FIDO U2F): not supported (owner, 2026-11-11). Access is not deployed yet and
  needs no backward compatibility; it requires FIDO2 passkeys (discoverable credential and user
  verification). Test only that registration with this device is refused with a clear message.

## Record per authenticator and browser

- Registration: success or the exact error; whether a PIN was asked; whether the credential was
  stored on the key (discoverable).
- Sign-in with and without typing an identifier first (discoverable vs non-discoverable flow).
- Step-up with user verification.
- Flags reported by the authenticator: BE and BS (from the authenticator data; developer tools or a
  server log of flags only, never keys or assertions).
- The Access WebAuthn options in force: `residentKey`, `userVerification`, attestation, allowed
  transports.

## Decisions this feeds

- BE is stored at registration (fixed; usable later for an AAL3 policy that requires device-bound
  keys). BS and `signCount` are not stored (`adr/access-is-a-pure-openid-provider.md`, decision 10).
- Whether to keep requiring discoverable credentials and user verification, given which keys fail.

Record results in `evidence/` (no key material, no assertions, no personal data).
