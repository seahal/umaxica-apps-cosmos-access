Task (umaxica-apps-cosmos-access only): apply `adr/sign-flow-terminology.md` to the current tree.
Rename sentry, guard, guardrail and checkpoint to availability, ingress, eligibility and
requirements. Naming only: behaviour, security order and stored values stay as they are. No commit.
Never print secrets, key material or environment values. Never edit config/credentials/*.yml.enc. No
push, no deploy, no Cloudflare change, no change outside this repository.

## Decision

Owner, 2026-11-14: the old names read unnaturally in English; one-noun terms that fit Rails
resourceful routing replace them. Read the ADR first; its table and rules are the contract.

| Old                                                                                     | New                             |
| --------------------------------------------------------------------------------------- | ------------------------------- |
| sentry (switch, resolver, enforcement, state value)                                     | availability                    |
| sentry (entry endpoint `/sign/in/sentry`, `/sign/up/sentry`), sign-up guard controllers | ingress                         |
| guardrail                                                                               | eligibility                     |
| checkpoint                                                                              | requirements (one: requirement) |

## Observed on 2026-11-14

- About 76 files under app, config, lib, db and test mention one of the old terms (174 Ruby lines
  under app, config, lib). Among them: `SignEntrySentryResolver`, `SignEntrySentryStateValue`,
  `SignEntrySentryEnforcement`, `sign_entry_classification.rb`, `oidc_authorization_start.rb` and
  the two Visa `oauth/authorizations_controller.rb` (the handoff to Auth `/sign/in/sentry`),
  `SignIn::SequencePolicy#show_checkpoint?` and friends, the `GUARDRAIL_PENDING` and
  `CHECKPOINT_PENDING` constants in the client and operator sign-in flow state models and the flow
  models, `AuthIoKeys::…::CHECKPOINT = :sign_in_checkpoint`, and the `sentry` routes in
  `config/routes/auth.rb` that point at the unavailable ceremony controllers.
- Most Auth ceremony controllers do not exist now (removed at `727cdb560`); they are restored later
  under the new names by separate orders.
- Other open orders from 2026-11-14 still say "sentry" (for example
  `plans/2026-11-14-front-channel-id-token-sign-in-work-order.md`); read that as "ingress".

## Work

1. Inventory every occurrence (code, routes, views, locale keys, log event names, tests, docs,
   `docs/mermaid`, checklists, OpenAPI). Classify each: identifier to rename, stored value to keep
   (integer state codes, column values, Flipper flag keys), or unrelated use to keep (for example
   `ingress` in `lib/runtime_role_route_guard.rb`, or "checkpoint" meaning the git checkpoint
   `727cdb560`).
2. Rename identifiers with `git mv` for files so history follows. Routes:
   `resource :ingress, only: :show` under `sign/in` and `sign/up` for both realms, still pointing at
   the unavailable ceremony controllers (Auth stays 503); Visa's handoff builds the new ingress URL
   through the route helper. Sign-up step routes become `namespace :requirements` with one singular
   resource per step where such routes exist now.
3. Stored values: keep integer codes and flag keys. If a reference table stores a name string for a
   renamed state, update the row with a reversible migration. `:sign_in_checkpoint` is a session
   key: rename it, and report that sessions in flight lose that value (acceptable during the reset;
   do not add a fallback read of the old key).
4. Docs: update current docs, diagrams, inventories and checklists to the new terms. ADRs keep their
   file names; add a one-line note pointing to `adr/sign-flow-terminology.md` where an ADR's text
   uses an old term as current vocabulary. Do not rewrite closed plans or evidence.
5. No alias, no old-path redirect, no deprecated constant.

Stop on an item and continue with the rest if the rename would change a stored value other than a
reference-table name, or an external contract.

## Tests

Rename tests with the code. Add or adjust: Visa's authorization start answers 303 through Jump to
`/sign/in/ingress` (both realms); `/sign/in/sentry` and `/sign/up/sentry` are no longer routed
(404); availability blocked still refuses at ingress; the static classification guard still sees
every reachable action. A static test fails if `sentry`, `guardrail` or `checkpoint` (case
insensitive) appears in app, config or lib outside an allow-list of stored values and unrelated uses
from step 1.

## Checks and report

bin/rails zeitwerk:check, bin/rails routes (Auth and Visa blocks), bin/rubocop, bundle exec erb_lint
--lint-all, bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error, bundle exec
database_consistency, bun run check, the changed tests, then bin/rails test (separate pre-existing
failures; unset `POSTGRESQL_TEST_PREPARE_DATABASES` if its stale list blocks boot).

Evidence: `evidence/YYYY-MM-DD-sign-flow-terminology-rename-XXXX.md` (full `git rev-parse HEAD`):
the inventory with classification, renamed files, kept stored values, migration if any, docs
touched, test results, stopped items, and confirmation that config/credentials files are unchanged.
Governance has its own copy of `AuthIoKeys` with `CHECKPOINT = :sign_in_checkpoint`; report it as a
follow-up for Governance, do not change it.
