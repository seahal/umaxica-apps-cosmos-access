Task (umaxica-apps-cosmos-access, with umaxica-apps-cosmos-governance and umaxica-apps-edge-jump
read for context): investigate, adversarially review and design a signed front-channel handoff
between Access and Governance through the Jump gateway (`jump.umaxica.net`). Implement with TDD only
what this order marks as decided. No commit. Never print secrets or environment values. Never edit
config/credentials/*.yml.enc. Do not deploy or change Cloudflare.

Prerequisite: `plans/2026-11-13-access-ps256-migration-work-order.md` (Access must sign and verify
PS256 only first).

Source: owner's brief of 2026-11-13 (conversation). This order adapts it to the current
repositories; where they differ, this order wins and the difference is stated.

## Status: blocked items first

These conflicts must be resolved by the owner before any implementation beyond Stage 1 to 3
(investigation, review, design). Report them in F; do not resolve them by assumption.

1. **Carrier decided (owner, 2026-11-13):** front channel through Jump replaces server-to-server
   calls (ADR decision 18 amended). Design every exchange in decision 18 for the front channel.
   Decided by the owner (2026-11-13): revocation delay is accepted (effective at the user's next
   pass through Access; propose the bound through Access session and OP token lifetimes and state
   it); pull only (Access asks, fail closed without a valid answer; nothing relies on the user
   delivering an unfavourable message); query parameters are signed JWS and encrypted when the user
   must not read them; consistency-check cookies are Rails encrypted or signed cookies. Size: design
   payloads to stay small (for example look up one credential by ID after the authenticator answers,
   or credential IDs only) and measure against URL limits of browsers, Cloudflare and Jump (observed
   in `umaxica-apps-edge-jump/src/core/verify_jwt.ts` at `0eb2959`: destination URL at most 2048
   characters, `rt` at most 4096; a PS256 signature alone is 512 characters, so the claims budget is
   small). A `Domain` cookie shared by both applications is rejected by the owner; if a payload
   cannot be made small enough, report it with options. Never fall back to a server call.
   Refresh-token requests (native apps, MCP clients) have no browser: propose the refresh token
   lifetime that forces a browser pass, as the revocation bound.
2. **Peer keys (decided, owner 2026-11-13).** Fetching the peer's published JWKS over HTTPS is
   allowed, as already done for Jump: cache it, refetch on an unknown `kid`, fail closed when no
   valid key is available. It is the only server-side read between the two applications; no API
   call. Reuse the existing JWKS client.
3. **Algorithm (decided).** PS256 per `adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md` (Accepted
   2026-11-09; implementation deferred until the split is complete). Observed 2026-11-13: Access
   code is still ES384 everywhere (`lib/jit_security_jwt_keyring.rb`, `lib/jit_security_jwt_jwk.rb`,
   `app/values/security_jwt_jump_rt_token_codec.rb`, `app/values/jump_rt_return_verifier.rb` accepts
   only an ES384 JWKS entry, ID and access token codecs, ceremony contracts). The owner decided a
   complete cut-over of Access to PS256 with no dual period (2026-11-13,
   `plans/2026-11-13-access-ps256-migration-work-order.md`); this order assumes it is done. The
   Handoff JWS is PS256 only. Lifetimes (decided, `adr/token-lifetime-policy-by-surface.md` and
   `app/values/security_token_lifetimes.rb`): access and ID token 5 minutes, client refresh 30 days
   (idle 8 hours), operator refresh 8 hours (idle 30 minutes), Jump `rt` 30 seconds, ceremony
   session 30 minutes. Refresh happens at Access without a browser, so these values alone bound a
   Governance revocation only by the refresh lifetime (30 days client, 8 hours operator). Propose
   the interval at which Access requires a fresh Governance answer through the browser, per surface;
   that interval is the owner's decision. `app/adapters/governance_revocation_command_verifier.rb`
   (server-delivered revocation commands, ES384) belongs to the superseded server-to-server design:
   report its callers and propose removal.
4. **Jump state.** The deployed Jump version currently fails closed (JWKS 503, key/config mismatch)
   until the planned rotation from the other machine. Live end-to-end verification is not possible
   until then; tests are local only.

## Fixed constraints from the brief

- Access and Governance share no database, cookies or sessions; each keeps its own signing private
  key; the peer verifies with the public key.
- Jump only redirects and holds no business state; each application owns its own state and makes its
  own authorization decision after verification.
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
  procedure and its own session; decide per purpose whether the extra round trip is needed by threat
  model, high-risk vs low-risk);
- replay (unique `jti`; reuse `SecurityConsumedJti` if fit; PostgreSQL UNIQUE on purpose + issuer +
  jti digest; consume and commit business state atomically within one database; across databases
  design idempotency and retry instead of assuming a transaction);
- token contract (own `typ`; fixed `alg`; `kid`; strict `iss`, `aud`, `typ`, `purpose`; `purpose`
  and `event` from allow-lists; no internal IDs, personal data, secrets or redirect targets; short
  per-purpose TTL);
- URL safety (where the JWS arrives after Jump returns, removal from the URL with 303 after
  acceptance, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, no token in logs, error
  monitoring or traces; accept that history and pre-redirect logs remain);
- failures (expiry, duplicate `jti`, multiple tabs, Back, interrupted Jump, session expiry on either
  side, key rotation, cancelled procedures, late duplicates, right signature for the wrong procedure
  or another browser); reloads never repeat completed work; "already done" pages never reveal
  another user's state.

Adversarial review: test each property separately (signature, purpose, audience, expiry, single use,
session binding, business acceptance); never conclude "safe because signed". Consult RFC 7515, 7519
and 8725 (and OAuth/OIDC requirements where they connect), per `generic/source-policy.mdc`.
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
