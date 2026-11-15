Task (umaxica-apps-cosmos-access only): make sign-up and sign-in free of server-side calls between
applications, apart from JWKS reads. The OP returns the ID Token to the first-party Base relying
parties through the front channel, and nothing the ID Token states is looked up after the browser
has left. No commit. Never print secrets, key material, tokens or environment values. Never edit
config/credentials/*.yml.enc. No push, no deploy, no Cloudflare change, no change outside this
repository.

## Decision (owner, 2026-11-14; do not reopen)

- During sign-up and sign-in, no application makes a server-side call to another except reading the
  peer's published JWKS. Owner quote: "jwks のパラメタ確認をする以外では、sign up/in で api と
  かを参照するのは禁止". Recorded in `adr/access-is-a-pure-openid-provider.md` decision 18 (e) and
  in the 2026-11-14 amendment of
  `adr/oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md` (read both first; they hold
  the profile, the claim list and the mitigations).
- `base-app-ww` and `base-org-ww` use `response_type=id_token`, query parameter through Jump, no
  Access or Refresh Token. Every other client keeps Code + PKCE S256 + Token Endpoint. Discovery
  keeps `response_types_supported: ["code"]`.
- Handoff decisions of the same day ("Handoff decisions (owner, 2026-11-14)" in the first ADR): Jump
  nodes and edges `auth-*-ww` ↔ `base-*-ww` already exist; peer keys come from the existing
  `/.well-known/jwks.json`; PS256 only; actor and subject are separate claims and must be equal for
  now; encryption only where the design proves it is needed.
- Scope is sign-up and sign-in. Sign-out (RFC 7009 call, back-channel logout) is out of scope; do
  not change it.

## Observed on 2026-11-14

- Governance's Base App sends `client_id=base-app-ww`, `response_type=code`, PKCE S256, `nonce`,
  `state` (PS256 JWS, about 700 characters), `ri`, `scope=openid profile`, `rt`; it will switch to
  `response_type=id_token` without PKCE under a matching Governance order. Its callback is
  `/oidc/callback` on `https://www.umaxica.app` and `https://www.umaxica.org`.
- `app/services/oidc_token_exchange_coordinator.rb` refuses every `authorization_code` grant with
  `temporarily_unavailable` ("Governance credential lookup is unavailable", line 42), and refuses
  refresh for clients with an operator capability (line 133). `sign_up_artifact_cleanup.rb` and
  `base_auth_admission_coordinator.rb` (around line 1380) raise "Governance … unavailable". These
  are remnants of a server-side Governance lookup.
- The Visa authorization endpoints (App and Org) were reopened today up to the 303 through Jump to
  Auth `/sign/in/sentry`, which still answers 503.
- Jump limits: destination URL at most 2048 characters, `rt` at most 4096. A PS256 signature is 512
  base64url characters.

## Work

1. **Inventory** every outbound call or lookup on the sign-up and sign-in paths (authorize, Auth
   ceremonies, result hand-back, token issuance) and classify it: JWKS read (allowed), browser
   handoff (allowed), anything else (to remove). Include the remnants above.
2. **Client profile.** Register the front-channel ID Token profile for `base-app-ww` and
   `base-org-ww` only, in the client registry (no new environment variable). The resolver accepts
   `response_type=id_token` only for clients registered with it, requires `nonce` and `state`,
   refuses PKCE parameters for them, and still refuses `id_token token` and every Hybrid type for
   all clients. A Base client sending `code` is refused (no dual period).
3. **Front-channel issuance.** When the authorization transaction reaches the authenticated state,
   the OP builds the ID Token with exactly the claim set in the ADR amendment (including `sid`, the
   OP session identifier that Back-Channel Logout already carries), lifetime at most 2 minutes,
   unique `jti`, and returns it with `state` and `iss` to the registered `redirect_uri` through Jump
   with 303. The transaction moves to completed atomically with issuance; a second completion is
   refused. Measure the full redirect URL for both realms and report the numbers; if it does not
   fit, stop and report options.
4. **Sign-in lookup contract (design, then implement what is decided).** Define the browser handoff
   by which Auth obtains, while the browser is present, what the ceremony and the ID Token need from
   Governance: purpose, issuer/audience (`https://auth.umaxica.*` ↔ `https://www.umaxica.*`), `typ`,
   claims (actor and subject separate), TTL, `jti`, receiver nonce binding, size. Write it into the
   design section of `adr/access-is-a-pure-openid-provider.md` as an amendment, and into a short
   contract file under `docs/` that can be copied verbatim to Governance. Implement the Access side
   (issue request, verify answer with the Base JWKS, store `sub` and the ceremony facts on the
   transaction). Stop before reopening the Auth ceremony screens; that is a separate order.
5. **Remove the remnants.** The ID Token for Base is no longer issued at the Token Endpoint, so the
   `authorization_code` branch that refuses with "Governance credential lookup" goes for Base; for
   other clients it must issue from stored transaction facts or refuse clearly, never call out.
   Decide line 133 the same way (stored capability or refuse) and report. Remove the "Governance …
   unavailable" raises on the sign-up and sign-in paths in favour of the handoff, or report each one
   that cannot go yet.
6. Sign-up: do not design the pending registration here; Governance owns it (Governance
   `plans/2026-11-14-pending-registration-lifecycle-design-work-order.md`). Where sign-up needs a
   hook, leave a clear refusal and report it.

Stop on an item and continue with the rest when it needs a schema change you cannot make reversibly,
a new environment variable or credential, or a contract that differs from the ADRs.

## Resolution of the 2026-11-14 stop (owner, 2026-11-15)

`evidence/2026-11-14-front-channel-id-token-sign-in-B3T8.md` stopped on blockers A and B. Both are
decided in "OP session and transaction storage decisions (owner, 2026-11-15)" of
`adr/access-is-a-pure-openid-provider.md`; read it. Items 2 and 5 are done; resume with:

7. Blocker A: PKCE child tables (one per realm), reversible migrations, models, coordinator reads
   PKCE only for Code transactions; `id_token` transactions store none. Existing Code flows must
   keep working (their tests stay green).
8. Blocker B: replace `user_id` with `subject_public_id` (string, NOT NULL, per realm) on root
   tokens, device sessions and grants and every writer and reader; discard dev/test rows keyed to
   removed accounts (this is approved; still use reversible structure migrations and say which
   tables were emptied). No production migration.
9. Item 4: write the lookup contract with `sub` = Governance public identifier, into the ADR and
   `docs/`, and implement the Access side.
10. Item 3: wire issuance (remove the 503 for the profile), so the Visa authorize request reaches
    the 303 through Jump to Auth; then the issuance tests below.

The "stop and report" rule above still applies to anything outside these decisions.

## Tests (Red first)

For both realms: the exact Governance request with `response_type=id_token` is accepted and, once
the transaction is authenticated (drive it through public code, no mocked coordinator), answers 303
through Jump with an ID Token that verifies against the Visa JWKS and carries only the allowed
claims; `sid` present and equal to the `sid` a later Logout Token for that OP session carries;
lifetime boundary (below, at, above 2 minutes); second completion refused; Base client with `code`
refused; another client with `id_token` refused; `id_token token` and Hybrid refused for all;
missing `nonce` or `state`; PKCE parameters from a Base client refused; Discovery unchanged; the
Token Endpoint issues nothing for Base. Static guard: no HTTP client class is reachable from the
sign-up and sign-in controllers and services except the JWKS client.

## Checks and report

bin/rails zeitwerk:check, bin/rubocop, bundle exec erb_lint --lint-all, bin/brakeman --quiet
--no-pager --exit-on-warn --exit-on-error, bundle exec database_consistency, bun run check, the
changed tests, then bin/rails test (separate pre-existing failures; unset
`POSTGRESQL_TEST_PREPARE_DATABASES` if its stale list blocks boot). Update README, docs/mermaid
diagrams and checklists affected.

Evidence: `evidence/YYYY-MM-DD-front-channel-id-token-sign-in-XXXX.md` (full `git rev-parse HEAD`):
inventory and classification, measured URL sizes, the lookup contract (or where it is), remnants
removed and stopped items, test results, the exact normative text the query response mode departs
from, owner items, confirmation that config/credentials files are unchanged.
