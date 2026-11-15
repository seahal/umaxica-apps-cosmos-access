Task (umaxica-apps-cosmos-access only): remove the server-pushed Governance revocation path now. No
commit. Never print secrets, key material or environment values. Never edit
config/credentials/*.yml.enc. No push, no deploy, no Cloudflare change.

## Decision

Owner, 2026-11-14: remove it ahead of the replacement design
("ハードリセットしているさいちゅうだし、
せんこうしてけしていいよ。どうせこわれているし。"). This overrides the condition in
`evidence/2026-11-12-jump-front-channel-handoff-JH31.md` section F that removal waits for the
accepted replacement. Revocation is handled later by the browser-carried handoff (pull, fail
closed); nothing replaces it in this order.

## Remove (observed 2026-11-14; follow references until the set closes)

- Routes and controllers: `app/controllers/visa/app/api/v0/revocation_commands_controller.rb`,
  `app/controllers/visa/org/api/v0/revocation_commands_controller.rb` and their routes.
- `app/services/governance_revocation_coordinator.rb`,
  `app/adapters/governance_revocation_command_verifier.rb` (ES384),
  `app/operations/governance_revocation_command.rb`,
  `app/values/governance_revocation_command_value.rb`,
  `app/lib/governance_revocation_acknowledgement_codec.rb`.
- Models `OpAppGovernanceRevocationReceipt`, `OpOrgGovernanceRevocationReceipt` and their tables:
  add drop migrations in `db/op_base_app_migrate/` and `db/op_base_org_migrate/` (reversible,
  recreating the table as created by `20261112130236` / `20261112130240`), and update the structure
  files. Before writing them, count rows in the development databases and report the counts; if any
  shared or production database is reachable from the container, do not touch it.
- Configuration (environment variable names, key settings, JWKS clients) used only by this path;
  report names only.
- Tests: `test/values/governance_revocation_command_value_test.rb`,
  `test/operations/governance_revocation_command_test.rb`,
  `test/concurrency/governance_revocation_receipt_concurrency_test.rb`,
  `test/models/governance_revocation_receipt_order_test.rb`,
  `test/controllers/visa/governance_revocation_commands_controller_test.rb`,
  `test/adapters/governance_revocation_command_verifier_test.rb`; adjust
  `test/security/invariants/op_authority_stop_single_writer_invariant_test.rb` so it no longer lists
  the removed writer, keeping its guarantee for the remaining writers.

Leave no compatibility layer, stub route or "gone" endpoint (`generic/no-compatibility-layer.mdc`).
If something outside this list depends on the path (for example an OP authority stop that only this
path could trigger), stop on that item, report it with options and continue with the rest.

## Docs

Update ADR text that describes the push path as current (amend with date; do not delete history),
`README.md`, `plans/2026-11-12-handoff.md`, OpenAPI if it lists the endpoints, and affected
`docs/mermaid` diagrams and inventories.

## Checks and report

bin/rails zeitwerk:check, bin/rails routes (no revocation route left), bin/rubocop, bundle exec
erb_lint --lint-all, bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error, bundle exec
database_consistency, bun run check, bin/rails db:migrate on development and test, then bin/rails
test (separate pre-existing failures; unset `POSTGRESQL_TEST_PREPARE_DATABASES` if its stale list
blocks boot and report that). `grep -ri revocation_command` and `grep -ri GovernanceRevocation` over
app, config, lib, db, test return nothing but migrations.

Evidence: `evidence/YYYY-MM-DD-governance-revocation-push-removal-XXXX.md` (full
`git rev-parse HEAD`): removed files, migrations and row counts, dependencies found and stopped
items, docs changed, test results, confirmation that config/credentials files are unchanged.
