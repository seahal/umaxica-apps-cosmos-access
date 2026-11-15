# Front-Channel ID Token Sign-In Evidence

Work order: `plans/2026-11-14-front-channel-id-token-sign-in-work-order.md`.

## Outcome

**Stopped on two items that need owner decisions (one schema design, one contract).** The first
acceptance is not met: Governance's `response_type=id_token` request to the Visa App and Org
authorize endpoints still answers HTTP 503 `temporarily_unavailable` ("Base front-channel ID Token
issuance is unavailable"), as asserted by
`test/integration/visa_authorization_start_boundary_test.rb`. Work items 2 and 5 are complete and
verified. Item 3 is measured but cannot be wired. Item 4 is blocked behind blocker B. The follow-on
order `plans/2026-11-15-auth-sign-in-ceremony-restoration-work-order.md` was not started because its
prerequisite is still unmet.

## Worktree

- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree carries extensive uncommitted work from earlier sessions (954 status entries). The
  inspected and tested behavior depends on it. This session added only this evidence file and a
  measurement script outside the repository (session scratchpad). No code, schema, test or document
  in the repository was changed in this session.
- `git status --short -- config/credentials` and `git diff --name-only -- config/credentials`
  printed nothing. No secret, key, token or environment value was read or printed.

## Resume point: done versus missing (from the diff)

| Item                          | State                                            | Evidence in tree                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ----------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1 Inventory                   | Done here (below)                                | this file                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 2 Client profile              | Done                                             | `authorization_response_type: "id_token"` for `base-app`/`base-org` in `app/values/oidc_client_stores_static_client_store.rb`; `front_channel_id_token?` in `app/values/oidc_client_registry.rb`; resolver accepts `id_token` only for that profile, refuses `code` from Base, refuses PKCE parameters from Base, requires `state` and `nonce`, refuses `id_token token` and Hybrid for all (`app/resolvers/oidc_authorize_request_resolver.rb`) |
| 3 Front-channel issuance      | Not wired (blockers A, B)                        | `app/controllers/concerns/oidc_authorization_start.rb` renders 503 for the profile before allocating a transaction                                                                                                                                                                                                                                                                                                                               |
| 4 Lookup contract             | Not written (blocker B); Base JWKS reader exists | `app/adapters/base_relying_party_jwks_client.rb` and its test                                                                                                                                                                                                                                                                                                                                                                                    |
| 5 Remnants                    | Done for the Token Endpoint                      | Base clients: `unauthorized_client` "Base front-channel clients do not use the Token Endpoint"; other clients' `authorization_code`: `temporarily_unavailable` without any outbound call; operator-capability refresh (former line 133): refused, because no stored capability exists                                                                                                                                                            |
| 6 Sign-up                     | Refusal remains                                  | sign-up routes stay on `UnavailableCeremoniesController` (503); `ClientSignUpFlow`/`OperatorSignUpFlow` raise `GovernanceLookupUnavailableError`                                                                                                                                                                                                                                                                                                 |
| ADR, checklist, Mermaid edits | Done by the previous session                     | `adr/oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md`, `adr/oidc-authorization-request-profile.md`, `docs/checklists/authentication.md`, `docs/mermaid/idp-*-oidc-authorization.mmd`, inventory                                                                                                                                                                                                                                 |
| Static HTTP guard             | Done                                             | `test/security/invariants/base_sign_in_inter_application_http_invariant_test.rb`                                                                                                                                                                                                                                                                                                                                                                 |

## Item 1: inventory of outbound calls on the sign-up and sign-in paths

| Call or lookup                                                                                                                                                                                                                                                                         | Where                                                 | Class                                                                                                  |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Base RP public JWKS GET                                                                                                                                                                                                                                                                | `BaseRelyingPartyJwksClient`                          | JWKS read: allowed                                                                                     |
| Jump `rt` issuance and 303                                                                                                                                                                                                                                                             | `CommonRedirect#redirect_to_jump_url`                 | browser handoff: allowed                                                                               |
| Auth admission handoff (`entry_ref`), result and cancellation references                                                                                                                                                                                                               | `BaseAuthAdmissionCoordinator` (Valkey, Access-owned) | local state, no inter-application call                                                                 |
| Token Endpoint call by Base RP                                                                                                                                                                                                                                                         | Governance to Access                                  | removed for Base (refused at Access)                                                                   |
| "Governance credential lookup" at `authorization_code`                                                                                                                                                                                                                                 | `OidcTokenExchangeCoordinator`                        | the server-side lookup is gone; Base is refused, other clients get `temporarily_unavailable`           |
| Operator capability at refresh                                                                                                                                                                                                                                                         | `OidcTokenExchangeCoordinator`                        | refused; no call                                                                                       |
| `GovernanceLookupUnavailableError` raises in `ClientSignInFlow`/`OperatorSignInFlow` (sign-in authority, evidence verification), `AuthEmailOtpChallenge` (email contact), OTP mailers, SMS job, `StepUpResolver`, `SessionLimitResolutionTransactionable`, `ClientSecretSignInReceipt` | models, mailers, jobs                                 | placeholders for a Governance answer; to be replaced by the lookup contract. No call is made today     |
| Sign-up: `ClientSignUpFlow`, `OperatorSignUpFlow`, `SignUpArtifactCleanup`, `SignUpExpiryJob`                                                                                                                                                                                          | models, services, jobs                                | refusal kept; Governance owns pending registration                                                     |
| Turnstile verification, Google/Apple/Entra adapters, email/SMS providers                                                                                                                                                                                                               | adapters                                              | external provider boundaries, not Access-to-Governance calls (the invariant test documents this split) |

No direct HTTP client other than the Base JWKS client is reachable from the scanned sign-in
controllers and services (static guard green).

## Item 3: measured redirect size

Script: session scratchpad `measure_front_channel_url.rb`, run with
`RAILS_ENV=test bin/rails runner` (prints lengths only). It signs the ID Token through the
repository's own `JitSecurityJwtKeyring` (PS256, test key), with exactly the ADR claim set (`iss`,
`sub`, `aud`, `exp`, `iat`, `auth_time`, `nonce`, `jti`, `sid`, `acr`, `amr`). It builds the
callback with `OidcAuthorizeCoordinator.rp_redirect_url` (adds `iss`) and wraps it with
`JumpRtIssuer` and `RedirectsJumpGatewayUrl`.

| Realm | ID Token | redirect_uri | Destination URL (limit 2048) | `rt` (limit 4096) | Gateway URL |
| ----- | -------- | ------------ | ---------------------------- | ----------------- | ----------- |
| app   | 1,004    | 37           | **1,793**                    | 3,296             | 3,325       |
| org   | 1,004    | 37           | **1,793**                    | 3,296             | 3,325       |

Assumptions that change the numbers: `state` 700 characters (the size observed from Governance);
`sub` as `cli_`/`opr_` plus 21 characters (Governance's real `sub` format is not fixed in this
repository; see blocker B); `sid` 21 characters (the current `OpAppGrant.public_id` length); `amr`
with two values; test-environment issuer origins. The headroom is 255 characters. The difference
from Governance's 1,923-character measurement is unexplained without its token and is not reconciled
here.

## Blockers (stopped items)

### A. An `id_token` authorization transaction cannot be stored (schema)

`client_oidc_authorization_transactions` and `operator_oidc_authorization_transactions` have
`code_challenge` and `code_challenge_method` NOT NULL. The models validate `response_type` in
`["code"]` and `code_challenge_method` in `["S256"]`. `OidcAuthorizationTransactionCoordinator`
reads both PKCE fields with `fetch`. A front-channel request has no PKCE, so the 303 to Auth (the
first acceptance) cannot be reached without a schema change. Options:

1. Move PKCE to a 1:1 child table (`*_oidc_authorization_pkce_challenges`) that only Code
   transactions have. This complies with the AGENTS.md NULL rule. It needs a data move of existing
   rows (a bulk persistence change: risk and recovery-plan approval required). It is reversible with
   a down migration that copies the values back.
2. Make the two columns nullable with a CHECK that ties NULL to `response_type = 'id_token'`.
   Reversible, but NULL would encode "not applicable", which AGENTS.md forbids for persisted state.
3. A separate front-channel transaction table. This duplicates the admission-binding foreign keys
   and the coordinator paths.

Recommendation: option 1.

### B. No OP session exists from which `sid` can come (contract and schema)

- In the current code, `sid` is `OpAppGrant`/`OpOrgGrant.public_id`. The Back-Channel Logout
  participant carries the same value (`OpAuthorityStopCommitter`, `OpLogoutTokenIssuer`). A grant
  requires a root token (`client_tokens`/`operator_tokens`) and a device session.
- HEAD `727cdb560` removed root-login establishment (`log_in`, `login_for_oidc`) and the `Client`
  and `Operator` models. Nothing in `app/` creates a `ClientToken` or `OperatorToken` now.
  `client_tokens.user_id` and `client_device_sessions.user_id` are NOT NULL `bigint`s keyed to the
  removed Access-local account. A Governance `sub` has no column to land in.
- Issuing an ID Token whose `sid` equals a later Logout Token's `sid` therefore needs an owner
  decision on how the OP session is keyed by a Governance subject (column type and format of `sub`,
  migration of the `user_id` keys). That decision also fixes what the lookup contract (item 4) must
  return. Because `sub` is the central claim of that contract, writing the contract first would
  guess it.

### Consequence for item 4

The Base JWKS reader is ready. The handoff shape (purpose, `iss`/`aud`, `typ`, actor and subject
claims, TTL, `jti`, receiver nonce, size) cannot be fixed without the subject format from blocker B.
It was not written into the ADR or `docs/` as a decided contract.

## Normative text the query response mode departs from

OAuth 2.0 Multiple Response Type Encoding Practices, section 3 (`id_token`): "the query encoding
MUST NOT be used." The deviation and its mitigations are recorded in the 2026-11-14 amendment of
`adr/oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md`.

## Tests and checks

| Command                                                                                                                                                                     | Result                                                                                                                                                                     |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bin/rails test` (resolver, client registry, Base JWKS client, HTTP invariant, token exchange service, token exchange boundary, Visa authorization start boundary: 7 files) | first attempt aborted before loading tests: `POSTGRESQL_TEST_PREPARE_DATABASES` lists 10 unverified databases (pre-existing environment state, not caused by this session) |
| same, with `POSTGRESQL_TEST_PREPARE_DATABASES` unset                                                                                                                        | **111 runs, 872 assertions, 0 failures, 0 errors, 0 skips**                                                                                                                |
| zeitwerk, rubocop, erb_lint, brakeman, database_consistency, `bun run check`, full `bin/rails test`                                                                         | **not run**: this session changed no code, so their results would describe the earlier sessions' work, not this order's completion                                         |

The order's Red-first tests for issuance (303 with a verifying ID Token, `sid` equal to the Logout
Token's `sid`, lifetime boundaries at 2 minutes, second completion refused) were not written,
because blockers A and B leave no transaction state for them to drive.

## Owner items

1. Blocker A: choose the PKCE storage shape (recommended: child table) and approve the data move.
2. Blocker B: decide how the OP session (root token, device session, grant) is keyed by the
   Governance `sub`, and fix the `sub` format.
3. After 1 and 2: the lookup contract (item 4), then issuance (item 3) and its tests, then the Auth
   ceremony restoration order.
