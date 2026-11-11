# Access surface hard reset

Status: implementing (accepted by repository owner, 2026-11-10)

## Purpose and authority

Remove retired and foreign in-repository application surfaces so this repository owns only Auth,
Visa, and its operator tools. The owner's 2026-11-10 task instruction authorizes this implementation
and resolves the narrower deferred route scope in
[`cosmos-press-route-ownership`](../cosmos-press-route-ownership/spec.md) for this change.

The retained application surfaces are Auth APP/ORG, Visa APP/ORG, and Mission, Flipper, Blazer,
PgHero, Coverband, and Swagger. Visa remains the OpenID Provider. The current cross-repository
connection contract in
[`cosmos-cross-repository-connection`](../cosmos-cross-repository-connection/spec.md) remains
applicable unless the owner directs otherwise.

## Scope and exclusions

Remove foreign and retired route definitions, controllers, views, helpers, concerns with no owned
caller, foreign host configuration and URL readers, related tests, and documentation that describes
those surfaces as current. Remove non-model implementation that becomes dead, repeating caller
analysis until no new dead service, value, job, policy, adapter, or concern remains.

Keep the Auth and Visa APP/ORG host boundaries, Visa's OP/OIDC protocol endpoints, JWKS and DBSC
paths, and the six named operator tools. Keep model and migration files and database configuration
for the follow-up usage review. Do not drop databases, change schemas, or remove models in this
task. Do not commit.

## Acceptance

- AC-1: Every route and controller namespace is inventoried and classified. The final route set
  serves only the retained application surfaces and justified shared framework infrastructure.
- AC-2: Foreign in-repository surfaces have no route/controller/view/helper/locale/test or host
  configuration residue. Shared code remains only with an owned caller.
- AC-3: Repeated reference analysis removes newly dead non-model implementation without deleting
  models, migrations, or database configuration.
- AC-4: `bin/rails zeitwerk:check`, `bin/rails routes`, `bin/rubocop`,
  `bundle exec erb_lint --lint-all`, and `bin/rails test` pass. Failures caused by the removals are
  fixed; pre-existing failures are reported separately.
- AC-5: `evidence/` records the full starting commit, the uncommitted-worktree caveat, retained
  route counts by host, deletion summary, database/model usage report, retained foreign-looking
  items and reasons, and actual verification results. No secret or environment value is recorded.

## Verification approach

Use the repository commands named in AC-4 after the final cleanup. Enumerate routes with
`bin/rails routes` and group them from the explicit route-file host constraints. Classify model
references from non-model application code separately from model-only and test-only references.
Preserve all database and migration files for the follow-up decision.
