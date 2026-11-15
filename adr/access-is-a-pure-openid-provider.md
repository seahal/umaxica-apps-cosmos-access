# Access Is a Pure OpenID Provider: Sign-in and Sign-out Only (2026-11-10)

## Status

Accepted (owner, 2026-11-10), architecture only. Implementation and migration are follow-up work.

Amends `adr/cosmos-identity-authentication-global-authorization-split.md` decision 12 ("Global
stores `sub` and no copy of credentials or profile data") and replaces the Avatar placement in
`docs/architecture/database-authority-placement.md` ("Avatar Boundary"). Other decisions of the
split record stand unless stated below.

Amended 2026-11-11 (owner, after consultation): Identity's source of truth is Governance. Accounts,
`sub`, sign-in identifiers (email addresses, telephone numbers), credentials (passkeys, TOTP,
recovery codes, social sign-in links) and profiles are owned and stored by Governance; Access keeps
none of them and reads what a ceremony needs through the credential lookup. Access keeps the Auth
subdomain and runs the ceremonies there (WebAuthn RP ID and social callback URIs unchanged).
Decisions 2 and 3 below are read with this amendment. Who generates an account and its `sub` during
sign-up, and how a sign-up interrupted between Access and Governance is completed or discarded,
remain open.

## Context

After the Cosmos split, Access (Identity) still carries code and databases beyond authentication:
profile and preference settings, avatars, settings dashboards, notifications and similar features
inherited from the single repository. Each such feature widens what an attacker reaches through the
component that holds credentials and signs tokens, and each one invites the next feature to be added
"because the data is already here".

Jump and Away (`umaxica-apps-edge-away`, `adr/0001-independent-away-responsibility.md`) show the
intended shape: a component with one responsibility, a fixed list of what it does, and no room to
grow into neighbouring work.

## Decision

1. **Access is the sign-in and sign-out component, nothing else.** It is the OpenID Provider and
   OAuth authorization server, and it runs the authentication ceremonies. Its responsibility ends
   when it has authenticated a person, issued or refused tokens, or ended a session.
2. **Access owns only what authentication needs:**
   - OpenID Connect and OAuth endpoints: authorization (with PAR), token, userinfo, JWKS,
     revocation, logout (including back-channel logout to relying parties);
   - ceremony screens: sign-in, sign-up, step-up, credential enrollment and removal reached by
     redirect from a relying party and returning to it, sign-out confirmation;
   - credentials: none stored (amended 2026-11-11); ceremonies verify against records looked up from
     Governance, the source of truth for Identity;
   - OP sessions, DBSC bindings, consent and tokens;
   - client registrations, as code (split record, decision 11);
   - a read-only copy of the signed snapshots Governance publishes;
   - its own audit records (`chronicle`).
3. **Access holds no other data and serves no other behavior.** Profiles, display names, avatar
   images, preferences, avatars and their assignments and memberships, organizations, roles,
   settings dashboards, credential lists, notifications, search and any business data live in
   Governance or in the relying party that uses them. Access does not write, edit or display them.
4. **Governance is where people and operators write such information.** Governance screens are an
   Access relying party (split record, decision 9). When a Governance screen needs an authentication
   ceremony (adding a passkey, changing a sign-in email), it redirects to Access and receives the
   result; it never handles the credential itself.
5. **Token claims beyond authentication come from Governance snapshots.** If a claim such as a
   display name must appear in an ID token, Governance publishes it in a signed snapshot and Access
   copies it into the token without interpreting or editing it. Otherwise relying parties read it
   from Governance by `sub`.
6. **The boundary is enforced by tests, not by convention.** Access keeps allow-lists of its route
   paths, its databases (`config/database.yml`) and its abstract `*Record` classes, guarded by
   static invariant tests (`project/static-invariant-guards.mdc`). A change to any list requires
   amending this record.

## Credential lookup (decided 2026-11-10, transport superseded 2026-11-13)

> **Transport amendment (owner, 2026-11-13):** decision 18 replaces the HTTPS API transport below
> with browser-carried Jump handoffs. The endpoint, Faraday, server-to-server request and response,
> and finite-HTTP-timeout wording below is historical and does not authorize an API. Credential
> ownership, fail-closed behavior, operation-specific permission, and Access's independent
> verification of credential records remain constraints where the Stage 3 design below preserves
> them.

7. **Governance down means no sign-in.** Access keeps no copy or cache of credentials; when
   Governance cannot answer in time, new sign-in, sign-up and step-up fail closed.
8. **Lookups are a server-to-server HTTPS API** (revised 2026-11-11; the earlier browser-carried
   JAR/JARM design is withdrawn). Access calls a Governance endpoint over public HTTPS, the same
   kind of call as PAR and the token endpoint. They share no database and no private network, only
   each other's JWKS. A lookup is:
   - a request signed by Access carrying the lookup key, the flow ID, a nonce, the audience
     (Governance) and a short expiry;
   - a response signed by Governance carrying `sub`, the Access-signed credential records, the
     current permission for the requested operation (account state), the credential versions and,
     for one-time codes, the delivery address;
   - finite timeouts (Faraday through the shared outbound connection); no answer in time means no
     permission. Access verifies Governance's signature, the nonce and flow binding, then its own
     signature on each credential record. Governance refuses lookups without a valid Access
     signature, answers from its primary database, and refuses a credential whose version is lower
     than one it has recorded. Access answers the person the same whether or not an account exists.
9. **Lookup keys.** Passkeys by credential ID; email and telephone one-time codes by a blind index
   that Access computes with a key only Access holds (the address itself is not sent); social
   sign-in by an index of the external `iss` and `sub`. Governance stores addresses encrypted with
   its own key for display and notices.
10. **Passkey records do not change after registration.** Access neither checks nor stores
    `signCount` (WebAuthn leaves counter handling to the relying party; synced passkeys mostly
    report 0) or the Backup State flag (BS), which can change over time. The Backup Eligible flag
    (BE) is fixed at creation and is stored at registration, for a possible later AAL3 policy
    requiring device-bound keys (BE = 0). Sign-in therefore only reads from Governance. Current code
    differs (observed 2026-11-11) and is aligned when credential data moves to Governance, not
    before: `sign_count` is stored and checked at sign-in
    (`app/controllers/concerns/passkey_sign_in_flow.rb`); `backup_state` is stored at registration
    and never updated; `backup_eligible` and `backup_state` are nullable booleans (an existing
    violation of the NOT NULL rule). BE is self-reported (attestation `none`), so it serves display
    and guidance only; an AAL3 policy would need attestation. Only FIDO2 passkeys are accepted:
    registration requires a discoverable credential and user verification, so U2F-only
    authenticators are not supported (owner, 2026-11-11; not deployed, no backward compatibility
    needed). WebAuthn is the only browser API used. Deleted credentials are marked revoked (an
    explicit NOT NULL state), not removed, so a re-inserted old record is detected; decisions read
    from the primary (`docs/backlog/2026-11-11-no-automatic-replica-reads.md`).

## Why the Auth ceremonies stay in Access (decided 2026-11-11)

With Identity's source of truth in Governance, two placements were compared:

|                                   | A. Auth in Access (chosen)                                                                                                                                           | B. Auth in Governance (Ory Hydra + Kratos shape)                    |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Where a passkey is verified       | Access, with records looked up from Governance                                                                                                                       | Governance, against its own database                                |
| Access <-> Governance             | lookup, registration write, permission, revocation                                                                                                                   | an authentication result per login challenge                        |
| Size of Access                    | larger (ceremonies)                                                                                                                                                  | smallest (protocol and tokens)                                      |
| Effect of a Governance compromise | no impersonation: Access rejects credential records without its own signature; an attacker can deny, delete or roll back, which revocation state and versions detect | impersonation of anyone: Access trusts Governance's "this is sub X" |

The URL is not the deciding factor: `auth.umaxica.*` could be served by either deployment, and
nothing is deployed yet. The deciding factor is that impersonation must require compromising both
Access (its signing key) and Governance. This is the consultation's purpose (limit how far a
compromise of one side spreads) and its rule that Access never skips its own WebAuthn verification
even with Governance's permission. B's simplicity is rejected because Governance is a large
application with administration screens.

14. **Auth stays in Access.** Access runs every ceremony (WebAuthn, social sign-in callbacks,
    step-up, one-time codes) and verifies it itself. Governance stores the records and grants
    permission; it never verifies a credential on Access's behalf.
15. **Credential records are signed by Access with a dedicated key.** Passkey records (credential
    ID, `sub`, public key, BE, version, realm) and social sign-in links (external `iss` and `sub`,
    `sub`) are signed at registration with an Access key used only for credential records, separate
    from token signing keys. On rotation the old public keys stay available for verification only,
    or all records are re-signed; the choice is part of key-rotation design.
16. **One exchange shape for all Access <-> Governance calls (transport superseded 2026-11-13).**
    Lookup and registration (Access to Governance) and revocation commands (Governance to Access)
    share one component: a signed request with an ID, a signed response, finite timeouts, idempotent
    handling of a repeated ID, and no success until the signed acknowledgement is verified. A
    registration exists only after Governance's acknowledgement; an interrupted registration is
    retried with the same ID or discarded.

Feasibility and order (2026-11-11). Existing parts are reused: `OutboundHttp::Connection` (Faraday),
the `jwt` gem and JWKS publication, consumed-`jti` tables, the current WebAuthn verification and the
per-tab flow handle (`adr/browser-flow-handle-per-tab.md`). Hard parts: sign-up interrupted between
Access and Governance (Governance creates the account and `sub`; when unfinished sign-ups are purged
is open), long-lived signatures across key rotation (decision 15), and tests spanning two
repositories (both run in development through their tunnels; the OIDC side is checked with
`umaxica-apps-mock-oidc` and the OpenID conformance suite). Build one thin slice first and widen:

1. App-realm passkey sign-in through the lookup API, against records already in Governance.
2. Passkey registration (sign, store, verify the acknowledgement).
3. Revocation commands from Governance.
4. Social sign-in, email and telephone one-time codes, the org realm, sign-up.
5. Clean-up: drop `sign_count` and `backup_state`, move Valkey state to PostgreSQL.

## Revocation commands from Governance (push design superseded 2026-11-13)

> Decision 18 supersedes the push command transport and this section's Governance-to-Access actor
> authority model. The Access-local requirement to revoke only Access-owned state remains. The
> replacement pull authorization contract is proposed in the Stage 3 design above and is not yet an
> implementation contract.

11. **Governance commands, Access executes.** Refresh tokens and OP sessions live in Access, so only
    Access can revoke them. Governance decides (PDP) and sends a revocation command; Access does not
    ask Governance on each refresh. Sources of a command: the person themselves (Governance app
    screens, own sessions only), an operator (Governance org admin screens, a client's app
    sessions), and a senior operator (another operator's org sessions). Operator commands require
    step-up at Access before they are issued.
12. **Transport: HTTPS API, not a shared database.** Governance calls an Access endpoint over public
    HTTPS with a request signed by Governance and verified against Governance's JWKS, with finite
    timeouts (Faraday). Access never exposes its database to Governance (split record, decision 12
    stands). A message queue may replace the HTTPS call later if the deployment cannot carry it; the
    command and acknowledgement contents stay the same.
13. **Success only on a signed acknowledgement.** A command carries an ID, realm, target `sub`,
    scope (all sessions or one), actor and reason. Access executes it once per ID (a resend is a
    no-op), records it in its audit records, and returns an acknowledgement signed by Access naming
    the command ID. Governance shows success only after verifying that acknowledgement; on timeout,
    error or an invalid acknowledgement it shows "not completed" and offers a resend with the same
    ID. Success means Access's refresh tokens and OP sessions for the target are revoked;
    back-channel logout to relying parties follows asynchronously, and already issued access tokens
    expire within their lifetime (5 minutes).

This replaces, for refresh, the consultation's row "refresh denied while Governance is unavailable":
refresh is not gated by a Governance query; revocation reaches Access as a command whose completion
is visible and retryable. New sign-in, sign-up and step-up still require Governance's permission and
fail closed without it.

## Data ownership and exchanges (summary, owner 2026-11-12)

17. **Access owns OpenID Provider data only; Governance owns everything else.**

| Data                                                                                                                                                                                                                             | Owner          | The other side reads it by                                             |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ---------------------------------------------------------------------- |
| OP sessions, authorization codes, PAR requests, refresh token families, access token state, DBSC bindings, consents and grants to relying parties (including MCP clients), client registrations (code), OP audit records         | **Access**     | Governance asks Access through a browser-carried handoff (decision 18) |
| Accounts and `sub`, email addresses and telephone numbers, credential records (passkeys, TOTP, recovery codes, social links; signed by Access), account state, profiles, avatars, preferences, organizations, memberships, roles | **Governance** | Access asks Governance through a browser-carried handoff (decision 18) |

18. **Exchanges.** This decision supersedes the server-to-server carrier and acknowledgement
    mechanics in decisions 8, 11 to 13, and 16. Those decisions remain historical context for data
    ownership, local Access revocation, signed credential records, and retry semantics; they do not
    authorize direct application HTTP calls. Every exchange is a browser-carried handoff. **Front
    channel only, no server-to-server calls (owner, 2026-11-13; supersedes the same-day HTTPS
    entry).** Access and Governance exchange signed handoff JWS carried by the user's browser
    through the Jump gateway (GET query parameters, Jump `rt` for navigation), never by direct HTTP
    between the two applications. Design and threat model:
    `plans/2026-11-13-jump-front-channel-handoff-work-order.md`. Owner decisions (2026-11-13): (a)
    **revocation delay is accepted**: with no browser present, revocation takes effect at the user's
    next pass through Access; the bound on that delay (Access session and OP token lifetimes) is set
    in the design; (b) **pull only**: Access asks Governance and proceeds only on a valid answer; no
    exchange depends on the browser delivering a message the user would prefer to withhold; (c)
    **browser-held values are protected**: query parameters carry signed JWS, and encrypted when the
    content must not be readable by the user; cookies used for consistency checks are Rails
    encrypted (or signed) cookies, never plain. (d) **payloads are designed small** (for example one
    credential per lookup); a `Domain` cookie shared by both applications is rejected. Reasons for
    the front channel (owner): no in-house know-how for service-to-service APIs, their additional
    security design, and the tight coupling between servers; the browser absorbs the exchange.
    Future OIDC clients (Android, iOS, MCP) authorize through a browser, so the carrier still
    exists; requests without a browser (token refresh) cannot consult Governance, so their staleness
    is bounded by token lifetimes under (a). (e) **JWKS fetch is allowed**: each application reads
    the peer's published JWKS over HTTPS (cached, refetched on an unknown `kid`), as already done
    for Jump; this public static document is the only server-side read between the two, and no API
    is called. **Sign-up and sign-in (owner, 2026-11-14):** this holds for the OIDC leg as well. The
    Base relying parties do not call the Token Endpoint, UserInfo or any other OP API during sign-up
    or sign-in; the OP returns the ID Token through the front channel
    (`adr/oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md`, amendment of
    2026-11-14), and the OP never consults Governance outside a browser-carried handoff. Everything
    the ID Token states is obtained during the ceremony while the browser is present. The ownership
    in decision 17 and the exchanges below are unchanged; only their carrier changes.

| Exchange                                  | Direction            | When                                                                                                      | Content                                                                                                              |
| ----------------------------------------- | -------------------- | --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Lookup                                    | Access -> Governance | each ceremony (mainly in Auth)                                                                            | credential records and the current permission for the operation                                                      |
| Registration                              | Access -> Governance | after a ceremony that adds or changes a credential                                                        | the credential record signed by Access; success only after Governance's signed acknowledgement                       |
| OP data query                             | Governance -> Access | when Governance shows or manages OP data (for example a person's signed-in sessions or connected clients) | read-only answers about the OP data listed above; Access shows no lists itself                                       |
| Proposed authority freshness / revocation | Access -> Governance | a browser-backed Access authentication or authorization boundary that needs current account permission    | current account and operation permission; Access applies any resulting change to its own sessions, grants, or tokens |

### Front-channel handoff design review (Stage 1–3, 2026-11-12)

**Status: design proposal, not implementation approval.** This section records the Stage 1–3
investigation and security review. The owner has decided the carrier, PS256, peer-JWKS fetch,
pull-only behavior, encrypted browser-held cookies, and that sensitive query payloads are encrypted
when the browser must not read them. The wire shape, endpoint topology, per-purpose nonce round
trips, peer encryption keys, operation authorization, and payload-size feasibility still require an
accepted implementation contract. No endpoint, route, key, migration, or runtime behavior is
authorized by this section.

#### Common message contract

- Keep Jump `rt` as the short-lived navigation instruction. Carry the handoff separately in one
  scalar, purpose-specific query parameter inside the signed destination URL. Never put the handoff
  token inside `rt`, use a raw return URL as a redirect target, add a second redirect mechanism, or
  change Jump's `pt` / `nt` / `xt` lanes.
- The sender's PS256 JWS is an integrity and issuer-authentication envelope, not proof that the
  person is authenticated or authorized at the receiving application. The receiver must verify its
  own browser-bound procedure, session, target ownership, and authorization before returning data or
  changing state. An Access ceremony must still verify the credential itself; a Governance response
  cannot assert an authentication result on Access's behalf.
- Existing OAuth and OpenID Connect protocol state remains separate from this handoff. Where a
  protocol flow uses `state`, `nonce`, PKCE, PAR, a registered `redirect_uri`, or a callback, its
  existing protocol validation remains required. The handoff challenge, `jti`, operation ID, or
  signature cannot replace or satisfy those checks. The handoff carries only its own bounded
  operation and re-enters the still-pending protocol procedure. See
  [RFC 6749](https://www.rfc-editor.org/rfc/rfc6749.html),
  [RFC 7636](https://www.rfc-editor.org/rfc/rfc7636.html),
  [RFC 9126](https://www.rfc-editor.org/rfc/rfc9126.html),
  [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html), and
  [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html).
- Require an exact protected-header allow-list containing `alg=PS256`, a handoff-specific `typ`, and
  a known `kid`; reject header-selected key locations, critical extensions, or other algorithms.
  Validate exact configured `iss`, one exact `aud`, `iat`, `exp`, a random one-use `jti`, realm,
  purpose, and event against per-exchange allow-lists. Reject unknown fields, duplicate or nested
  handoff parameters, wrong types, wrong procedure, and a response whose `in_reply_to` does not
  identify the current request. A two-minute maximum lifetime is proposed for handoff messages;
  shorter per-purpose limits may be used. No leeway may make an expired message valid beyond its
  declared lifetime plus the separately documented clock-skew allowance.
- Claims contain only the fields needed for one operation: an opaque per-flow reference, receiver
  challenge, correlation to the exact request, and the smallest operation payload. They contain no
  database primary keys, email/telephone address, raw credential, session cookie, private key,
  authorization bearer, or redirect target. Credential IDs and public-key records are still
  sensitive linkable data; encrypt them when they must cross the browser.
- Sign first and, where confidentiality is required, encrypt the signed JWT as a nested JWE to a
  distinct receiver encryption key. Do not use a PS256 signing key for decryption. A separate
  published encryption key, protected-header allow-list, and peer JWKS handling are required. A
  candidate profile is RSA-OAEP-256 with A256GCM, but key type and algorithm remain owner decisions
  until the actual payload is measured. The JOSE profiles must follow
  [RFC 7515](https://www.rfc-editor.org/rfc/rfc7515.html),
  [RFC 7516](https://www.rfc-editor.org/rfc/rfc7516.html),
  [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519.html), and
  [RFC 8725](https://www.rfc-editor.org/rfc/rfc8725.html), including fixed algorithm selection,
  issuer and audience checks, explicit typing, and mutually exclusive validation rules.
- Publish only peer public keys. Retain a signing or encryption key through the maximum token
  lifetime plus the configured JWKS/CDN stale window; after an unknown `kid`, refetch the peer JWKS
  once and fail closed if no unambiguous valid key is available. Never fall back to a cached account
  or credential answer.

#### Browser and session binding

Each application keeps its own host-only Rails session and its own pending procedure state. The
Rails cookie store is encrypted, `HttpOnly`, `SameSite=Lax`, and has no `Domain`; it is `Secure`
outside development and test. A new handoff consistency value belongs in that application's
encrypted session (or a Rails-signed/encrypted cookie), paired with its existing server-side
procedure record. The existing random-only `auth_sid` is a lookup handle, not an encrypted
consistency value. No cookie is shared between Access and Governance.

The receiver issues a random, single-use nonce bound to its own session and pending procedure. The
sender stores its original per-tab procedure handle and verifies that its current session still owns
that procedure before accepting a response. The nonce is a correlation value, never a substitute for
session or identity proof. A response is accepted only when both the receiver challenge and the
sender's still-current procedure match; cancellation, expiry, session reset, or a different browser
invalidates it. Reloads and Back must not repeat a completed mutation.

All four current exchanges affect authentication, credentials, account state, authorization, or
private OP data. The review therefore recommends the receiver-challenge round trip for each:
credential lookup, credential registration, OP data query, and authority freshness/revocation. There
is no currently identified low-risk exchange for which omitting receiver session binding is
justified. This adds a browser visit before the data-bearing handoff and increases redirects; the
per-purpose decision and browser compatibility need owner acceptance before implementation.

#### Exchange sequences and state ownership

1. **Credential lookup (Access -> Governance).** Access starts or resumes its own ceremony and
   stores the per-tab flow reference and state. The browser first obtains a Governance challenge
   bound to Governance's own session. Access then issues a short-lived PS256 request through Jump,
   containing the challenge and only the requested credential reference. Governance verifies the
   request, its nonce and browser session, reads its authoritative credential and current operation
   permission, and returns a signed response; credential material is encrypted to Access. Access
   verifies the reply's issuer, audience, signature, `in_reply_to`, challenge, time, purpose, and
   unused `jti`, then independently verifies Access's signature/version on any credential record and
   performs the ceremony's cryptographic check. An unavailable, invalid, negative, expired, or
   withheld answer fails closed. Nothing is inferred from an absent reply.
2. **Credential registration (Access -> Governance).** Governance first establishes its own
   session-bound challenge and account-side pending operation. Access completes its existing
   ceremony, independently verifies the credential, signs the credential record with the dedicated
   record-signing key, and returns a registration handoff through Jump. Governance verifies that
   signature and its local account/session authorization, then writes the credential and an
   idempotency receipt in one Governance database transaction. It returns a signed acknowledgement
   only after that commit. Access completes only after verifying the acknowledgement and matching
   the original Access flow. A lost acknowledgement leaves Access pending; retry uses the same
   operation ID and Governance returns the same committed outcome without applying the write twice.
3. **OP data query (Governance -> Access).** Governance's own session and authorization initiate one
   narrowly scoped query and a receiver-bound Access challenge. Access verifies the request, checks
   its own browser/session and current OP ownership rules, and returns only the requested read-only
   answer, encrypted when it is private. Governance verifies and correlates the reply before
   rendering. A Governance signature alone cannot authorize Access to reveal another person's or
   operator's data. The current repository has no accepted delegation contract for an administrator
   querying another person's OP data; Access must refuse that case until one exists.
4. **Authority freshness / revocation.** The proposed replacement for pushed revocation commands is
   an Access-initiated, browser-carried pull of current Governance account state at each accepted
   authentication or authorization boundary that requires fresh permission. Access proceeds only on
   a valid affirmative response; a negative, missing, expired, or unavailable response cannot be
   withheld to make Access proceed. Access applies revocation only to Access-owned state and commits
   that local change with the accepted response's replay receipt. A browser that never returns the
   response can still delay a decision until its existing Access authority expires; the system must
   never report a Governance action as completed merely because it launched Jump.

Each receiver consumes the incoming `jti` in the same local PostgreSQL transaction as its business
mutation. The unique key is `(purpose, issuer, jti_digest)` with a digest of the token ID; the raw
token and raw `jti` are not persisted. No cross-database transaction is assumed. A mutation that
commits at one application before its acknowledgement reaches the other must be retryable by the
same opaque operation ID, with a receiver-owned receipt sufficient to reproduce the same signed
acknowledgement. `SecurityConsumedJti` has an app-only owner and records consumption but not a
replayable result; by itself it does not satisfy the org realm or registration acknowledgement
contract. `OpAppConsumedJti` and `OpOrgConsumedJti` are realm-owned, add an OIDC client identifier
to their uniqueness scope, and do not store handoff outcomes. A handoff receipt design must
therefore be selected before implementation rather than treating any existing consumed-JTI table as
a universal ledger.

#### URL, response, and failure behavior

The receiver must verify a handoff on a non-rendering endpoint, then answer with `303 See Other` to
the same allowlisted local path with the handoff query removed. Both acceptance and rejection
responses set `Cache-Control: no-store` and `Referrer-Policy: no-referrer`. No page may load
third-party resources before the redirect. Access's current Lograge and span scrubbers redact URL
and query attributes, but this does not control browser history, the initial request at the browser
or Jump, a CDN/proxy log, or another application's logging. Those boundaries require verification
before rollout; the receiver must never put token values, query strings, decrypted claims, or raw
exception messages in application logs, error monitoring, or traces.

Expired, duplicate, malformed, wrong-purpose, wrong-audience, wrong-procedure, wrong-session,
cancelled, or cross-browser handoffs fail closed with a generic refusal or explicit unavailable
response. A replay of a committed idempotent registration may return its same signed acknowledgement
without reapplying the mutation; it never returns another user's state. Parallel tabs use separate
flow references and challenges. A late response after cancellation or completion is refused. A
session reset invalidates outstanding challenges. If Jump or peer JWKS is unavailable, the operation
does not continue with stale identity data.

#### Revocation exposure bound

Current Access code sets the absolute root-token lifetime to 30 days for clients and 8 hours for
operators, with idle windows of 8 hours and 30 minutes respectively. Browser and OIDC access tokens
are capped at the root token's `discard_at`, and refresh rotation retains that same absolute
deadline. Therefore the current maximum stale-authority interval for a continuously active client is
30 days and for an operator is 8 hours, measured from Governance changing the account state until
the Access root expires; the 5-minute access/ID JWT limit does not add to that bound because newly
issued tokens cannot exceed the root deadline. The idle window can shorten, but not lengthen, it.
After expiry, refresh cannot create a new root; the next operation that establishes a root or grants
new authorization must obtain a valid Governance answer through a browser. Whether every relevant
boundary already does that is unverified. This is the proposed bound implied by current code, not
evidence that the owner has accepted the resulting 30-day client interval. Confirm that bound and
which browser-backed authorization boundaries require a pull before implementation.

#### Current blockers and unresolved decisions

- The local `JumpRtSurface` and `JumpRtReturnPolicy::EDGE_CATALOG` define Auth, Visa, Base, Core,
  Warp, and Palm, but no Governance issuer or destination. `JumpRtIssuer` only supports Auth and
  Visa issuers. Governance is also not a configured Access surface in this checkout. The current
  Jump graph therefore cannot express a Governance <-> Access handoff as described without an
  owner-approved identity/edge addition. An external Jump RT destination is deprecated for new use,
  and cross-TLD navigation is assigned to Away. The design must not alias Governance to Visa/Auth,
  add a Jump edge, or use deprecated external mode by assumption.
- The app and org revocation endpoints call `GovernanceRevocationCoordinator`, which calls the ES384
  `GovernanceRevocationCommandVerifier`; these are remnants of the superseded server-to-server
  command design. Propose removing the verifier, coordinator, routes, controllers, and command
  receipt/acknowledgement code after this front-channel contract is accepted. They are not removed
  in this Stage 3 review.
- The app registration example leaves only about 973 characters of total destination-URL headroom
  after a synthetic minimal 3,072-bit PS256 request JWS (1,036 bytes) and a 39-byte callback prefix
  under Jump's 2,048-character destination limit. JWE overhead and a real credential record reduce
  that margin; the enclosing Jump `rt` must independently fit its 4,096-character limit. No peer
  encryption key or real maximum credential payload is available in this checkout, so registration
  and some credential lookups are not yet demonstrated to fit. Do not truncate or split claims;
  report the measured oversize and obtain an owner decision among a smaller data contract, a browser
  form-post contract, or stopping that exchange. A server-to-server fallback is rejected.
- The Access repo does not establish Governance's fixed issuer/JWKS origins, receiver route names,
  the authorization proof for an operator acting on another person's data, the JWE key profile, or
  whether a second browser visit for each high-risk exchange is accepted. Existing revocation
  `ENV.fetch` names do not establish the handoff identities or Jump destinations.
- Credential sign-up ownership and cleanup after interruption remain open in the parent ADR. A
  browser handoff cannot make account creation and Access registration atomic across two databases;
  Governance must own the pending account, expiry, retry, and cancellation state before sign-up is
  enabled.

19. **Credential changes run through the browser and Access, then land in Governance.** To add a
    passkey or link a social account, Governance redirects the browser to an Access ceremony; Access
    verifies, signs the record and registers it in Governance; the browser returns to Governance.
    Governance never writes a credential on its own. To remove a credential, Governance marks its
    own record revoked so later lookups refuse it. The earlier instruction to send an immediate
    server-to-server revocation command is superseded by decision 18; Access may change only its own
    state after a valid current Governance answer under the handoff contract and its accepted
    revocation bound.

## Handoff decisions (owner, 2026-11-14)

These answer the owner items of the Stage 1–3 review
(`evidence/2026-11-12-jump-front-channel-handoff-JH31.md`, section F) and unblock Stage 4 design
where stated.

- **Route identity and issuers.** The Jump nodes and edges already exist and are used as they are:
  `auth-app-ww` ↔ `base-app-ww` and `auth-org-ww` ↔ `base-org-ww`, both directions. Each node's
  issuer is its origin (`https://www.umaxica.app`, `https://www.umaxica.org`,
  `https://auth.umaxica.app`, `https://auth.umaxica.org`); no new Jump node or edge is needed. The
  peer key source is the issuer's existing `/.well-known/jwks.json`; no new JWKS URL is introduced.
  Access's own allow-lists still have to accept Base as a handoff peer, not only as a relying party;
  that is Stage 4 work.
- **Cross-subject operations.** Only the person themself for now. Handoff tokens carry the acting
  principal and the subject as separate claims, and the receiver refuses any token where they
  differ. Operator delegation can be added later by defining how that difference is proved, without
  changing the token shape.
- **Revocation bound.** The proposed staleness bounds are accepted: 30 days for clients and 8 hours
  for operators.
- **Signing and encryption.** Handoff JWS stay PS256 only. Encryption is used only where the design
  shows a payload the user must not read. Where it is needed, the profile is RSA-OAEP-256 with
  A256GCM, using a separate RSA key per receiver published in the same JWKS with `use: enc`; a
  signing key is never used for encryption. Payloads are designed first so that encryption is
  avoided where possible.
- **Pending sign-up lifecycle.** Governance owns it. The design (start, identifier claim, credential
  delivery, completion, cancellation, expiry, interruption at every step) comes before Stage 4 is
  implemented, in Governance's
  `plans/2026-11-14-pending-registration-lifecycle-design-work-order.md`.
- **Push revocation removal.** The old push path (routes, controllers, coordinator, ES384 verifier,
  receipt tables) is removed now, ahead of the replacement, because it is already broken and the
  repository is being reset (`plans/2026-11-14-governance-revocation-push-removal-work-order.md`).
  Until the pull contract exists, Governance has no way to revoke Access sessions or refresh tokens.

## Consequences

- Access loses its settings, profile and avatar code and databases. Features still needed move to
  Governance (or a relying party) before or with the removal; features nobody needs are deleted.
- Account deletion and other lifecycle changes flow both ways as events: Access to Governance for
  credentials and sessions, Governance to Access for snapshot data it no longer publishes.
- Access becomes smaller to review and to harden; the component that signs tokens has no features
  unrelated to signing them.
- Relying parties that need profile data make a Governance read or rely on snapshot-derived claims.

## OP session and transaction storage decisions (owner, 2026-11-15)

Taken after `evidence/2026-11-14-front-channel-id-token-sign-in-B3T8.md` stopped on two items.

- **Subject.** `sub` is the Governance account's public identifier: `Client.public_id` in the App
  realm, `Operator.public_id` in the Org realm (strings). The realm is given by the issuer, not by a
  prefix inside `sub`. Actor and subject stay separate claims and are equal for now.
- **OP session keying.** Root tokens (`client_tokens`, `operator_tokens`), device sessions and
  grants (`OpAppGrant`, `OpOrgGrant`) are keyed by a per-realm `subject_public_id` string column,
  NOT NULL, instead of the `user_id` bigint that pointed at the Access-local accounts removed on
  2026-11-13 (`727cdb560`). Access holds no foreign key to Governance; it records the identifier
  that the lookup handoff delivered. `sid` remains the grant's `public_id`, so the ID Token and a
  later Logout Token carry the same `sid`.
- **Existing rows.** Rows keyed to removed accounts have no owner and are discarded in development
  and test as part of the hard reset. The migrations are reversible in structure; discarded rows are
  not restored. No production database is migrated by this decision.
- **Authorization transactions.** PKCE moves to a 1:1 child table
  (`client_oidc_authorization_pkce_challenges`, `operator_oidc_authorization_pkce_challenges`) with
  NOT NULL columns, present only for Code transactions. The transaction tables lose `code_challenge`
  and `code_challenge_method`; `response_type` admits `code` and `id_token`. Transactions are
  short-lived: in-flight rows are moved into the child table and expired rows may be discarded. A
  nullable PKCE column and a separate front-channel transaction table were rejected (NULL as "not
  applicable"; duplicated paths).
- **Lookup contract.** With `sub` fixed, the sign-in lookup handoff returns the Governance public
  identifier as `sub` (and `act`), and Access stores it on the transaction and the OP session.

## Rejected Alternatives

- **Keeping profile and avatar data in Access for convenience.** It keeps unrelated writers next to
  credentials and token signing, and it is the path by which Access grew beyond authentication.
- **Governance storing copies of credentials or sign-in identifiers.** It would add a second place
  where credentials leak; ceremonies stay in Access only.
- **A written rule without tests.** Allow-lists without enforcement drift as the split record's
  unenforced boundaries did.

## Open Questions

- Whether Access remains the policy decision point for common authorization (split record,
  decision 2) by evaluating Governance snapshots, or only enforces authentication strength and
  leaves all authorization to relying parties.
- Which existing databases move to Governance (`avatar`, `*_setting`, parts of the principal and
  `zenith` stores) and which are deleted; recorded in the database ownership inventory.
- The snapshot fields Access accepts for token claims, and their maximum age.
- Per-purpose receiver challenge round trips, the payload-size contract, and the exact
  browser-backed authorization boundaries at which Access must pull current Governance permission.
  Issuers, JWKS, the encryption profile, delegation and the revocation bound were decided on
  2026-11-14 (see "Handoff decisions").
- The pending sign-up lifecycle details (deadline, duplicate pending identifiers), to be designed in
  Governance per the 2026-11-14 decision.
- Service-to-service alternatives in
  `research/2026-11-12-access-governance-service-communication-options.md` are historical after
  decision 18's front-channel choice; they are not current transport options.

## References

- W3C Web Authentication (signature counter, BE and BS flags): https://www.w3.org/TR/webauthn-3/
- RFC 7519, JSON Web Token (claim names): https://www.rfc-editor.org/rfc/rfc7519.html
