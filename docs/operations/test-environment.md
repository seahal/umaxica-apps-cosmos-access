# Rails test environment

Rails tests use explicit test-only PostgreSQL databases and Valkey logical databases declared in
`config/valkey.yml`. A test process must not inherit the development host or the development Valkey
databases.

Canonical Compose services are `valkey-cache` and `valkey-kvs`. Test cache does not connect to
Valkey; it uses `ActiveSupport::Cache::MemoryStore`. Rate-limit and auth-state use `valkey-kvs`
logical DBs 4 and 6.

Inside a Dev Container the supported entry point is:

```bash
bundle exec rails test
bun vitest run
```

Orchestration supplies `VALKEY_KVS_HOST`. Do not export `VALKEY_TEST_HOST`, `CACHE_REDIS_URL`,
`RATE_LIMIT_REDIS_URL`, `AUTH_STATE_REDIS_URL`, or a run namespace before those commands. Rails
generates `VALKEY_NAMESPACE_RUN_ID` when it is absent.

`config/database.yml` fixes every test database to `primary:5432` as `root` (password
`development`); no environment variable selects the test PostgreSQL target, so an exported variable
cannot redirect a destructive preparation. `Umaxica::TestEnvironment::DatabaseSafety` holds the same
fixed values and validates every effective test database configuration before opening Active Record
connections. `DATABASE_URL` and other database URL overrides cannot silently redirect a test
connection to a non-test database.

Application auth-state and rate-limit keys include the run and worker identifiers. Parallel Minitest
workers share logical DBs 4 and 6 and isolate keys by namespace (`<run-id>:<worker-id>:…`). Cleanup
uses prefix SCAN + DEL. `FLUSHDB` and `FLUSHALL` are forbidden.

The test boundary prevents provider delivery: Action Mailer uses the `:test` delivery method, the
SMS provider is `test`, and Turnstile is replaced by `TurnstileVerifierStub`. An unstubbed Turnstile
call raises a test-boundary error rather than invoking Cloudflare. Faraday requests are blocked
unless the test uses `OutboundHttpStub` (or another explicit test adapter) for the duration of the
request.

For a standalone Puma server exercised by TypeScript Playwright and Chromium, see
[Rails browser E2E](rails-browser-e2e.md). That command uses the ordinary configured test databases
and enables real CSRF only in its browser-server process. Neither command requires a PostgreSQL
manifest or per-run database fleet. Both share a process lock and must not run concurrently.

## Rails System Test

`test/application_system_test_case.rb` uses Rails' `driven_by :playwright` integration with
Capybara and Chromium. It reuses `test_helper.rb` for fixtures, Vite builds, database safety,
the test-process lock, and Valkey isolation. Select one worker before loading that helper:

```bash
RAILS_ENV=test PARALLEL_WORKERS=1 \
  PLAYWRIGHT_CLI_EXECUTABLE_PATH=./node_modules/.bin/playwright \
  bin/rails test:system
```

Install the locked JavaScript dependencies and the Chromium build for that CLI first. The CLI
path is explicit so the driver cannot download an unpinned version through `npx`. The initial
local verification used Ruby client 1.64.0 and the installed CLI 1.64.1; exact-version alignment
and the bundled Chromium build still need verification before making this a mandatory CI gate.
To use an already installed Chromium, supply `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium`;
this enables Chromium's sandbox. In environments that start Ruby's remote debugger automatically,
also supply `RUBY_DEBUG_ENABLE=0` for unattended execution.

CSRF remains at the ordinary test-environment default (disabled); do not set `RAILS_BROWSER_E2E`
for this command. The separate TypeScript E2E retains its existing CSRF setting. System tests
currently cover the Auth liveness response and browser back navigation to the retired Auth root.
The current Auth root returns `unknown_host`; the historical TypeScript public-landing test assumes
a React page there and no longer matches the current routes. No authentication admission is
fabricated to restore that page. React, forms, and authentication journeys remain follow-up scope.

Rails saves failure screenshots under `tmp/screenshots/`; application diagnostics use `log/test.log`.
These artifacts can contain page data and must be reviewed before sharing. The current smoke
endpoints load no external assets; browser-wide external-network enforcement remains follow-up
work before expanding the suite to provider-backed pages.

Ordinary `bin/rails test` excludes system tests. Local coverage now uses this same selection.
The GitHub coverage command still explicitly selects `test/`, which would also load the browser
suite; change it to `env COVERAGE=true bin/rails test` before merging this addition. The workflow
file is mounted read-only in the current executor, including outside its sandbox, so that one-line
correction could not be applied here. System tests are currently an explicit local command;
automatic System Test jobs and required deployment gates are not yet configured.
