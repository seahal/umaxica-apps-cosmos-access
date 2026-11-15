# Public source coverage completion

Status: verified. Acceptance authority: the user's 2026-11-13 request to finish the Access work in
progress, then raise Vitest public-source coverage to 99% and Minitest public/protected method
coverage above 99%.

Progress: AC-1 and AC-2 pass on the current dirty worktree: Vitest statements, branches, functions,
and lines are each 100%; Minitest public/protected methods are 1,804/1,816 (99.3392%). Related
coverage tests and scoped lint pass. The full Rails suite remains non-green (98 failures, 99
errors); those aggregate failures are recorded without being claimed as passing or fully attributed.
See [final coverage evidence](../../evidence/2026-11-13-public-source-coverage-completion-N7C4.md).

## Purpose

Increase confidence in shipped public behavior by making the JavaScript source and Ruby
public/protected method surface observable and exercised by meaningful tests. Coverage is an outcome
of behavioral verification; the work must not weaken product contracts or make code unreachable
solely to improve a percentage.

## Scope

- All production files under `src/` included by `vitest.config.ts`.
- Public and protected methods defined under `app/` and `lib/`, measured from the current Minitest
  SimpleCov result and classified by runtime visibility.
- Tests and proportionate analysis tooling needed to measure and verify the requested metrics.
- Evidence of baseline, red/green work, verification and unresolved limits.

## Exclusions

- No change to CI/CD, GitHub Actions, hooks or workflow definitions.
- No lowering, excluding or bypassing existing coverage thresholds.
- No test-only production branches, reflection tests of private behavior, swallowed suite failures,
  or behavior changes made only to affect coverage.
- Existing unrelated dirty worktree changes remain untouched.

## Acceptance

- AC-1: `bun run test:coverage` passes with each existing Vitest source metric (statements,
  branches, functions and lines) at or above 99%, with the configured thresholds unchanged.
- AC-2: The Minitest SimpleCov result shows greater than 99% coverage of application/library public
  and protected method records. Private methods are not part of this requested measure. Test-defined
  classes that exist only to host a concern in tests are excluded from the production API
  denominator and identified explicitly.
- AC-3: Every added test observes a public behavior or contract; tests reach private behavior only
  through its public caller. Unreachable or superseded code is removed only when current routes,
  callers and accepted contracts establish it is no longer needed.
- AC-4: Relevant tests, lint/format and coverage commands are run and recorded. Existing suite
  failures are distinguished from change-caused failures. No unverified result is reported as
  passing.
- AC-5: No commit or push is made.

## Risks and assumptions

- The checkout contains extensive pre-existing uncommitted Access work and deletions; measured
  coverage therefore describes this exact dirty tree, not a clean `HEAD` baseline.
- The full Minitest suite currently reports failures and errors. Any production path those tests
  cannot reach needs contract-level review before adding success-path coverage.
- The requested public/protected metric is distinct from SimpleCov's configured all-method metric.
  The report must include its classification and denominator, not substitute the all-method
  percentage.
