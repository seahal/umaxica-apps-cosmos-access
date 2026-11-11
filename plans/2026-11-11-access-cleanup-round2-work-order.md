Task (umaxica-apps-cosmos-access): cleanup round 2 and primary-only reads. Destructive removal is
approved; no compatibility layer; no commit. Never print secrets or environment values.

## Access's surfaces (the only correct list; read this first)

Access is the OpenID Provider and sign-in/sign-out component only
(adr/access-is-a-pure-openid-provider.md). OWN, keep:

- auth: app and org (`auth.umaxica.*`; development `auth.app.localhost`, `auth.org.localhost`):
  sign-in, sign-up, step-up, verification, credential ceremonies (passkey, TOTP, social sign-in
  callbacks), sign-out confirmation
- visa: app and org (`visa.umaxica.*`): OIDC/OAuth endpoints, JWKS, DBSC, OP sessions
- operator tools: mission, flipper, blazer, pghero, coverband, swagger
- unknown-host 404 fallback

Everything else is foreign: base, tech (Governance); core, warp, palm (Sphere); edit, docs, news,
help, info (Press); guid, performance, and every `.com` surface.

The 2026-11-10 surface hard reset already removed foreign Rails routes and controllers
(evidence/2026-11-10-surface-hard-reset-M7Q4.md). Do not re-add anything it removed.

## Do not touch

config/credentials/_.yml.enc (rotated and cleaned on 2026-11-11), .devcontainer/\*\*, .env_ values
(you may remove variable names listed below, never print values), docs/backlog/**, plans/**,
evidence/** (except your new record), adr/**, models and migrations (no model or table removal in
this task).

## Part A: remove leftovers

1. Front-end pages of foreign surfaces: `src/pages/base`, `src/pages/core`, `src/pages/palm`,
   `src/pages/warp`, and every src feature, component, entrypoint, style, asset and gait/Vitest test
   used only by them. Confirm first that no Access entrypoint or Inertia page registry references
   them; report any reference you find instead of deleting it.
2. The Auth settings dashboard: `resource :settings, only: :show` in config/routes/auth.rb,
   `app/controllers/auth/app/settings_controller.rb`, its views, locale keys used only by it and its
   tests. Access serves ceremony screens only; lists and dashboards belong to Governance. KEEP the
   ceremony entry points under `settings`: `settings/totps` (new, create),
   `settings/totps/enrollment`, `settings/totps/handoff`. REPORT ONLY, do not change:
   `settings/apple` and `settings/google` (show, edit, create, destroy) and
   `app/controllers/auth/app/preferences_base_controller.rb` — list which actions are ceremonies and
   which are display screens.
3. Object storage, per docs/backlog/2026-11-10-access-no-object-storage.md (Access only; other
   repositories keep Shrine and S3): stop loading `active_storage/engine`; delete
   `config/storage.yml`, the `storage` database entry; remove gems `shrine` and `aws-sdk-s3` (keep
   `aws-sdk-sns`), `config/initializers/shrine.rb`, `app/uploaders/**`, `lib/object_storage_*.rb`,
   `lib/tasks/object_storage.rake`, `app/models/publishing/media_file.rb` only if nothing else in
   Access uses it, and the `OBJECT_STORAGE_*` variable names from .env.container.devcontainer, .env
   templates, compose and CI. Do not drop the storage database itself; report it for the database
   step.
4. Service Worker leftovers, per docs/backlog/2026-11-10-access-no-service-worker.md: delete built
   worker registration files under `public/vite*/assets/` (check they are build output; never commit
   build output), make sure no build configuration produces a worker, and add a static guard test
   that Access source never calls `navigator.serviceWorker.register`. Do not add Clear-Site-Data
   changes in this task; report the proposal only.

## Part B: primary-only reads

Per docs/backlog/2026-11-11-no-automatic-replica-reads.md: remove `database_selector`,
`database_resolver` and `database_resolver_context` from `config/initializers/multi_db.rb` so every
read uses the primary. Report every remaining `connected_to(role: :reading)` in app/ and lib/. Add a
request test: after an OP session is revoked by a server-side write outside the browser's session,
an immediate `GET /oauth/authorize` from that browser does not issue a code.

## Checks

Run bin/rails zeitwerk:check, bin/rails routes, bin/rubocop, bundle exec erb_lint --lint-all, bun
run check, bin/rails test. The baseline before this task is 38 failures and 38 errors in bin/rails
test (evidence/2026-11-10-surface-hard-reset-M7Q4.md); compare failure identifiers and report new
failures separately from pre-existing ones. Before finishing, confirm:

- `src/pages/` contains no base, core, palm or warp directory;
- `bin/rails routes` lists only auth, visa, operator-tool and fallback routes, and no
  `settings#show`;
- `config/routes/` still contains auth.rb, visa.rb and the operator-tool files only.

## Report

Record in evidence/YYYY-MM-DD-access-cleanup-round2-XXXX.md (full `git rev-parse HEAD`; note that
uncommitted changes affected results): removed paths summary, the report-only findings (Apple,
Google, preferences base, storage database, Clear-Site-Data proposal, remaining reading-role uses),
check results with old/new failure split. No commit.
