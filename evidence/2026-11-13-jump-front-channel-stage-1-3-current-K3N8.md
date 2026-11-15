# Jump Front-Channel Handoff — Stage 1–3 Current Worktree Record

This record completes the requested Stage 1–3 item in
`plans/2026-11-13-jump-front-channel-handoff-work-order.md`. Stage 4 is outside the requested scope
and was not performed.

## Revision and scope

- Repository: Access; branch `feature`; `git rev-parse HEAD`:
  `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree had 340 changed paths at review time. Pre-existing and earlier authorized changes
  affect the observations; they were preserved. No commit or push was made.
- `git status --short -- config/credentials` returned no changes. No route, runtime handoff code,
  migration, schema, key material, or peer configuration was added for this item.
- `git diff --check` passed.
- The detailed investigation, design, size calculation, adversarial table, and protocol references
  are in `evidence/2026-11-13-jump-front-channel-stage-1-3-R5F8.md`. This current-worktree record
  rechecks the owning plan and ADR after the earlier PS256 work and records current scope/status.

## Current boundary and design record

- The work order confirms that front-channel browser handoffs through Jump replace application
  server-to-server exchanges, while HTTPS peer JWKS retrieval remains allowed. It preserves Jump's
  separate `rt` navigation token and `pt`/`nt`/`xt` lanes, host-only application sessions, and the
  rule that a signature alone never authenticates a person or authorizes access.
- The current `adr/access-is-a-pure-openid-provider.md` records four proposed exchanges: credential
  lookup, credential registration, Governance queries for Access-owned OP data, and Access-initiated
  authority freshness checks. It specifies receiver-session challenges, sender per-tab procedure
  binding, strict PS256 handoff typing and claims, one-use replay identifiers, receiver-local
  idempotency receipts, encrypted confidential payloads with a distinct receiver key, and clean 303
  responses with no-store/no-referrer behavior. These remain design requirements, not deployed
  behavior or approval to implement Stage 4.
- Current Access routes and callers still include the old server-delivered revocation-command path
  (`config/routes/visa.rb`, the APP/ORG controllers, and `GovernanceRevocationCoordinator`). The ADR
  identifies it as superseded and proposes removal only after the replacement contract and callers
  are accepted; no part of that path was changed here.
- Access and Edge Jump issuer/return allow-lists do not establish a Governance issuer or
  destination. The Governance and Edge Jump checkouts are absent from this workspace. No repository
  was fetched, and prior dated Jump URL-limit observations were not represented as live/current
  verification.

## Adversarial findings and open decisions

The detailed severity-ranked review remains in the referenced R5F8 evidence. The unresolved
implementation blockers remain material: fixed Governance issuer/JWKS origins and an approved Jump
edge; authority/delegation proof for OP-data queries; accepted stale-authority bounds and exact
browser-pull boundaries; receiver challenge round trips per operation; JWE key profile and rotation;
a measured real maximum payload and behavior when it exceeds gateway limits; Governance pending
account/cancellation semantics; and gateway/proxy observability. No origin, route, key or payload
limit was guessed. Oversized or unverifiable exchanges must fail closed, with no server-call
fallback.

The design references primary protocol sources reviewed for the earlier Stage 1–3 record:
[RFC 7515](https://www.rfc-editor.org/rfc/rfc7515.html),
[RFC 7516](https://www.rfc-editor.org/rfc/rfc7516.html),
[RFC 7519](https://www.rfc-editor.org/rfc/rfc7519.html),
[RFC 8725](https://www.rfc-editor.org/rfc/rfc8725.html),
[RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html), and
[OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html).

## Verification

- Re-read the current work order, the owning pure-OpenID-Provider ADR, and the prior Stage 1–3
  evidence; inspected current Access Jump issuer/return policy entries, `request.original_url`
  callers, and revocation-command routes/callers.
- `git diff --check`: passed.
- No runtime behavior changed during this Stage 1–3 completion, so no runtime test was run for this
  evidence-only recheck. The earlier Stage 1–3 record likewise identifies that its changes were ADR
  prose and records its verification separately.
- No live Governance/Jump integration, deployment, Cloudflare, or browser verification was possible
  from this checkout. Stage 4 remains unimplemented and requires the listed design decisions.
