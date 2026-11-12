# Retained OP logout regression adaptation

HEAD: `f84c87b060876a25994e30e9274420d9067f1367`. The substantially dirty worktree
includes the accepted non-OP retirement and new OP resolver/logout boundaries.

Seven existing logout test files were inspected and adapted. Setup now uses actual OP
roots, stable devices, scalar principal IDs, public-subject snapshots, signed browser
JWTs and real encrypted grant logout hints. Retired account/settings fixtures and unused
copied helpers were removed. Rewritten cases inline setup, token construction, actions,
cleanup and assertions; no custom test helper calls or new helpers were introduced.
The primitive source, SignOidcLogout and the parent's new existing-session suite were
not changed by this slice.

Removed cases, each formerly generated for APP and ORG:

- Anonymous Preference JWT issuance after committed logout.
- Copying display, consent, push, receipt and browser-binding settings after logout.
- Preference-copy transaction failure after an OP stop.
- Preference-token issuance failure after an OP stop.
- Successful silent-authorization coordinator/continuation behavior.
- CSP allowances for the now-unavailable silent-authorization continuation.

The authorization GET regression now asserts an explicit unavailable response without
an OP stop or device revocation. The removed rootless risk test formerly fabricated a
local principal-wide identity event/epoch. Its replacement requires explicit refusal and
zero authority-stop writes. Root-scoped risk still verifies the actual root stop and
unchanged OP epoch.

Preserved contracts include root/grant/device revocation, other-device and other-realm
isolation, preconditions under the device lock, rollback on root/grant/device write errors,
safe failure logging, lost-commit confirmation, unreadable commit outcomes, no successful
GET revocation, hint signature/issuer/audience/expiry checks, stale confirmations,
idempotence, cookie preservation on stop failures and unknown outcomes, post-commit
notice/Jump failure behavior, durable pending delivery after enqueue failure, and actual
separate-connection rotation/stop/refresh ordering.

Command used `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test bin/rails test`
with these files:

- `test/controllers/concerns/authentication/logout_current_session_test.rb`
- `test/controllers/concerns/authentication/logoutable_test.rb`
- `test/controllers/concerns/authentication/logout_resolver_round_trip_test.rb`
- `test/integration/oidc_current_device_logout_test.rb`
- `test/integration/oidc_logout_realm_acceptance_test.rb`
- `test/integration/oidc_logout_enqueue_failure_test.rb`
- `test/concurrency/oidc_logout_rotation_acceptance_test.rb`

Actual first run: 94 tests, 322 assertions, 8 failures and 43 errors. Errors were fixture
strict loading from the generated `create_logout_hint!` association method and a removed
cookie constant. Fixtures now instantiate the hint model directly and use the current
cookie-name value.

Actual second run: **94 tests, 621 assertions, 28 failures, zero errors/skips**.
All remaining failures are public locale/canonicalization discrepancies: `lx=en` rendered
Japanese text (26), or absent `ri` rendered directly instead of the previous 302 region
canonicalization (2). Their assertions remain intact pending the owning source decision.
The failure log is `tmp/op-retained-logout-regressions-second.log`. The parent received
these actual findings and the base PostgreSQL slot was released.

The parent restored the DB-free locale and region boundary in `VisaBrowserRequestContext`
and explicit Visa Authority callbacks. The concern uses lexical `I18n.with_locale`, the
existing RequestContextContract region default/allow-list and explicit `en`/`ja` request
locale support. JSON requests do not receive the browser canonicalization redirect.
No test assertions were weakened and no settings or account lookups were restored.

The parent reran the seven files above together with the original six
`step_up_evidence_state_contract` cases: **100 tests, 1,045 assertions, zero failures,
errors or skips** (`tmp/op-logout-locale-state-green.log`). This supersedes the pending
28-failure result above. RuboCop passed all seven adapted files with no offenses.

No passing full-suite, final coverage or real Governance result is claimed here.
