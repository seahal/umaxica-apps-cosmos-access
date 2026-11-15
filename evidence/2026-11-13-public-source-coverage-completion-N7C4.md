# Public-source Coverage Target — Current Verification

This evidence closes the requested Vitest source-coverage and Minitest public/protected method
coverage targets in `specs/public-source-coverage-completion/spec.md` for the current Access
worktree. It does not claim that the full Rails suite or repository-wide static checks are green.

## Revision and worktree

- Repository: Access, branch `feature`; `git rev-parse HEAD`:
  `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The dirty worktree had 343 changed paths before this evidence file was added. Measurements apply
  to that working tree, not to a clean checkout. No commit or push was made.
- `config/credentials/`, `.github/workflows/`, `config/ci.rb`, `.simplecov`, and `vitest.config.ts`
  had no changes at capture. No CI configuration, threshold, filter, or production coverage branch
  was changed for this verification.
- `git diff --check` passed.

## AC-1 — Vitest source coverage

Fresh command: `bun run test:coverage`.

- Test files: 18 passed.
- Tests: 115 passed.
- Statements: 126/126 (100%).
- Branches: 144/144 (100%).
- Functions: 43/43 (100%).
- Lines: 121/121 (100%).
- No source files had missing coverage; 3 empty files were skipped by the reporter.

The configured 99% thresholds were unchanged. Earlier public-source behavior tests and their
contracts are described in `evidence/2026-11-13-public-coverage-baseline-PM8Q.md`.

## AC-2 — Minitest public/protected method coverage

Fresh coverage command:

```bash
env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 COVERAGE=true RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test
```

The result was then classified with:

```bash
env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test bin/rails runner -e test script/public_protected_method_coverage.rb
```

| Visibility                 |   Covered / total |     Coverage |
| -------------------------- | ----------------: | -----------: |
| Public instance            |     1,248 / 1,256 |     99.3631% |
| Public singleton           |         547 / 550 |     99.4545% |
| Protected instance         |            9 / 10 |        90.0% |
| **Public/protected total** | **1,804 / 1,816** | **99.3392%** |

The requested aggregate is greater than 99%. The classifier excluded 2,287 private records and 23
test-only records, and reported 0 unclassified records. The protected-only figure is below 99%; the
spec's target is the combined public/protected denominator.

Twelve public/protected records remain uncovered:

- `BannerModel#actor`
- `ContactAuditOutbox::ClassMethods#record!`
- `RefreshTokenable::ClassMethods#replace_current_for_reauthentication!`
- `OidcAuthorizationTransactionCoordinator.issue_with_handoff!`
- `SignUpFinalizationContext.build`
- `AssociatedRecordLimitValidator#validate`
- `ArchitectureBaseline.write`
- `ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement#csrf_detected?`, `#extra`,
  `#info`, `#uid`, and `#authorize_params`

No private method was exposed or invoked by reflection to reduce this residual list. No production
behavior was changed for the percentage.

## AC-3 — Behavior-based test repairs

The final full run exposed three stale test assumptions in coverage-focused tests. These were
recorded as Red and corrected against the current implementation contract:

1. Batch 30/31 used the removed `Client` actor, passed the old `resource:` keyword to the ID token
   codec/issuer, and called a resource-type helper that is no longer part of that codec API. They
   now exercise `resource_type:` with the codec's current subject shape and verify the current
   `resource_type_for_client` behavior.
2. The JWK refusal test supplied malformed Base64 and expected the domain
   `JitSecurityJwtJwk::Error`, but the JOSE library correctly rejected decoding first. The test now
   supplies valid base64url bytes for a modulus below the RSA minimum, exercising the intended
   domain refusal.
3. The OIDC revocation test gave a grant an expiry slightly later than the parent root's absolute
   expiry. The fixture now sets the grant expiry to `root.discard_at`, preserving the active-session
   and expiry-boundary contract.

Focused Green results after the repairs:

- Batch 30/31: 11 runs, 35 assertions, 0 failures, 0 errors, 0 skips.
- OIDC revocation coverage file: 7 runs, 23 assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop on the three changed test files: 3 files, no offenses.
- The final full-run failure list contains no Batch 30/31 or `OidcTokenRevokerCoverageTest` failure.

These edits changed test setup and expectations only. No private-method seam or weakened product
assertion was added.

## AC-4 — Coverage command and full-suite disposition

The final full Rails run completed in 235.44 seconds with 5,695 runs, 37,025 assertions, 98
failures, 99 errors, and 0 skips. It is not a green suite result. SimpleCov reported line coverage
22,748/24,895 (91.37%), branch coverage 3,158/4,810 (65.69%), and all-method coverage 3,756/4,126
(91.03%). SimpleCov excluded 16 old subprocess results beyond its configured 3,600-second merge
window and stopped normal processing after test errors. The separate public/protected classifier
above uses the current generated result and has no unclassified records.

The coverage-focused failures found during this run were corrected and pass both focused and full
run checks. Other failures remain in the extensively modified worktree. Examples include stale
OpenAPI entries for removed preference endpoints, current routes missing from OpenAPI after route
changes, and the architecture baseline test naming concerns with no remaining offense. There is no
clean pre-change checkout result that permits attributing every remaining failure to a specific
work-order change. Those failures are recorded as unresolved suite failures, not as passing or
proven pre-existing.

The latest repository-wide static-check findings remain in
`evidence/2026-11-13-ci-static-checks-source-switch-D8K4.md`. They were not suppressed or fixed as
part of this coverage completion.

## AC-5 — Repository state

- No commit or push was made.
- No CI/CD, hook, threshold, coverage-filter, or credentials change was made.
- Existing unrelated dirty work was preserved.
