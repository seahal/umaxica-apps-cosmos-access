# Access operator tool retirement

Executed 2026-11-09 UTC against full HEAD `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`, with extensive
pre-existing uncommitted changes. The task baseline copies in `/tmp/access-night-baseline` preserved
the pre-task contents for scoped diff inspection. Existing TODO: AUDIT, NOTICE:, NOTE:, FIXME:,
message-pack configuration and unrelated documentation additions were preserved. Credentials
payloads were not edited or rotated. No commit, external change, development database write, volume
deletion or database reset occurred.

## Implemented, in requested order

1. Removed rails_db and its Gemfile explanation, stale concrete-class references in the controller
   inheritance invariant and ApplicationRecord explanation, and RailsDb entries in the
   mounted-engine invariant. Kept `/rails/db` forbidden and retained the other engine guards.
2. Removed rails_performance, its initializer, dedicated route file/draw, engine route suppression,
   sanitizer and store-resilience modules, their dedicated sanitizer tests and the matching test in
   the branch-coverage collection. Removed its FQDN registry entry, development Host Authorization
   entries, Valkey responsibility/catalog and exclusive writable environment declarations. Kept
   `/rails/performance` forbidden. Updated current operator-tool documentation to six tools, and
   appended retirement amendments to ADRs without erasing prior decisions or added prose.
   OpenTelemetry and the other operator tools retain their implementations and controls.

`bundle install --local` succeeded after each gem removal. Compared with the task baseline,
Gemfile.lock removes only rails_db, rails_performance and dependencies no longer needed: browser,
kaminari and its three components, ransack, simple_form. No gem version is added or upgraded. The
existing msgpack gem and message-pack serializer configuration remain.

## Required edits blocked by read-only mounts

Both `.github` and `.devcontainer` are separate read-only filesystem mounts (confirmed with
`findmnt -T`). Attempts to edit stopped with EROFS. No remount or permission bypass was attempted.
The following scoped edits are still unapplied:

- `.github/workflows/ci.yml`: remove exclusive performance public/private host, Basic-auth and
  enable-switch declarations from both job environment blocks. Values are deliberately omitted.
- `.devcontainer/compose.yaml`: remove the two performance network aliases; change the Access
  operator-tools count from seven to six; remove performance from the diagnostic-instance comment.

`.env` and `.env.container.devcontainer` no longer declare the exclusive surface variables where
present. Diagnostic Valkey host/port settings stay because Coverband uses them. Stored credentials
were not rewritten. No diagnostic data was deleted. The read-only CI/Compose files must be updated
in a writable checkout before the retirement is fully complete.

## Verification

- `bin/rubocop`: rails_db stage, 4652 files, zero offenses. Performance stage initially found one
  extra blank line after deleting the retired sanitizer test; corrected it. Final tools run: 4647
  files, zero offenses.
- `PARALLEL_WORKERS=1 OTEL_SDK_DISABLED=true bin/rails test test/security/invariants/mounted_engine_invariant_test.rb test/security`:
  rails_db stage 144 runs, 820 assertions, zero failures/errors/skips; performance stage 144 runs,
  817 assertions, zero failures/errors/skips. Test fixture work was confined to the test
  environment.
- Development `bin/rails routes`, with PostgreSQL forced read-only: zero `/rails/db`,
  `/rails/performance` or rails_performance route matches after removal. Runtime constant checks
  confirm neither retired gem is loaded.
- Actual local HTTP requests through temporary Puma on loopback port 3815, for both retired paths
  across 121 configured/local host names: each path returned 404 for 99 hosts, 401 for 16 guarded
  operator host aliases, and 403 for six Host Authorization refusals. No request reached a retired
  engine. No redirect was followed or external address contacted. The old performance hosts are
  rejected by Host Authorization, rather than returning the requested 404; other tools' guards were
  preserved instead of changing them merely to force a uniform status.
- The HTTP harness kept PostgreSQL read-only for boot and every request. Its initial attempts
  returned 500 because the development migration-check middleware calls the repository's
  `SchemaMigrationIfNotExists#create_table`, which still emits CREATE TABLE IF NOT EXISTS for an
  existing table. PostgreSQL rejects that statement in a read-only transaction. For the final
  route-only probe, a temporary before_initialize setting disabled only the development page-load
  migration check. No repository configuration or authorization/CSRF/rate-limit check was disabled.
  This is a verification limitation, not a change to the application's runtime.
- Puma stopped in ensure; `ss -ltn '( sport = :3815 )'` showed no listener afterward.
- Scoped `git diff --check` passed. Retained evidence contains names, counts and status codes only.

Docker is unavailable in this executor. Running development containers were not recreated, and no
claim is made that another running process has unloaded the gems. Container recreation and external
Cloudflare tunnel/DNS/Access cleanup remain owner operations. Historical plans/research and prior
evidence retain their original references; current runtime references are removed except for the
explicit read-only CI/Compose blockers and forbidden-path assertions.

## Ready-to-apply read-only-mount remainder

The remaining CI changes are exactly ten declarations: two occurrences each of the following five
names: PUBLIC_PERFORMANCE_URL, PRIVATE_PERFORMANCE_URL, RAILS_PERFORMANCE_USERNAME,
RAILS_PERFORMANCE_PASSWORD, RAILS_PERFORMANCE_ENABLED. Compose has exactly two retired performance
network aliases. The following value-independent transformation is prepared for a writable checkout;
it is not executed here and contains no credential values:

```python
from pathlib import Path
import re

ci = Path(".github/workflows/ci.yml")
source = ci.read_text()
keys = (
    "PUBLIC_PERFORMANCE_URL|PRIVATE_PERFORMANCE_URL|RAILS_PERFORMANCE_USERNAME|"
    "RAILS_PERFORMANCE_PASSWORD|RAILS_PERFORMANCE_ENABLED"
)
updated, removed = re.subn(r"^.*\b(?:" + keys + r")\b.*\n", "", source, flags=re.M)
assert removed == 10, "CI declarations changed; inspect names before applying"

compose = Path(".devcontainer/compose.yaml")
compose_source = compose.read_text()
compose_updated, aliases = re.subn(
    r"^.*- performance(?:-access\.umaxica\.dev|\.core\.dev\.localhost).*\n",
    "", compose_source, flags=re.M,
)
assert aliases == 2, "Compose aliases changed; inspect names before applying"
compose_updated = compose_updated.replace("operator tools (7)", "operator tools (6)")
compose_updated = compose_updated.replace("(rails_performance, Coverband, and", "(Coverband and")
ci.write_text(updated)
compose.write_text(compose_updated)
```

After applying, inspect the diff and validate the existing CI/Compose syntax without launching,
recreating or deleting services. Container recreation and external cleanup remain separate work.
