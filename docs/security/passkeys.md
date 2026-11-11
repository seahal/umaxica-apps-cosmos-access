# Passkeys

Current Access passkey behavior covers APP/ORG Auth credential ceremonies. Visa consumes admitted
ceremony evidence and owns local session issuance. Access has no Base identity-management pages or
COM passkey routes; external RPs own their credential-management UI in their own repositories.
Persisted COM model history remains subject to the separate model/database usage report. Decisions
live in the ADRs in section (f). Mechanically checked invariants stay in
[WebAuthn security invariants](webauthn-security-invariants.md); RP ID and Origin rules in
[WebAuthn RP ID and Origin boundary](webauthn-rp-id-origin-boundary.md).

## (a) Where Passkeys are used

| Purpose                               | Routes                                                                                                    | Surfaces    | Controller                                                                          | Concerns                                                                               | Main tests                                                                                                                 |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Sign-in (identifier-first)            | `GET /sign/in/passkey/new`, `POST /sign/in/passkey/options`, `POST /sign/in/passkey/verification`         | APP         | `Auth::<S>::Sign::In::{Passkeys,Passkey::Options,Passkey::Verifications}Controller` | `PasskeySignInFlow`, `SignInPhaseBindingControllerSupport`                             | `test/controllers/auth/app/in/passkeys_controller_test.rb`, `test/queries/passkey_sign_in_identity_resolver_query_test.rb` |
| ORG Normal sign-in after Entra        | same three routes                                                                                         | ORG         | `Auth::Org::Sign::In::…`                                                            | `SignOrgNormalPasskeyCeremony`                                                         | `test/controllers/auth/org/in/passkeys_controller_test.rb`                                                                 |
| ORG Emergency (Standby)               | `GET /sign/in/emergency/passkey/new`, `POST …/options`, `POST …/verification`                             | ORG         | `Auth::Org::Sign::In::Emergency::…`                                                 | `SignOrgStandbyPasskeyCeremony`                                                        | `test/controllers/auth/org/in/emergency/passkeys_controller_test.rb`                                                       |
| Sign-in second factor (MFA)           | `GET /sign/in/challenge/passkey/new`, `POST /sign/in/challenge/passkey`                                   | APP         | `Auth::<S>::Sign::In::Challenge::PasskeysController`                                | `PasskeyCeremonyContext`, `SignInPhaseBindingControllerSupport`                        | `test/controllers/auth/app/in/mfa/passkeys_controller_test.rb`                                                             |
| Sign-up registration (telephone path) | `GET/POST/PATCH/PUT/DELETE /sign/up/check/telephone/passkey`                                              | APP         | `Auth::<S>::Sign::Up::Check::Telephone::PasskeysController`                         | `PasskeyRegistrationFlow`                                                              | `test/controllers/auth/app/up/checkpoint_passkeys_controller_test.rb`                                                      |
| Step-Up                               | `GET /verification/passkey/new`, `POST /verification/passkey/options`, `POST /verification/passkey`       | APP, ORG    | `Auth::<S>::Verification::PasskeysController`                                       | `AuthStepUpPasskeyCeremony`                                                            | `test/services/webauthn/verifier_uv_policy_test.rb` and Step-Up request tests                                              |
| Registration for a signed-in Identity | `GET /verification/registration/passkey/new`, `POST …/options`, `POST /verification/registration/passkey` | APP, ORG    | `Auth::<S>::Verification::Registration::PasskeysController`                         | `AuthPasskeyRegistrationCeremony` → `IdentityPasskeyRegistrationVerificationCommitter` | `test/controllers/auth/ceremony_admission_boundary_test.rb`                                                                |
| External credential management        | No local Access route                                                                                     | External RP | Owned by the RP repository                                                          | RP-specific                                                                            | RP-specific                                                                                                                |

`bin/rails routes -g passkey` is the current route inventory. It must contain only Auth APP/ORG
ceremony routes; external RP management pages are outside this application.

## (b) Registration

- Discoverable credentials on retained Auth APP/ORG ceremony surfaces
  (`RegistrationVerifier::RESIDENT_KEY_BY_SURFACE`, `resident_key: "required"` for sign-up and
  Identity registration), attestation `none`, User Verification required (`Webauthn::UvPolicy`).
  Registration options request the `credProps` extension; ORG refuses a credential the client does
  not report as discoverable (`rk: true`) with `DiscoverableCredentialRequiredError`, and a UV=false
  attestation is refused on every surface.
- `user.id` is the opaque immutable WebAuthn user handle. `user.name` and `user.displayName` use the
  APP or ORG surface label from `Webauthn::Surface#account_label`, never an Email, Telephone,
  Employee Number, Entra identifier, or user handle.
- Capacity: at most ten Passkeys per retained APP/ORG Identity (`MAX_PASSKEYS_PER_USER`, `_STAFF`),
  checked under the owner lock in `PasskeyRegistrationOperation`; the eleventh is refused. Visitor
  credential limits remain persisted history for the deferred model report. Writes outside that
  operation are the open gap in `plans/backlog/2026-10-19-passkey-limit-enforcement-gap.md`.
- Authenticator metadata (`Webauthn::AuthenticatorMetadata`) and the audit outbox
  (`*PasskeyAuditOutbox`) are written with the credential.

## (c) Sign-in

- APP is identifier-first: the options request carries `identifier` (an Email or Telephone).
  `PasskeySignInIdentityResolverQuery` selects the Identity only through an effective contact
  binding of that surface. A missing or empty identifier is refused with 422. An unknown, malformed,
  unverified, unfinalized, released, expired or other-surface identifier is not distinguished in the
  response: the challenge is bound to an actor key no credential owns (`<surface>:0`).
- `allowCredentials` is always empty on APP; the authenticator offers its discoverable credentials.
- Verification requires the presenting credential's owner to equal the Identity the challenge was
  bound to. The `userHandle` the client sends is not used for selection; when present, its decoded
  bytes must equal that Identity's immutable opaque handle. A credential of another Identity or a
  mismatched returned handle is refused with the same 401 as a missing credential.
- ORG Normal runs after the Entra sign-in and binds to the Operator that the Entra transaction
  names. ORG Emergency selects by Employee Number, sends no descriptors, and produces a Standby
  context.
- Every sign-in ceremony records evidence on Auth under the Visa-owned OIDC authorization parent;
  Visa issues the session when the authorization resumes. Auth issues no general login session.

## (d) Invariants

- Non-disclosure: existing and unknown identifiers receive the same status and options shape; no
  real credential id is ever sent before authentication on APP.
- Ownership: credential owner = challenge actor, re-checked under the actor and credential locks.
- Replay: challenges are one-time and bound to surface, RP ID, Origin, purpose and actor
  (`Webauthn::ChallengeStore`); every path discards the challenge after use.
- `ADVANCED` Security Mode keeps at least two active Passkeys
  (`adr/authentication-security-mode.md`).

## (e) Threats and limits

- A lost authenticator together with its PIN and the victim's identifier still signs in on APP. The
  account label removes the identifier from the authenticator, so the finder must learn it
  elsewhere. Access provides no general passkey-management page; use the owning RP's credential
  management or recovery process.
- ORG Normal additionally requires the Entra sign-in.
- Response timing between existing and unknown identifiers is bounded by `MinimumResponseBudget`; no
  separate timing measurement is recorded for identifier-first sign-in yet.

## (f) Governing ADRs

| ADR                                                       | Effect today                                                                                                                    |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `adr/passkey-identifier-first-sign-in.md`                 | Identity selection before the ceremony; ten-Passkey capacity and discoverable ORG credentials, with the account-label amendment |
| `adr/passkey-authenticator-account-label.md`              | Non-identifying label; ORG discoverable; capacity ten                                                                           |
| `adr/credential-response-nondisclosure.md`                | ORG discoverable + UV; Emergency without descriptors; one refusal message                                                       |
| `adr/webauthn-discoverable-direct-sign-in.md`             | Usernameless APP/COM selection superseded by identifier-first                                                                   |
| `adr/webauthn-user-handle.md`                             | Opaque immutable user handles                                                                                                   |
| `adr/passkey-uv-policy.md`                                | UV registry                                                                                                                     |
| `adr/passkey-authenticator-metadata.md`                   | Metadata                                                                                                                        |
| `adr/passkey-current-state-limit-and-chronicle-outbox.md` | Lifecycle, owner serialization, outbox                                                                                          |
| `adr/authentication-security-mode.md`                     | `ADVANCED` two-Passkey minimum                                                                                                  |
