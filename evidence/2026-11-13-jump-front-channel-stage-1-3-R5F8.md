# Jump Front-Channel Handoff — Stage 1–3 Completion

Completed the investigation, adversarial review, and design stages in
`plans/2026-11-13-jump-front-channel-handoff-work-order.md`. Stage 4 implementation was not part of
the requested scope.

## Revision and worktree

- Repository: Access; branch `feature`; `git rev-parse HEAD`:
  `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- At capture the dirty worktree had 264 changed paths, including extensive earlier authorized work.
  Those changes were preserved and affect the observations below.
- No `config/credentials/*.yml.enc` file changed. No handoff key, route, runtime code, database
  schema, migration, or peer configuration was added. No commit or push was made.
- `git diff --check` passed.
- The design remains in the owning `adr/access-is-a-pure-openid-provider.md`; no duplicate ADR was
  created. This pass amended its Common Message Contract to state that OAuth/OIDC protocol state is
  independent from the handoff. No runtime behavior changed.

## Sources and authority

The accepted Access ADR and current Access tree were treated as current. The local research note
`research/2026-11-12-access-governance-service-communication-options.md` is explicitly
non-normative; its later 2026-11-13 section says the owner's browser-carried decision supersedes its
earlier HTTPS request/response decision. Historical paragraphs in that note were not treated as
current requirements.

Read the Access redirect and session ADRs, the Access OIDC state and Discovery docs, the current
Jump surface/edge code, token lifetime code, revocation command callers, session cookie config, and
the handoff design section in the owning ADR. The Governance and Edge Jump repositories, their
receiver contract, and Governance's copy of the research note are absent from this workspace. No old
repository was fetched. The dated Jump limit/deployment observations below are therefore not claimed
as current source or live verification.

Reviewed the primary protocol sources:

- [RFC 7515 — JWS](https://www.rfc-editor.org/rfc/rfc7515.html),
  [RFC 7516 — JWE](https://www.rfc-editor.org/rfc/rfc7516.html),
  [RFC 7519 — JWT](https://www.rfc-editor.org/rfc/rfc7519.html), and
  [RFC 8725 — JWT Best Current Practices](https://www.rfc-editor.org/rfc/rfc8725.html).
- [RFC 6749 — OAuth 2.0](https://www.rfc-editor.org/rfc/rfc6749.html),
  [RFC 9700 — OAuth 2.0 Security BCP](https://www.rfc-editor.org/rfc/rfc9700.html),
  [RFC 7636 — PKCE](https://www.rfc-editor.org/rfc/rfc7636.html),
  [RFC 9126 — PAR](https://www.rfc-editor.org/rfc/rfc9126.html), and
  [OpenID Connect Core 1.0 with errata set 2](https://openid.net/specs/openid-connect-core-1_0.html).
  RFC 8725 supports fixed algorithm allow-lists, issuer/audience validation, explicit token typing,
  and mutually exclusive JWT profiles. OAuth/OIDC's `state`, `nonce`, PKCE, PAR, registered redirect
  URI, and callback checks remain independent protocol controls. RFC 9700's referer and
  browser-history leakage guidance supports the designed no-third-party-content and token-cleanup
  boundary.
- Also reviewed
  [RFC 10017 — OAuth 2.0 for Browser-Based Applications](https://www.rfc-editor.org/rfc/rfc10017.html)
  (BCP 212, August 2026). Access is a Rails server application and does not expose OAuth bearer
  tokens to browser JavaScript, so the RFC's browser token-storage patterns do not define this
  handoff; its browser threat discussion does not remove the URL-history and referer risks below.

## A. Current state and ownership boundaries

- Access signs first-party tokens with PS256. Jump `rt` remains a short-lived navigation token,
  separate from a proposed handoff JWS. Access's `JumpRtSurface::ISSUER_NAMESPACES` contains only
  `AUTH_APP`, `AUTH_ORG`, `VISA_APP`, and `VISA_ORG`; its return-origin list contains Auth, Visa,
  Base, Core, Warp, and Palm. `JumpRtReturnPolicy::EDGE_CATALOG` has no Governance identity or edge.
  The code does not establish that Governance may be aliased to another namespace.
- Access's current Rails session uses the encrypted cookie store, an explicit `SameSite=Lax` session
  cookie, host-only scope, `HttpOnly`, 14-day expiry, and `Secure` outside development and test.
  Production defaults other cookies to `SameSite=Strict`; the session cookie explicitly overrides
  that default for inbound protocol state. There is no shared `Domain` cookie.
- Six current `request.original_url` call sites remain across four files:
  `app/controllers/concerns/jump_rt_return_verification.rb` (2),
  `app/controllers/concerns/op_browser_session_request.rb` (2),
  `app/controllers/concerns/base_oauth_token_endpoint.rb` (1), and
  `app/controllers/concerns/oidc_op_endpoint.rb` (1). They support existing request/URL binding; no
  handoff endpoint exists, so there is no new handoff-token logging path to inspect. Application
  redaction cannot establish what the browser, Jump, CDN/proxy, or another application records.
- The old server-delivered revocation path still exists in Access: `config/routes/visa.rb` exposes
  APP/ORG revocation-command resources;
  `app/controllers/visa/app/api/v0/revocation_commands_controller.rb` and the ORG counterpart call
  `GovernanceRevocationCoordinator`, which invokes the ES384 `GovernanceRevocationCommandVerifier`
  and persists realm receipts through `GovernanceRevocationCommand`. The ADR now treats the push
  transport as superseded. Propose removal only after the replacement design and callers are
  accepted/migrated; none of those files changed in this design-only stage.
- Governance source, Edge Jump receiver source/contract, and live deployment state were not
  revalidated because their repositories are absent and the work order prohibits fetching them.
  Previous public-snapshot or JWKS-503 observations remain dated evidence only.

## B. Proposed design

The existing ADR records four separate browser-carried sequences: credential lookup (Access ->
Governance), credential registration (Access -> Governance), OP-data query (Governance -> Access),
and authority freshness/revocation (Access -> Governance). For each, the receiver issues a random
challenge bound to its own session and pending operation; the sender also checks its original
per-tab procedure and session. Neither a valid signature nor the handoff itself establishes user
authentication, object ownership, or authorization. Access verifies credentials itself and only
proceeds on a valid affirmative Governance answer.

The proposed message has a strict protected header (`PS256`, handoff-specific `typ`, known `kid`),
exact issuer/audience, time, realm, purpose/event allow-lists, request correlation, and one-use
`jti`. A two-minute maximum lifetime is proposed. Payloads are minimal and contain no internal
primary keys, personal contact data, raw credentials, session cookies, authorization bearer, or
redirect targets. Sign first; use nested JWE to a distinct receiver encryption key when the browser
must not read a claim. Peer public JWKS may be fetched over HTTPS, cached, refetched on unknown
`kid`, and must fail closed without a valid key. These wire details are a design proposal, not
implementation authorization.

Replay consumption belongs to the receiver's local PostgreSQL transaction with the corresponding
business mutation. The proposed unique replay identity is `(purpose, issuer, jti_digest)`; raw token
and raw `jti` are not persisted. Existing `SecurityConsumedJti` is APP-owned and does not preserve a
committed result; the APP/ORG consumed-JTI models also do not store repeatable handoff outcomes.
Cross-database registration therefore needs a receiver-owned durable idempotency receipt and a
repeatable signed acknowledgement. No distributed transaction is assumed.

Handoff tokens arrive only at non-rendering endpoints. Acceptance or rejection returns a 303 to an
allowlisted local path with the handoff query removed, plus `Cache-Control: no-store` and
`Referrer-Policy: no-referrer`; no third-party resources load first. Invalid, expired, duplicate,
wrong-purpose, wrong-audience, wrong-procedure/session, cancelled, late, or cross-browser handoffs
refuse generically or return explicit unavailability. A committed idempotent retry can repeat its
own signed acknowledgement without reapplying the mutation or disclosing another user's state.
Reload, Back, multiple tabs, interruption, and session reset must not replay completed work.

The design preserves Jump `rt`, `pt`/`nt`/`xt`, the approved same-domain directed graph, and the
separate Away boundary for cross-TLD movement. It adds no gateway-to-gateway destination or
server-to-server fallback. Existing OAuth/OIDC `state`, `nonce`, PKCE, PAR, registered
`redirect_uri`, and callback checks remain independent; the ADR now states this explicitly.

## C. Size and revocation bounds

The work-order/earlier review cites Edge Jump limits observed at revision `0eb2959`: destination URL
at most 2,048 characters and Jump `rt` at most 4,096. Current source was unavailable for
revalidation. A fresh synthetic measurement used an in-memory 3,072-bit RSA key and non-sensitive
placeholder claims; only lengths were printed:

- PS256 request JWS: 1,036 bytes.
- Query URL with a 39-byte fixed prefix: 1,075 bytes.
- Remaining under the cited 2,048-character destination ceiling: 973 bytes.

This is only a minimal signed-JWS measurement. It excludes nested JWE overhead, real credential
records, browser-specific limits, CDN/proxy limits, and a measured real maximum. Registration and
some lookups have not been shown to fit. Oversized payloads must be reported and the exchange
stopped until a smaller contract or another explicitly approved front-channel shape exists; no
truncation, claim splitting, or server call is a fallback.

Current Access root-token absolute lifetime implies a proposed maximum stale-authority interval of
30 days for clients and 8 hours for operators. Idle limits (8 hours and 30 minutes respectively) may
shorten but not extend it. Root expiry prevents refresh from extending the same authority; a new
root/authorization boundary must obtain a fresh affirmative Governance answer through a browser. The
owner accepted that a Governance change takes effect on the user's next Access pass, but the numeric
bounds and the exact per-surface boundaries that must pull remain unconfirmed.

## D. Adversarial findings and dispositions

| Severity / priority | Finding and impact                                                                                                                                                                       | Disposition                                                                                                                                                                |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| High / P1           | No approved Governance Jump identity or edge. Guessing an issuer, aliasing it to Visa/Auth, adding an edge, or using deprecated external mode would cross trust/topology boundaries.     | Handoff to owner for fixed origins and approved edge; Stage 4 remains blocked.                                                                                             |
| High / P1           | A valid signature could be mistaken for authentication or permission to query another subject. That could disclose another person's OP data or accept an unauthorized credential result. | Refuse cross-subject/admin queries until a Governance delegation proof and Access authorization contract are accepted. Self-owned data still needs receiver authorization. |
| High / P1           | Minimal JWS leaves only 973 bytes before JWE and real credential content; requests may exceed the Jump destination ceiling.                                                              | Measure a bounded real payload; stop that exchange if oversized. No truncation or API fallback.                                                                            |
| High / P1           | Local authority can remain stale for up to 30 days for clients and 8 hours for operators; a 5-minute JWT does not shorten a renewable root.                                              | Propose those absolute bounds and browser-pull boundaries to owner; numeric acceptance remains open.                                                                       |
| High / P1           | Consuming `jti` alone cannot reproduce a committed cross-database registration result after a lost acknowledgement; retry may otherwise duplicate or lose a write.                       | Governance must commit a local idempotency receipt with its mutation and reproduce the same acknowledgement.                                                               |
| Medium / P2         | URL cleanup cannot erase the initial query from browser history, the first Jump/CDN request, or upstream logs. A referrer or page asset could disclose it.                               | No-render 303 cleanup, no-store/no-referrer, no third-party assets, and verify gateway/proxy logging before rollout.                                                       |
| Medium / P2         | Host-only `SameSite=Lax` browser sessions and cross-origin top-level GET behavior must work for the challenge sequence; changing to a shared cookie would leak surface authority.        | Keep per-app cookies and require real-browser verification before rollout.                                                                                                 |

## E. Verification and remaining decisions

- Read the current Stage 1–3 plan, related Access ADRs, Access code, the Access communication
  research note, and the previous Stage 1–3 evidence. The source policy was followed; external
  protocol references were official IETF RFC Editor or OpenID Foundation documents.
- Re-ran the synthetic size calculation; it returned 1,036 / 1,075 / 973 bytes as above.
- `git diff --check`: passed. No runtime tests were run because this stage changed only ADR prose.
- No live browser, Jump deployment, Governance, Cloudflare, or cross-repository test was performed.
- Stage 4 still needs accepted decisions for Governance issuer/receiver origins and Jump edge;
  operator delegation; numeric staleness bounds and exact browser-pull boundaries; receiver nonce
  round trips per purpose; JWE key type/algorithm/publication/rotation; real maximum payload and
  behavior if it cannot fit; Governance pending-account/cancellation lifecycle; and gateway/CDN
  observability. Unknown endpoints or keys were not guessed.
