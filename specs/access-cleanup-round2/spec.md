# Access cleanup round 2

Status: implementing (accepted by repository owner, 2026-11-11)

## Purpose and authority

Remove the remaining foreign frontend assets and the accepted Access-only object-storage and
automatic-replica-read dependencies. Remove the Auth settings dashboard while preserving the
explicitly retained ceremony routes and the report-only Apple/Google and preference controller
surfaces. The accepted implementation scope is recorded in the owner-provided
[`round-2 task prompt`](../../tmp/access-cleanup-round2-prompt.md).

This specification continues the [Access surface hard reset](../access-surface-hard-reset/spec.md).
It does not reopen removed routes or controllers.

## Scope and exclusions

Remove foreign-only frontend source, tests and build leftovers after confirming that no Access
entrypoint or Inertia page registry references them. Remove Active Storage engine loading, Shrine
and S3 dependencies, their configuration and upload code, the `storage` database configuration
entry, and `OBJECT_STORAGE_*` variable names in writable in-scope files. Keep the database itself,
its migrations and schema artifacts. Remove the automatic database selector and any explicit
application read-role calls that contradict primary-only reads, then verify server-side OP session
revocation through an immediate authorization request.

Do not modify `.devcontainer/**`, `.github`, credentials, backlog/plan/ADR documents, prior
evidence, or migrations and schema files. Do not drop databases, change tables, or commit. Do not
change Clear-Site-Data behavior. The report-only Apple/Google and preference controller findings
must be recorded with the final evidence.

## Acceptance

- AC-1: No `base`, `core`, `palm` or `warp` page tree or foreign-only frontend artifacts remain
  under `src/` or `gait/`; no Access entrypoint or Inertia page registry references those page
  trees.
- AC-2: Auth has no `settings#show` dashboard route, controller, dashboard-only view, locale key or
  test. The TOTP ceremony entry points remain. Apple/Google show/edit/create/destroy routes and
  actions remain; only return and back-link destinations that depended on the removed dashboard are
  updated, as authorized by the owner on 2026-11-11. Their action classifications and the
  `PreferencesBaseController` role are reported.
- AC-3: Access loads no Active Storage engine and has no Shrine/S3 object-storage implementation or
  `OBJECT_STORAGE_*` names in writable in-scope files. The `storage` database and schema history are
  retained for a separate database decision.
- AC-4: No Access source or build configuration registers a Service Worker, no built worker
  registration asset remains, and no Access route serves a worker script. A static guard covers
  source registration and worker routes. Clear-Site-Data is unchanged.
- AC-5: Automatic role switching is removed, no explicit `connected_to(role: :reading)` remains in
  `app/` or `lib/`, and an immediate `GET /oauth/authorize` after an out-of-browser server-side OP
  session revocation does not issue an authorization code.
- AC-6: Run and record `bin/rails zeitwerk:check`, `bin/rails routes`, `bin/rubocop`,
  `bundle exec erb_lint --lint-all`, `bun run check`, and `bin/rails test`. Compare test failure and
  error identifiers with the 38-failure/38-error baseline and distinguish new failures.
- AC-7: A new evidence record includes the full `git rev-parse HEAD`, the uncommitted-worktree
  caveat, removals, report-only findings, remaining read-role sites, storage database disposition,
  verification results, and any `.github` lock limitation. It contains no secret or environment
  values.

## Verification

Use the task's listed commands after all source changes are complete. Inspect final routes, source
references, worker build configuration and route recognition. Test the revocation property through
the HTTP request boundary. Record exact results and scope in the new evidence record.
