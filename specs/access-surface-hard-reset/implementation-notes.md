# Access Surface Hard Reset — Implementation Notes

## Context

- Spec: [spec.md](spec.md), accepted 2026-11-10.
- Related decisions: `adr/visa-op-host.md` and `specs/cosmos-cross-repository-connection/spec.md`.
- Implementation date: 2026-11-11.

## Decisions Made During Implementation

- Preserve cross-repository OIDC client redirect registrations. The owner explicitly chose to retain
  those clients while removing foreign in-repository surfaces.
- Keep the shared worktree intact and do not commit. No databases were dropped, and no Active Record
  model classes or migrations were removed.
- Remove `PromotionalEmailUnsubscribable` as an unused concern module after confirming it has no
  runtime or test caller. This does not remove an Active Record model.
- Leave `.github/workflows/ci.yml` untouched because `.github` is mounted read-only as a safety
  boundary. Its 47 retired variable references remain for a later authorized update.

## Deviations and Deferred Work

- The CI workflow variable cleanup remains incomplete until the owner supplies an approved safe path
  to update the read-only `.github` tree. No mount or permission change was attempted.
- A production Rails boot check could not reach `config/environments/production.rb`: application
  boot stops in `config/application.rb` because no production database provider is configured. No
  database configuration was fabricated. Ruby syntax validation passed.
- The initial recheck report incorrectly said there were no new RuboCop offense sites. The current
  comparison found 10 new offenses on changed lines across nine files. Those offenses were fixed;
  the final full RuboCop run has no offenses on added or changed Ruby lines.

## Review Notes

- Tests run: `bin/rails zeitwerk:check`, `bin/rails routes`, `bin/rubocop`,
  `bundle exec erb_lint --lint-all`, and `bin/rails test` after the source fixes.
- Results: Zeitwerk, routes, and ERB lint passed. RuboCop reported 220 remaining offenses on
  unchanged lines. The full suite reported 12,357 runs, 89,536 assertions, 38 failures, and 38
  errors; its failure/error identifiers matched the preceding recheck and the checkpoint comparison
  recorded in evidence.
- Environment construction: `ruby -c config/environments/production.rb` passed. A production Rails
  boot check was attempted and stopped at the existing missing-provider guard described above.
- Documentation recheck removed the retired Performance host from the current README table,
  corrected Access's operator-host count in the active cross-repository tunnel plan, and updated
  current surface guidance and architecture/test/operations references to the retained `app` and
  `org` surfaces.
- Full route/model inventory, deletion summary, database classification, retained items and
  verification details:
  [surface hard reset evidence](../../evidence/2026-11-10-surface-hard-reset-M7Q4.md) and
  [2026-11-11 recheck evidence](../../evidence/2026-11-11-surface-hard-reset-recheck-Q4R8.md).
