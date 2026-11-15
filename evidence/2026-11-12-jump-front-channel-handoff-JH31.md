# Jump Front-Channel Handoff — Stage 1–3

## Revision and scope

- Repository: Access (`umaxica-apps-cosmos-access`), branch `feature`.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree was already extensively modified and uncommitted by prior authorized work. Those
  changes were preserved. The Access ADR already had uncommitted owner amendments; this stage
  clarified their supersession boundaries and added the Stage 3 design. No commit or push was made.
- Scope completed: investigation, adversarial review, and design only. No Stage 4 runtime
  implementation, route, test, migration, key, peer configuration, deploy, or Cloudflare change.
- No `config/credentials/*.yml.enc`, route, database, or environment configuration file changed.

## A. Current state

### Access

- Access's first-party token migration to PS256 is recorded in
  `evidence/2026-11-12-access-ps256-migration-K8M4.md`. Existing Jump RT issuance and verification
  remain separate from the proposed handoff token.
- `app/values/jump_rt_surface.rb` issues Jump RTs only for Auth and Visa; its receiver-origin list
  adds Base, Core, Warp, and Palm. `app/policies/jump_rt_return_policy.rb` has no Governance
  namespace or directed edge. The current Access Jump contract cannot route to a distinct Governance
  surface as described without an additional owner-approved topology decision.
- No Handoff token type or browser handoff routes exist in Access. The active app/org
  server-delivered revocation endpoints call `GovernanceRevocationCoordinator`, which calls the
  ES384 `GovernanceRevocationCommandVerifier`. Those are remnants of the superseded server-to-server
  design and are proposed for removal only after the replacement contract is accepted.
- The local `SecurityConsumedJti` belongs to `OpBaseAppRecord`; the app/org consumed-JTI models do
  not persist a handoff outcome that could reproduce a registration acknowledgement after a lost
  browser response.
- The Access Rails cookie store is encrypted, host-only, `HttpOnly`, `SameSite=Lax`, and expires
  after 14 days; `Secure` is forced outside development and test. `auth_sid` is a random lookup
  handle and is not suitable as a new consistency secret.
- Six `request.original_url` call sites were reviewed across four files:
  `app/controllers/concerns/jump_rt_return_verification.rb` (2),
  `app/controllers/concerns/op_browser_session_request.rb` (2),
  `app/controllers/concerns/base_oauth_token_endpoint.rb` (1), and
  `app/controllers/concerns/oidc_op_endpoint.rb` (1). They support token/URL verification; this
  review found no new handoff token logging path because no handoff endpoint exists.
- Lograge and span scrubbing redact URL/query data inside Access. This does not establish how the
  browser, Jump, a CDN/proxy, or Governance logs initial requests.

### Governance and Jump

- Governance and Edge Jump source worktrees are not present in this workspace. The work order
  prohibits fetching the old repositories; no network fetch was made. Their current source code and
  configuration could not be independently revalidated for this stage.
- The Jump work order records the Edge limit at revision `0eb2959`: destination URL at most 2,048
  characters and Jump `rt` at most 4,096 characters. It also records the deployed Jump JWKS as
  unavailable (503) until a separate key/configuration rotation. Neither observation was rechecked
  live in this stage.
- Earlier public-snapshot observations are in the PS256 evidence and are dated evidence only; they
  are not represented here as current Governance or Jump state.

## B. Existing contracts

- Jump `rt` remains a signed navigation target and the handoff remains a distinct purpose token.
  Existing `pt` / `nt` / `xt` lanes, the directed graph, and the Jump protocol are unchanged.
  External Jump RT destinations are deprecated for new use; cross-top-level-domain navigation is
  assigned to Away.
- The session binding design keeps each application's own host-only session. It does not add a
  shared `Domain` cookie. Receiver consistency values belong in the receiver's Rails-encrypted
  session or a Rails-signed/encrypted cookie and must also bind to that application's pending
  procedure.
- `adr/access-is-a-pure-openid-provider.md` now marks the prior lookup API, signed-request API
  shape, and pushed revocation command transport as superseded by decision 18. The data-ownership
  table reflects browser-carried exchanges. The new revocation row is explicitly a proposal.
- The ADR amendment records separate sequences for credential lookup, registration, OP data query,
  and authority freshness/revocation; token and key requirements; replay and retry behavior; URL
  cleanup; failure behavior; and the measured revocation bound.

## C. Proposed design

The owning ADR describes a separate, purpose-specific PS256 handoff JWS, encrypted as a nested JWE
when its claims must not be readable by the browser. The profile requires exact `alg`, `typ`, `kid`,
`iss`, `aud`, time, realm, purpose, event, and one-use `jti` checks. No identity result from one app
is itself authentication or authorization at the other. The receiver checks its own browser session,
procedure, object ownership, and local authorization. Access independently verifies each credential
and the Governance-signed current permission before proceeding.

All four current exchanges are high-risk or privacy-sensitive. The proposed design uses a
receiver-issued, session-bound nonce for each and requires the sender to validate its original
per-tab procedure and session. Cross-database writes use receiver-owned idempotency receipts and
repeatable acknowledgements; no distributed transaction is assumed. A negative or absent Governance
answer cannot be withheld to make Access proceed.

A synthetic PS256 JWS was signed in memory with a generated temporary 3,072-bit RSA key and
non-sensitive placeholder claims. It was 1,036 bytes. A 39-byte callback/query prefix produced a
1,075-byte destination URL and left 973 characters under the 2,048-character Jump destination limit.
The temporary key and token were not persisted or printed. JWE overhead and actual credential
records were not measured because there is no agreed payload shape or peer encryption key; the
registration and some lookup payloads therefore have not been shown to fit. The enclosing Jump `rt`
has its separate 4,096-character limit.

The current Access root lifetime gives a proposed maximum stale-authority interval of 30 days for
clients and 8 hours for operators. Active-token and refresh issuance are capped at the root's
absolute `discard_at`; idle windows (8 hours for clients, 30 minutes for operators) may shorten but
cannot extend that interval. The owner accepted a delay until the user's next Access pass, but did
not explicitly accept these numerical bounds or define every boundary that must perform a browser
pull.

## D. Adversarial review

1. **High — no approved Governance Jump identity or edge.** Access cannot currently name a
   Governance issuer/destination in `JumpRtSurface` or the directed return graph. Guessing that
   Governance is Visa/Auth, adding an edge, or using deprecated external Jump mode would cross the
   stated boundaries. No bypass was implemented.
2. **High — signed message mistaken for user authority.** A valid Governance signature cannot
   establish Access authentication or authorize cross-subject OP data. Without a separate
   Access-session check and accepted delegation proof for administrators, Access must refuse
   cross-subject queries.
3. **High — handoff payload may exceed URL limits.** The synthetic minimal request already uses
   about half the destination budget before encryption and credential content. Oversize payloads
   must fail; no truncation, multipart guessing, or server-to-server fallback is allowed.
4. **High — revocation remains bounded by long-lived local authority.** A continuously active client
   can remain stale for up to 30 days and an operator for 8 hours. This follows the current absolute
   root expiry and is not a 5-minute access-token bound. The client bound needs explicit owner
   acceptance.
5. **High — cross-database retry can duplicate or lose registration.** Consuming `jti` alone does
   not preserve a committed result. Governance needs a local atomic operation receipt that can
   reproduce the same acknowledgement; Access must finalize its own flow only once.
6. **Medium — URL observability and history.** Rails scrubbers cover local URL/query fields, but
   query tokens remain visible in browser history and may reach pre-redirect or upstream logs.
   Verify provider logging and never render a page or load third-party assets before token removal.
7. **Medium — browser/session continuity across sites.** The existing Rails session is
   `SameSite=Lax` and host-only. Cross-origin top-level GET behavior and the proposed receiver
   challenge require real-browser verification before rollout; no shared cookie can be used as a
   shortcut.

## E. Work and verification

- Added the Stage 3 design and supersession notes to `adr/access-is-a-pure-openid-provider.md`; did
  not modify application code or the work order.
- Inspected Access Jump surface/edge definitions, cookie policy, consumed-JTI ownership, revocation
  verifier/coordinator/callers, token lifetime and expiry paths, URL redaction, and the four
  exchanges in decision 18.
- Recorded RFC 7515, 7516, 7519, and 8725 as the JOSE design sources in the ADR.
- Synthetic URL-size measurement command (the key was generated in memory; only lengths were
  printed):

  ```bash
  bundle exec ruby -e 'require "jwt"; require "openssl"; key = OpenSSL::PKey::RSA.generate(3072); now = 1_794_355_200; payload = {"iss" => "https://access.example", "aud" => "https://governance.example/handoff", "iat" => now, "exp" => now + 120, "jti" => "a" * 43, "purpose" => "credential.lookup", "event" => "client", "nonce" => "b" * 43, "in_reply_to" => "c" * 43}; token = JWT.encode(payload, key, "PS256", {"typ" => "umaxica-handoff+jwt", "kid" => "sample-ps256-3072"}); puts "synthetic_ps256_jws_bytes=#{token.bytesize}"; puts "synthetic_query_url_bytes=#{"https://access.example/handoff?handoff=".bytesize + token.bytesize}"; puts "jump_url_limit_bytes=2048"; puts "remaining_budget_bytes=#{2048 - "https://access.example/handoff?handoff=".bytesize - token.bytesize}"'
  ```

  Result: JWS 1,036 bytes, callback URL 1,075 bytes, 973 characters remaining. The fixed placeholder
  values contain no customer or secret data.

- `git diff --check`: passed.
- No tests or coverage run: no runtime code changed in this Stage 1–3-only task. Live Jump and
  cross-repository verification were unavailable and were not claimed.
- No config, routes, credentials, keys, database schemas, or migrations changed.

## F. Decisions and follow-up required before implementation

- Approve the actual Governance issuer and receiver origins and the matching Jump identity/edge. The
  local graph has no Governance node, while the work order forbids an unapproved Jump change or
  deprecated external destination.
- Define issuer and JWKS URLs for each realm without guessing them; the old revocation environment
  names do not define the new browser handoff identity.
- Define Access-verifiable authorization for an operator querying or changing another person's OP
  data. Until then, only self-owned OP data may be considered.
- Accept or change the proposed 30-day client / 8-hour operator staleness bounds and specify exactly
  which browser-backed boundaries must pull current Governance permission.
- Approve the per-purpose receiver-challenge round trip, JWE key type and algorithms, publication
  and rotation overlap, and a maximum real credential payload. The query URL measurement is only a
  synthetic lower-bound case.
- Define Governance's pending account/sign-up and cancellation lifecycle so a browser interruption
  cannot leave an unowned partial registration.
- Remove the old app/org push revocation routes, controllers, coordinator, ES384 verifier, and
  command receipts only after the replacement design is accepted and its caller behavior is
  migrated.

These items do not block the next independently scoped work order, but they block Stage 4 handoff
implementation. No implementation has been started.
