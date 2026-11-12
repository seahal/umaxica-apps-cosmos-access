# Initial Rails System Test execution

- Revision: `f84c87b060876a25994e30e9274420d9067f1367` (`feature`).
- Uncommitted changes affected results: new `test/application_system_test_case.rb` and
  `test/system/smoke/auth_publics_test.rb`; local coverage selection and test-environment docs
  were also updated. Pre-existing changes in Procfile, ADR, handoff, research, backlog, and
  `test/services/jump_rt/return_policy_test.rb` were preserved.
- Scope: local System Test foundation and smoke execution; no mandatory CI/deployment gate.

## Observations

`bundle check` passed. Installed Rails source supports `driven_by :playwright` directly.
Ruby was 4.0.9, the Ruby Playwright client was 1.64.0, and the installed CLI was 1.64.1.
Execution used `/usr/bin/chromium` with Chromium sandbox enabled, not a newly downloaded browser.

Executed outside the command sandbox, which cannot reach the local PostgreSQL service:

```bash
RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 \
  PLAYWRIGHT_CLI_EXECUTABLE_PATH=./node_modules/.bin/playwright \
  PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium bin/rails test:system
```

Result: **2 runs, 6 assertions, 0 failures, 0 errors, 0 skips**, 1.551426 seconds reported by
Minitest (not total process startup time). Puma listened on a dynamically allocated loopback port.
Chromium displayed Auth liveness and returned to the retired root using browser back navigation.
The existing database catalog validation completed against configured `test_*` databases and
the common helper supplied fixtures, database-process locking, and Valkey isolation. CSRF
configuration was unchanged and the browser-E2E opt-in flag was not set.

The initial test incorrectly reused the historical TypeScript expectation of an Auth root React
page. It failed with `unknown_host`; source inspection confirmed the root route is retired.
The failure saved a screenshot under `tmp/screenshots/`. The smoke tests were corrected to the
current contract; no production route or authentication bypass was added.

```bash
RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 \
  bin/rails test test/integration/auth_visa_route_host_test.rb
```

Result: **2 runs, 11 assertions, 0 failures, 0 errors, 0 skips**, 0.775004 seconds.

Final static checks: `bin/rubocop test/application_system_test_case.rb
test/system/smoke/auth_publics_test.rb config/ci.rb` passed (3 files, no offenses), and
`git diff --check` passed. The only test edits after execution added blank lines for RuboCop.

## Limits and remaining work

- Full existing Minitest, full CI, TypeScript E2E, React, forms, and authentication journeys were
  not executed. Browser-wide egress enforcement is not implemented; current endpoints load no
  external assets.
- Exact CLI/client version alignment and Playwright's bundled Chromium remain unverified.
- Local coverage now uses `bin/rails test`, which excludes system tests. GitHub coverage still
  uses `bin/rails test test/`, which includes them and needs correction before merge.
  `.github/workflows/ci.yml` is mounted read-only: both normal editing and an escalated write
  failed, the latter with `OSError: [Errno 30] Read-only file system`.
- Required workflow correction: replace `run: env COVERAGE=true bin/rails test test/` with
  `run: env COVERAGE=true bin/rails test`.
- Automatic System Test jobs and required deployment checks are not configured in this initial
  local introduction.
