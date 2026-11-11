# Sign-In Sequence

The canonical Sign In admission also receives completed App registration. The rationale and
failure-domain contract are documented in
[Sign In First: Registration Handoff](sign-in-first-registration-handoff.md) and
[ADR D13](../../adr/sign-in-first-and-sign-up-handoff.md).

> **Current scope (2026-11-10):** Visa APP/ORG is the sole local OpenID Provider and session
> authority; Auth APP/ORG owns credential ceremonies. External RPs retain their approved Visa
> registrations but own their callbacks, browser sessions, and post-auth pages in their
> repositories. Access has no local RP callback or dashboard route. Older `sign/id`–`acme/www`
> sections are migration history.

> **Reading rule:** The sections below retain the earlier `sign/id`–`acme/www` vocabulary as a
> migration record. They are not a description of the current Access route boundary. For the active
> result contract, use the current section immediately below and the Auth/Visa ownership contract.

> **Lifecycle vocabulary:** Status, event, and result names in this document are current runtime
> vocabulary. Future canonical lifecycle terminology (`ACTIVE`, `COMPLETED`, `CANCELLED`, `EXPIRED`,
> `HALTED`, and the canonical events) is defined in `docs/security/idp-flow-lifecycle.md` and
> `adr/idp-flow-lifecycle-vocabulary.md`; future canonical naming remains a documentation concern
> unless the owning lifecycle axis is changed.

## Current Rails result contract

Auth owns credential ceremony continuity and authentication evidence only. Visa owns the OIDC
authorization transaction, Root Session, authorization code, and authority token issuance. Visa's
client-scoped grant and token records remain in Access; each external RP owns its callback, browser
session, and product state in its own repository. Registrations do not give Access authority over an
external RP's database.

The Auth-to-Visa result is a short-lived opaque Valkey transport capability. Its digest, generation,
expiry, and Visa finalization references are stored on the matching surface-local PostgreSQL
authorization transaction. The Visa display GET validates the transaction, reads the transport, and
renders a same-origin continuation without consuming it. The authorization POST rechecks the
generation under the locked PostgreSQL row before finalizing. A current result may be retried while
its transport TTL remains; the authority finalization timestamp makes Root Session finalization
idempotent and a transaction creates at most one Root Session.

The transport is not the authorization grant. Authorization-code aliases may be issued for the same
durable transaction, while `authorization_grant_redeemed_at` is claimed atomically in the same
surface ticket-database transaction that creates or resolves the RP Session. Raw result and
authorization-code values are never stored in PostgreSQL. Valkey cleanup is transport cleanup, not
the durable session or grant authority. Rails forgery protection remains enabled for both local and
cross-surface POST boundaries.

The historical `sign/id` and `acme/www` sections that follow must therefore not be used to infer
that a result is signed, Valkey-one-shot, or owned by Acme in the current Rails implementation.

## Historical migration vocabulary: Authority

Sign-in has two boundaries:

- `sign/id` hosts unauthenticated sign-in entry points and executes credential ceremonies.
- `acme/www` consumes the ceremony result and commits session, actor/session, OIDC, and token state.

Sign-in completion means the credential ceremony is complete on sign and the session commit is
complete on acme. A credential ceremony alone is not a signed-in session.

Logical authority moves now; physical storage may remain where it is. Existing sign-side tables,
models, services, controllers, route names, or namespaces do not imply sign-side authority.

## Sign/ID Responsibilities

`sign/id` may:

- host unauthenticated sign-in entry points;
- collect identifiers needed to start a credential ceremony;
- execute passkey/WebAuthn, OTP, TOTP, passcode, and social callback ceremonies where supported;
- host MFA ceremony steps that are part of sign-in credential proof;
- consume or introspect an acme session only to decide whether a ceremony is needed;
- keep credential inventory and short-lived ceremony state;
- return a signed, one-shot ceremony result to acme.

`sign/id` must not:

- create, rotate, continue, revoke, list, or display user sessions;
- issue access tokens, refresh tokens, OIDC tokens, or downstream tokens;
- store step-up freshness, `recent_auth`, `sudo`, or `last_step_up_at`;
- redirect to a sign dashboard as signed-in authority;
- commit actor/session state;
- decide authorization for product behavior.

Acme's own browser flow uses the shared browser RP client id `base-rails-rp`. The first
`/oauth/authorize` login step establishes Acme authority for code issuance. The later
`/oidc/callback` step validates state, PKCE, nonce, and ID token claims, then establishes the local
product browser session on the same host. That callback is an intentional RP boundary, not a second
authority issuer.

## Acme/WWW Responsibilities

`acme/www` owns:

- session creation and continuation;
- actor/session state;
- sign-in guardrails that depend on account/session/product policy;
- session-limit decisions and session-management UI;
- the Acme sign-in limitation ceremony at `/sign/in/limitation`;
- dashboard and post-auth navigation as authenticated product surfaces;
- OIDC authorization, token issuance, and JWKS authority;
- refresh token family issuance and rotation;
- downstream token issuance;
- step-up freshness confirmation when sign-in is not enough for a later sensitive action.

`core`, `line`, and future downstream services must trust acme-issued downstream tokens, not
sign-issued tokens.

## Historical migration vocabulary: Ceremony Result Flow

The sign-in flow uses the credential grant/result boundary:

1. The browser enters a sign/id unauthenticated sign-in route.
2. sign/id executes the requested credential ceremony.
3. sign/id returns a signed ceremony result that is audience-bound to acme, purpose-bound, one-shot,
   expiring, and bound to the acme transaction or session where applicable.
4. acme validates and consumes the result.
5. acme commits or rejects session creation and actor/session state.
6. acme performs post-auth navigation, dashboard routing, OIDC continuation, or downstream token
   issuance as acme-owned behavior.

Redirect targets, OAuth/OIDC `state`, Jump `rt`, and local return paths are navigation state. They
must not carry authentication result facts. The signed ceremony result is the security object.

## Sequence Vocabulary

The old sign-in state-machine vocabulary remains useful only as ceremony or compatibility routing
vocabulary:

| Vocabulary                   | Historical meaning                                                                  |
| ---------------------------- | ----------------------------------------------------------------------------------- |
| Primary credential           | The first credential ceremony executed by sign/id.                                  |
| MFA challenge during sign-in | Additional credential ceremony before sign returns evidence to acme.                |
| Guardrail                    | A policy stop. If it depends on session/account/product state, acme owns it.        |
| Checkpoint                   | A required pre-session or post-auth requirement. acme owns session/account effects. |
| Selector                     | Acme-owned actor/session selection before session commit.                           |
| Session issuance             | Acme-owned session creation, never sign-owned.                                      |
| Welcome/dashboard            | Acme-owned post-auth navigation or product surface.                                 |

Existing DB-backed sign-in cycle rows may remain physically where they are during migration. They do
not make sign the session authority.

## Surface Inventory

The supported credential methods remain surface-aware:

| Surface | Auth ceremony methods                                               | Visa-owned commit                                            |
| ------- | ------------------------------------------------------------------- | ------------------------------------------------------------ |
| `app`   | email OTP, passkey, TOTP where implemented, passcode, Google, Apple | Client session, account/session state, OIDC/token issuance   |
| `org`   | passkey, passcode                                                   | Operator session, account/session state, OIDC/token issuance |

Org production sign-in does not use external social providers. Google, Apple, Microsoft, and other
external social providers are not org sign-in methods.

## Auth APP Sign-In Route Matrix

Current Auth APP sign-in routes share the same ceremony completion gate. Route-local controllers
verify the credential or provider response, then return evidence to Visa. Visa performs the
session-issuance and OIDC authority transition.

| route family                        | controller path                                | credential / provider                | state object                        | completion gate                 | notes                                                                                  |
| ----------------------------------- | ---------------------------------------------- | ------------------------------------ | ----------------------------------- | ------------------------------- | -------------------------------------------------------------------------------------- |
| Email OTP                           | `Auth::App::Sign::In::EmailsController`        | email + OTP                          | Email sign-in flow                  | Visa authorization finalization | `create` issues real or dummy OTP; `update` verifies OTP and returns ceremony evidence |
| Google social                       | Auth APP social entry and callback controllers | Google OAuth / OmniAuth              | social auth intent + callback state | Visa authorization finalization | callback validates state, provider assertion, and callback replay                      |
| Apple social                        | Auth APP social entry and callback controllers | Apple OAuth / OmniAuth               | social auth intent + callback state | Visa authorization finalization | Apple form-post callback handling is delegated to the provider integration             |
| Passkey / WebAuthn                  | Auth APP passkey and verification controllers  | WebAuthn credential                  | passkey challenge state             | Visa authorization finalization | options and verification remain bound to the admitted ceremony                         |
| TOTP / passcode / secret credential | Auth APP secret and challenge controllers      | TOTP, passcode, or secret credential | pending MFA state                   | Visa authorization finalization | direct login and MFA follow-up branches return evidence to the same Visa transaction   |

The route families above must not create `ClientToken`, `ClientDeviceSession`, or auth cookies
directly in controller code.

All successful sign-in routes must normalize the completion result through the shared `SignInResult`
adapter. The current result shape includes `success`, `mfa_required`, `session_limit_pending`,
`session_limit_conflict`, `credential_rejected`, `identity_unavailable`, `transaction_expired`,
`failure`, and `invalid_request`.

## One RP sign-in per browser (D-155; current RP contract)

The accepted external RP contract limits each RP browser session to one pending sign-in. Access does
not implement those RP pending-flow cookies or interruption pages. Each RP must apply its registered
callback, state, nonce, and return-target checks in its own repository. Visa session limits are
enforced independently at the OP for APP and ORG.

## Timing And Enumeration Mitigation

Credential endpoints must not make account or credential existence easy to infer from response
timing. Controllers that include `MinimumResponseBudget` now get timing protection enabled by
default; endpoints that need a narrower action set override `minimum_response_budget_enabled?` for
those actions. The contract test in
`test/controllers/auth/credential_timing_protection_contract_test.rb` lists credential controllers
that must either use that response budget or document another timing-equalized path.

Current coverage is:

| Credential path             | Mitigation                                                      |
| --------------------------- | --------------------------------------------------------------- |
| App email OTP sign-in       | Dummy OTP generation and minimum elapsed verification on update |
| App/com/org passkey sign-in | `MinimumResponseBudget` on options and verification endpoints   |
| Org Entra sign-in           | `MinimumResponseBudget` on authorization start                  |

New credential endpoints must be added to the contract test. If an endpoint intentionally opts out
of the response budget, it must have an alternate dummy-work or fixed-time verification path that is
visible in tests and documentation.

## Ceremony Cleanup

Sign-in credential ceremonies store short-lived transaction rows keyed by `expires_at`. These rows
are not part of the account-retention `purge_eligible_at` model handled by `RetentionPurgeJob`, so
production recurring cleanup registers the dedicated ceremony transaction purge jobs in
`config/recurring.yml`.

The cleanup contract is intentionally narrow: expired ceremony transaction rows beyond their
retention period may be physically deleted; active and non-expired transactions must remain
available until they either complete, expire, or are superseded by a fresh ceremony. Running the
purge repeatedly is safe because each job scopes deletion to currently purgeable expired rows.

## Signed-In Re-Entry

If a browser already has a Visa session, Auth may inspect an admitted transaction only to decide
whether a credential ceremony is needed. Auth must not create a general session, redirect to a local
product dashboard, or mutate Visa session state.

## OIDC And Token Authority

OIDC authority belongs to Visa.

Visa owns OIDC authorization, token issuance, ID tokens, access tokens, refresh tokens, JWKS, and
downstream token issuance. External RPs own their local callback and session implementation.

## Local sign-in phase admission

Local app sign-in requests that use a DB-backed `SignInFlow` carry a server-generated, purpose-bound
signed binding for the expected surface, flow public identifier, phase, and immutable flow
generation. This binding is an admission check; it is not a replacement for the locked flow row,
actor binding, expiry, provider correlation, or the existing session-issuance boundary.

Same-phase reload is allowed. A GET or HEAD with a missing, malformed, expired, cross-surface,
cross-flow, or contradictory phase binding returns HTTP `409 Conflict` as plain text with the exact
body `この画面は古くなっています。最初からやり直してください。`. It does not redirect, mutate the
flow, issue an OTP or WebAuthn challenge, create a session, or perform another side effect. The
authentication no-store response policy is preserved. This refusal is not a lifecycle edge.

A state-changing request that is bound to the original local flow but uses an obsolete or otherwise
contradictory phase is handled under the flow row lock after a fresh reload. The original flow is
halted with `HALTED = 930` and an auditable reason code (`phase_regression` or `phase_violation`).
HALTED is terminal and absorbing. It cannot be revived, changed to another terminal, or used to
issue a session, OTP, challenge, or provider transaction. An invalid binding is refused without
treating the current session locator as an alternate flow authority, so an old request from flow A
cannot halt a newly started flow B.

The binding applies only where the local `SignInFlow` is the authoritative phase object. Social,
OIDC/Entra, and other provider-owned ceremonies continue to validate their own concrete state,
nonce, PKCE, transaction, and one-shot contracts; they are not forced into a generic sign-in row. No
client-side History API or browser Back detector participates in this security decision.

## Related

- `docs/identity/authority-boundary.md`
- `docs/security/credential-gateway.md`
- `docs/security/ceremony-grant-result.md`
- `docs/security/session-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`
- `docs/security/idp-flow-lifecycle.md`

## Delivered current sequence (2026-10-06)

The active sequence is Visa authorization, an Auth admitted ceremony where needed, Visa
session-limit resolution, and committed Visa session issuance before Visa returns to the registered
external RP. Stale, cancelled, expired, conflicting, and replayed requests are refused or completed
through their explicit terminal transition. The historical sign/id/acme vocabulary above is not an
active authority contract.
