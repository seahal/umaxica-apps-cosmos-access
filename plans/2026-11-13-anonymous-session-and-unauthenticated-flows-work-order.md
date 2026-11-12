Task (umaxica-apps-cosmos-access): survey, adversarially review and fix the unauthenticated
multi-request flows (Anonymous Session and Stateful Workflow). No commit. Never print secrets or
environment values. Never edit config/credentials/*.yml.enc. Solid Queue is out of scope.

Source: owner's brief of 2026-11-13 (conversation). This order adapts it to the current Access
repository; where they differ, this order wins and the difference is stated.

## Purpose and non-goals

Find and remove verified problems in how a browser that is not signed in is tied to a server-side
flow across requests. Do not build a new session or flow framework, do not add AASM or another state
machine library, do not rename `SignUpFlow` and friends to "Anonymous..." and do not add a
`GuestSession` class (`guest` is already a domain term and an authentication mode). Shared security
invariants and test criteria come first; share code only when duplication is clear and no surface
boundary is crossed.

Out of scope: redesign of authentication or OAuth/OIDC, session library replacement, unrelated
routes, UI rebuilds, CI configuration, Solid Queue, unnecessary migrations.

## Authority order

1. current working tree; 2. accepted ADRs and accepted active specs; 3. current docs; 4. tests;
5. history and old repositories; 6. general practice. Record every conflict and the chosen side.
Never override an accepted ADR because code differs; report it instead.

Old repositories named in the brief (`umaxica-apps-jit-global`, `umaxica-apps-edge`) are not cloned
on this machine; use `git log` / `git show` in this repository for history instead. Do not fetch
from the network.

## Access-specific constraints (from the Cosmos split)

- Access is a pure OpenID Provider (`adr/access-is-a-pure-openid-provider.md`). Ceremonies stay in
  Access; identity, profiles and credential records move to Governance (decisions 14, 17 to 19).
  Do not invest in sign-up finalization or identity persistence that the ADR moves to Governance:
  fix security defects there minimally, report the rest as handoff items.
- Databases and models scheduled for removal: do not extend or harden them; check the current
  removal plan (`plans/2026-11-12-handoff.md`).
- JavaScript only for passkey (WebAuthn), the OTP resend countdown and Turnstile.
- Each surface is its own trust boundary; never share cookies or sessions across surfaces or
  applications. Jump RT and cross-origin redirects: review only where they touch these flows.
- Acceptance condition of the split: all CI static checks report zero problems without suppression
  (`docs/backlog/2026-11-12-ci-static-checks-acceptance.md`); do not add new offenses.

## Read first (owning decisions)

`adr/idp-flow-lifecycle-vocabulary.md`, `adr/idp-flow-state-machine-lifecycle.md`,
`adr/browser-flow-handle-per-tab.md`, `adr/sign-up-flow-admission-binding-and-cardinality.md`,
`adr/sign-up-checkpoint-turnstile-boundary.md`, `adr/sign-up-cycle-cancellation-retention.md`,
`adr/sign-up-finalization-in-auth.md`, `adr/sign-up-authentication-handoff-and-social-rt.md`,
`adr/sign-in-first-and-sign-up-handoff.md`, `adr/session-reset-on-privilege-transition.md`,
`adr/session-token-hardening-baseline.md`, `adr/static-and-guest-controller-boundaries.md`,
`adr/defer-auth-xper-transient-workflow-redesign.md`, `docs/mermaid/README.md` and the IdP state
machine inventory. Plus the rules AGENTS.md selects for controllers, routes, authentication,
sessions, migrations, tests and fail-fast.

Observed today (2026-11-13): present — `SignUpSessionState`, `SignUpStateMachine`,
`ClientSignUpFlow`, `checkpoint_version`, `with_cycle_lock` (`app/models/concerns/flow_base.rb`),
`SocialAuth` (social callback concerns), `AUTHENTICATION_MODE`; absent —
`SignUpSequenceControllerSupport`, `VisitorSignUpFlow`, `SignUp::ParticipantPolicy`,
`SignUp::RequirementPolicy`, `SignUp::FinalizationPolicy`. Confirm and explain each.

## Stage 1: inventory (report before changing code)

Flows to check: sign-up, sign-in, account recovery, email/telephone OTP, social sign-in, OIDC
authorization start and callbacks, and any other unauthenticated multi-request procedure that still
exists in Access. OAuth/OIDC keeps its protocol mechanisms (`state`, `nonce`, PKCE, PAR); do not
convert it to the web-form pattern.

Per flow: start and end conditions; cookie and Rails session use; server-side state store; flow
identifier generation, storage and lookup; transition validation; expiry and revocation; CSRF;
IDOR; double submit and races; multiple tabs and Back; abandon and resume; transition to
authenticated (session reset); existing tests. Where the same data sits in the session and the
database, state which is authoritative and why (a copy may be an identifier or a check value, not a
duplicate).

## Stage 2: adversarial review

A. Identification and access: guessable identifiers, another person's flow, cookie-to-flow binding,
session fixation, stolen cookie reuse, confusion between authentication states, silent fallback to
unauthenticated. Verify each `AUTHENTICATION_MODE` value (`:guest`, `:open`, `:private`, `:bare` or
whatever exists) and keep the boundaries. Owning a flow is never proof of identity.

B. Transitions: skipping steps by direct access, reuse of expired or finished flows, stale forms,
multi-tab races, double submit, concurrent finalization, exceptions mid-way. Check atomicity from
check to commit (transaction, row lock, conditional UPDATE, unique constraint). Do not assume a DB
transaction prevents duplicate external side effects (mail, SMS, provider calls).

C. HTTP and CSRF: state changes never on GET; Rails CSRF protection is the standard; no business
one-time tokens or CSRF tokens in GET parameters. Evaluate OIDC `state`, callbacks and email
verification links on their own terms. Keep CSRF, one-time tokens and idempotency keys separate.

D. Cookies and browser: `Secure`, `HttpOnly`, `SameSite`, `Path`, `Domain`, `__Host-`, lifetime,
size, revocation, `Cache-Control`, bfcache. Scope across the multiple subdomains and TLDs strictly.

Do not write attack procedures into repository files; describe the class of weakness, the
precondition and the impact.

Rate each finding (severity, priority) and decide, per finding: fix now, report as handoff to
Governance, or accept with a reason.

## Stage 3 and 4: fix with TDD

Responsibilities to respect (no new classes or tables implied): Rails session = short-lived request
links; cookie = minimal browser data; flow record = server-side state; state machine = allowed
transitions; policy = actor/target/action authorization; CSRF protection; database = durability,
constraints, atomicity; idempotency = duplicate business operations.

Constraints: reuse existing state machines, policies and concerns; no generic flow framework; no
blanket `flow_id` rotation; no new GET tokens; no sensitive business state in cookies; never skip
server checks for convenience; declarative PostgreSQL constraints (CHECK, UNIQUE, FK, NOT NULL)
over validations; no new triggers or callbacks; NULL never encodes state. Multi-tab: follow
`adr/browser-flow-handle-per-tab.md`; unsupported behaviour may be rejected, but never corrupt state
or mix authority.

Per fix: confirm current behaviour, failing test (Red), minimal fix (Green), refactor, lint and
format, rerun related tests. Races are tested with real concurrency (threads with separate
connections, non-transactional test that cleans up its rows), not sequential requests. Cover
boundaries per AGENTS.md (below, at, above expiry; missing, empty, invalid identifiers). No
coverage-only tests. Migrations need the owner's approval before running if they change or drop
existing data.

If a fix needs a contract, schema or cross-surface change outside this scope, or an ADR amendment,
stop on that item, state the options and continue the rest.

## Checks and report

bin/rails zeitwerk:check, bin/rubocop, bundle exec erb_lint --lint-all, bundle exec
database_consistency, bun run check, the related test files, then bin/rails test (and test:system if
flows' browser behaviour changed). Separate pre-existing failures (baseline in
evidence/2026-11-12 round 2) from change-caused ones.

Record in evidence/YYYY-MM-DD-unauthenticated-flows-XXXX.md (full `git rev-parse HEAD`;
uncommitted changes affected results): A. current state per flow; B. adversarial findings with
precondition, impact, existing defence, decision; C. changes with files and reasons and behaviour
differences; D. tests added/changed, results, coverage of changed paths, unverified items;
E. residual risks and follow-ups (including Governance handoff items); F. ADR, mermaid and docs
updates made (amend existing ADRs; no duplicate ADR). Confirm config/credentials files unchanged.
