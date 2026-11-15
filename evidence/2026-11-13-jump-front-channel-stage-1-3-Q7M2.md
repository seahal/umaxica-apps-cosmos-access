# Jump Front-Channel Handoff — Stage 1–3 Review

## Revision and scope

- Repository: Access (`umaxica-apps-cosmos-access`), branch `feature`.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree is already extensively modified: 112 modified/staged paths, 68 deleted paths, and 17
  untracked paths (197 total). These changes were preserved; they affect the observations below. No
  commit or push was made.
- Completed the requested investigation, adversarial review, and design stages only. Stage 4 and all
  runtime implementation were outside this request. The prior Stage 4 worktree changes, if any, were
  not modified in this step.
- The existing Stage 3 design in `adr/access-is-a-pure-openid-provider.md` was re-read. It remains
  explicitly a proposal, not implementation approval. No additional runtime code, test, route,
  migration, key, or peer configuration was changed.

## Findings and design retained

- Jump `rt` remains a short-lived navigation instruction, separate from the handoff token. The
  design preserves `pt` / `nt` / `xt`, the existing directed graph, host-only per-application
  sessions, and the prohibition on shared cookies and server-to-server fallback.
- The proposed message is a purpose-specific PS256 JWS with strict header and claim allow-lists,
  exact issuer/audience/purpose checks, short expiry, and one-use `jti`. Sensitive claims require a
  nested JWE using a separate receiver encryption key. A signed message alone is not user
  authentication or authorization.
- Each side binds a handoff to its own browser session and pending procedure. High-risk credential
  lookup, registration, OP data queries, and authority freshness use receiver-issued session-bound
  challenges. The receiver checks its own ownership and authorization. Cross-database writes use
  receiver-owned idempotency receipts and retryable acknowledgements, not distributed transactions.
- The ADR covers token cleanup by 303 redirect, no-store and no-referrer responses, redaction
  boundaries, replay and interruption behavior, key rotation, and generic fail-closed outcomes.
- A synthetic lower-bound measurement recorded in the prior Stage 1–3 evidence is a 1,036-byte PS256
  JWS and a 1,075-byte callback URL, leaving 973 bytes under the observed 2,048-byte Jump
  destination limit. JWE overhead and real credential payload size remain unmeasured; no claim is
  made that registration and lookup payloads fit.

## Adversarial review and unresolved decisions

High risks retained in the ADR and prior evidence: Access has no approved Governance Jump identity
or directed edge; a signature cannot authorize cross-subject OP access; actual payloads may exceed
URL limits; current implied staleness bounds are 30 days for clients and 8 hours for operators;
cross-database registration needs durable idempotency receipts; and an unattended browser can delay
revocation until existing local authority expires. Browser history and upstream logs may observe the
query before the receiver's cleanup redirect.

Implementation remains blocked on the exact Governance issuer and receiver origins, its Jump edge,
operator delegation proof, accepted staleness bounds and pull boundaries, per-purpose challenge
round trips, JWE key profile and rotation, actual maximum payload, and interrupted sign-up
lifecycle. These are recorded as unresolved owner decisions rather than guessed. The old
server-delivered revocation routes and verifier are identified as superseded but were not removed in
this design-only scope.

Governance and Jump source worktrees are absent. The Stage 1–3 work order prohibits fetching the old
repositories, so their live source/configuration and deployed Jump availability were not revalidated
here. Earlier observations remain dated evidence only. No cross-repository or live end-to-end claim
is made.

## Verification

- Re-read `plans/2026-11-13-jump-front-channel-handoff-work-order.md`, prior evidence
  `evidence/2026-11-12-jump-front-channel-handoff-JH31.md`, and the owning ADR's Stage 3 design.
- `git diff --check`: passed.
- No runtime tests were run because this requested portion was investigation/review/design only and
  no runtime code changed in this step.
- `config/routes.rb`, `config/routes/`, `config/database.yml`, and `config/credentials/` have no
  worktree changes at this capture. Credential files were not read or edited.
- This stage adds no CI/CD or Solid Queue changes.
