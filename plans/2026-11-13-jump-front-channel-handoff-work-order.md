Task (umaxica-apps-cosmos-access, with umaxica-apps-cosmos-governance and umaxica-apps-edge-jump
read for context): investigate, adversarially review and design a signed front-channel handoff
between Access and Governance through the Jump gateway (`jump.umaxica.net`). Implement with TDD only
what this order marks as decided. No commit. Never print secrets or environment values. Never edit
config/credentials/*.yml.enc. Do not deploy or change Cloudflare.

Source: owner's brief of 2026-11-13 (conversation). This order adapts it to the current
repositories; where they differ, this order wins and the difference is stated.

## Status: blocked items first

These conflicts must be resolved by the owner before any implementation beyond Stage 1 to 3
(investigation, review, design). Report them in F; do not resolve them by assumption.

1. **Carrier decided (owner, 2026-11-13):** front channel through Jump replaces server-to-server
   calls (ADR decision 18 amended). Design every exchange in decision 18 for the front channel.
   Still open for the owner: revocation has no browser present, so propose how and when it takes
   effect (for example at the user's next pass through Access, with short OP token lifetimes) and
   state the exposure window; Lookup during a ceremony becomes a browser round trip each time;
   credential records must fit query-string limits (measure; never fall back to a server call).
2. **Peer keys.** Treat fetching the peer's JWKS as server-to-server unless the owner says
   otherwise: design configuration-distributed public keys with an overlap period for rotation, and
   report the cost.
3. **Algorithm.** Access code uses ES384 (16 references); the Jump gateway moved to PS256
   (RSA 3072) on 2026-11-12 (`umaxica-apps-edge-jump/evidence/2026-11-12-key-rotation-ps256.md`).
   Do not introduce a new algorithm silently; report the current per-token-type algorithms and a
   recommendation.
4. **Jump state.** The deployed Jump version currently fails closed (JWKS 503, key/config mismatch)
   until the planned rotation from the other machine. Live end-to-end verification is not possible
   until then; tests are local only.

## Fixed constraints from the brief

- Access and Governance share no database, cookies or sessions; each keeps its own signing private
  key; the peer verifies with the public key.
- Jump only redirects and holds no business state; each application owns its own state and makes
  its own authorization decision after verification.
- A JWS issued by one application is never by itself authentication or authorization in the other.
- Jump `rt` (where to go) and the Handoff JWS (which procedure, who proves what) are separate token
  types. Keep `pt` / `nt` / `xt` lanes; external origins follow the `xt` rules. Do not change the
  Jump protocol or add a second redirect mechanism.
- Identity attestation transfer is a separate future topic; do not build it here.
- No speculative business events or authentication-result transfer.

## Read first

ADRs in Access: `adr/secure-jump-link-redirector.md`, `adr/redirect-target-lanes-pt-nt-xt.md`,
`adr/signed-return-targets-only.md`, `adr/jump-directed-rails-handoff-contract.md` (check whether it
already covers part of this brief; amend it rather than writing a duplicate),
`adr/jumper-current-boundary.md`, `adr/access-is-a-pure-openid-provider.md` (decisions 8, 12, 14 and
16 to 19), `adr/session-token-hardening-baseline.md`. Jump receiver contract in
`umaxica-apps-edge-jump` (`docs/receiver-contract.md`, `docs/operations/`), and Governance's copy of
the communication research note. Rules AGENTS.md selects for controllers, routes, authentication,
tokens, logging, migrations and tests.

Observed today: Access has `JumpRtIssuer`, `JumpRtReturnVerifier`, `JumpRtReturnVerification`,
`SecurityJwtJumpRtTokenCodec`, `RedirectsJumpGatewayUrl`, `JumpRtReturnPolicy`,
`SecurityConsumedJti`; `Common::Redirect` is absent; `request.original_url` appears in 6 Ruby files
(check each for token leakage). The old repositories named in the brief are not cloned here; use git
history, no network fetch.

## Stage 1 to 3: investigation, review, design

Follow the brief's sections 3 to 7 and 9 for content:

- session binding (receiver-issued nonce bound to its browser session; sender checks the original
  procedure and its own session; decide per purpose whether the extra round trip is needed by
  threat model, high-risk vs low-risk);
- replay (unique `jti`; reuse `SecurityConsumedJti` if fit; PostgreSQL UNIQUE on
  purpose + issuer + jti digest; consume and commit business state atomically within one database;
  across databases design idempotency and retry instead of assuming a transaction);
- token contract (own `typ`; fixed `alg`; `kid`; strict `iss`, `aud`, `typ`, `purpose`; `purpose`
  and `event` from allow-lists; no internal IDs, personal data, secrets or redirect targets; short
  per-purpose TTL);
- URL safety (where the JWS arrives after Jump returns, removal from the URL with 303 after
  acceptance, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, no token in logs, error
  monitoring or traces; accept that history and pre-redirect logs remain);
- failures (expiry, duplicate `jti`, multiple tabs, Back, interrupted Jump, session expiry on
  either side, key rotation, cancelled procedures, late duplicates, right signature for the wrong
  procedure or another browser); reloads never repeat completed work; "already done" pages never
  reveal another user's state.

Adversarial review: test each property separately (signature, purpose, audience, expiry, single
use, session binding, business acceptance); never conclude "safe because signed". Consult RFC 7515,
7519 and 8725 (and OAuth/OIDC requirements where they connect), per `generic/source-policy.mdc`.
Repository files describe weakness classes, preconditions and impact, not attack procedures.

## Stage 4: implementation (only decided parts)

Allowed without further decision: hardening of existing Jump RT handling in Access that the review
shows is defective (for example token values in logs), with Red -> Green -> Refactor, Minitest,
existing Playwright only if browser behaviour changes. Real concurrency for replay races.

Not allowed until the owner confirms the design in C and the open points in items 1 to 3: new
Handoff token type, new endpoints or routes, Governance changes, migrations, key material,
configuration of peer keys.

## Checks and report

bin/rails zeitwerk:check, bin/rubocop, bundle exec erb_lint --lint-all, bundle exec
database_consistency, bun run check, related tests, bin/rails test (separate pre-existing failures).

Record in evidence/YYYY-MM-DD-jump-front-channel-handoff-XXXX.md (full `git rev-parse HEAD`;
uncommitted changes affected results): A. current state (Access, Governance, Jump; reuse
assessment); B. consistency with Jump `rt`, lanes, cookies, ADR decision 18; C. design (sequences
for both directions, state transitions, claims, keys and rotation, errors, idempotency, revocation
limits) in a design document or ADR amendment, not only in evidence; D. adversarial review ranked by
severity; E. implementation plan and verification done; F. owner decisions still needed (only those
the ADRs, code and decided requirements cannot answer). Confirm config/credentials files unchanged.
