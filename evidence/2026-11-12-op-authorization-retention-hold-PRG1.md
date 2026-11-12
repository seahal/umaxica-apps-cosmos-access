# OP authorization history retention without Governance claim lookup

HEAD: `f84c87b060876a25994e30e9274420d9067f1367`. Results include substantial
uncommitted non-OP retirement and OP-boundary work in the shared worktree.

The approved scope preserves authorization history that still requires Governance
credential-claim reconciliation. The existing optional APP secret-flow relationship
identifies that dependency; this change adds no NULL state, column or association.
The owner approved per-row holds with an explicit delayed error after independent
APP/ORG collection completes.

`OidcAuthorizationTransactionPurger` now locks and rechecks each parent's retention
eligibility in its realm transaction. A secret-linked APP parent raises
`GovernanceLookupUnavailableError` before any child cleanup. That candidate transaction
rolls back. Only this explicit external-authority error is deferred; independent parents
and the other realm finish, then the error is raised to the caller/job. Nothing fabricates
a claim outcome, clears ownership or deletes held history. Local session-limit and
admission retention owners still decide whether their children can be collected.
Finite, positive retention inputs are validated before querying or deleting history.
The original `.call` arguments and successful `{ "app" => count, "org" => count }` return
shape remain unchanged. The existing scheduled job delegates unchanged and exposes the
error. Queue configuration, schemas and production/shared databases were not modified.

Actual TDD:

- Red: six tests, three assertions, two failures and three errors. Existing APP collection
  raised a removed `AppZenithRecord` NameError; the mixed-history case expected the explicit
  Governance error; invalid retention raised an incidental TypeError.
- Initial Green: six tests, 31 assertions, zero failures/errors/skips.
- Additional exact-count assertions exposed unrelated eligible rows in the disposable test
  database. Automatic approval rejected a proposed replacement with before/after deltas as
  potentially weaker; that combined edit/run did not execute. The safer alternative keeps
  the fixed deletion counts and makes existing disposable parent rows ineligible only inside
  framework-rolled-back test transactions before constructing the case's own eligible rows.
- Final Green: **eight tests, 56 assertions, zero failures, errors or skips**.

The tests exercise microsecond before/at/after retention boundaries, live-row retention,
count keys and fixed deletion counts, invalid input partitions, exact preservation of the
held parent/flow/receipt/resolution attributes, independent APP and ORG progress, open
resolution holds, RESOLVED continuations lacking a root, terminal child-before-parent
collection and scheduled-job failure visibility. SQL-created receipt fixtures represent
retained pre-cutover evidence; they do not assert that new receipt issuance is available.
No custom test helpers or production test branches were added.

Final command:

```sh
env -u POSTGRESQL_TEST_PREPARE_DATABASES -u COVERAGE RUBY_DEBUG_ENABLE=0 RAILS_ENV=test \
  bundle exec ruby -r ./tmp/authorization_purger_coverage.rb bin/rails test \
  test/operations/oidc_authorization_transaction_purger_test.rb \
  test/jobs/oidc_authorization_transaction_purge_job_test.rb
```

Log: `tmp/authorization-purger-coverage-green.log`.
Scoped coverage for the purger and unchanged job: lines 60/60 (100%), branches 18/19
(94.74%), methods 8/8 (100%). This is not whole-application coverage.
RuboCop passed the source and two dedicated test files with no offenses.

Governance-dependent history remains intentionally retained and the recurring job will
continue to report unavailable until a real claim-retention API exists. The historical
purge description in `specs/sign-fqdn-integrated-plan/plan.md` and corresponding retention
checklists need the owner's documentation follow-up; they were not rewritten here.
No full-suite or real Governance integration result is claimed.
