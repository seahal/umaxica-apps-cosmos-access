# Surface hard reset recheck — 2026-11-11

## Revision and scope

- `git rev-parse HEAD`: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- Commands ran against the shared, uncommitted worktree at that revision. No commit was created.
- The original inventory, deletions, database/model usage report, retained-item explanations and
  initial verification record are in
  [2026-11-10 surface hard reset evidence](2026-11-10-surface-hard-reset-M7Q4.md).
- No database was dropped. No Active Record model class or migration was deleted. The unused
  `PromotionalEmailUnsubscribable` concern module was removed after a repository-wide caller search
  found no runtime or test caller; historical research references were left intact.

## Surface recheck

- `bin/rails routes` exited 0. The current table has 338 method rows and six mounted-engine rows,
  for 344 route entries. No unexpected route action namespace was found.
- Route counts by host remain: Auth APP 138, Auth ORG 46, Visa APP 37, Visa ORG 36, Mission 25,
  Flipper 1, Blazer 32, PgHero 26, Coverband 0, Swagger 2, and the owned hostless unknown-host
  fallback 1. No hostless Rails framework route remains.
- Controller action roots remain Auth 175, Visa 73, Mission Control 24, Blazer 31, PgHero 23, and
  the owned unknown-host fallback 1. No unexpected action root was found.
- The tracked environment template has 31 URL key names; the unsupported private Jump gateway key is
  absent. No foreign URL key name was found in the application, configuration, or library scan.

## Locked CI references

- `.github/workflows/ci.yml` remains unmodified. `findmnt` reports the `.github` mount as ZFS
  read-only, and its Git status is clean. No remount, chmod, alternate checkout, or other lock
  bypass was attempted.
- The workflow still contains 74 unique surface/performance URL key names. The original
  classification identifies 47 retired references that remain pending the approved safe update.

## Verification after the final source fixes

| Check                                        | Result                                                                                                                                                        |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bin/rails zeitwerk:check`                   | PASS — exit 0                                                                                                                                                 |
| `bin/rails routes`                           | PASS — exit 0; 344 entries as grouped above                                                                                                                   |
| `bundle exec erb_lint --lint-all`            | PASS — exit 0; 554 files                                                                                                                                      |
| `bin/rubocop`                                | FAIL — 3,759 files inspected, 220 offenses remain                                                                                                             |
| `bin/rails test`                             | FAIL — 12,357 runs, 89,536 assertions, 38 failures, 38 errors, 0 skips                                                                                        |
| Targeted RuboCop on the nine corrected files | PASS — 9 files, no offenses                                                                                                                                   |
| `ruby -c config/environments/production.rb`  | PASS — `Syntax OK`                                                                                                                                            |
| Production Rails boot check                  | NOT COMPLETED — boot stopped at the `config/application.rb` guard because no production database provider is configured; no database settings were fabricated |
| `git diff --check`                           | FAIL — seven whitespace warnings remain in existing Gait/TypeScript worktree files; no changes to those files were made for this task                         |

The 38 failure and 38 error identifiers matched the preceding full-suite recheck. The original
evidence records that checkpoint comparison; this recheck introduced no new test identifier.

The first recheck incorrectly stated that RuboCop had no new offense sites. Comparing the current
offenses with the committed source found 10 offenses on changed lines across nine files. Those
offenses were fixed forward. The final run has zero offenses on added or changed Ruby lines; the
remaining 220 offenses are on unchanged lines. The previous global count was 234.

The production boot limitation is separate from the requested test environment. The missing
production database provider is not configured or inferred by this task, which does not authorize
database configuration or deletion.

## Documentation recheck

- Removed the stale Performance development-host row from `README.md`.
- Updated the Access section of `plans/2026-11-08-cloudflare-tunnel-split.md` from seven operator
  hosts and eleven public hosts to the six retained operator tools and ten public hosts. Removed the
  retired Access Performance host from its list. Kept the generic cross-repository tool set with an
  explicit note that Access retired Performance and each repository serves only tools it owns.
- Marked `plans/ai-umaxica-global-foamy-ember.md` as a historical implementation plan. Its
  Performance steps remain as provenance and link to the accepted retirement decision and current
  surface spec. The retirement ADR and the open CI follow-up backlogs remain available as decision
  history and outstanding work.
- Reconciled the current surface rule, SRS, HLD, DDS, engine boundary, external-scan procedure,
  actor naming, i18n guidance, test specification, dictionary, encryption guidance, forbidden-method
  reference, and identity regression checklist with the retained local `app` and `org` surfaces.
  These documents distinguish retired local `com` routing/UI from retained legacy `Com` data models.
- Kept documents that explicitly identify themselves as historical, plus model/data ownership
  descriptions and the former `com` preference mapping marked historical. Those records do not claim
  an active `com` route or UI.
