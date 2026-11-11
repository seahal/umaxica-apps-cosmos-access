# Access separation final check

Date: 2026-11-09  
HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`  
Uncommitted changes: yes; 1,545 paths were reported by `git status --short` at the start of this
check. Existing user and collaborator changes were preserved. No commit, database or volume
deletion, or external service change was made.

## Verification

| Command or check                                                      | Result                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bin/rubocop`                                                         | Passed: 4,652 files inspected, no offenses.                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `bundle exec erb_lint --lint-all`                                     | Failed: one lint error at `app/views/visa/shared/authorization_continuation.html.erb:16`; the rule rejects `javascript_tag do`. No edit was made because the continuation is security-sensitive and the lint rule's suggested inline script could affect CSP nonce handling.                                                                                                                                                                                                                  |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`      | Passed: 0 warnings and 0 errors.                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `bun run check`                                                       | Failed: 196 TypeScript diagnostics in 23 files (111 TS2307 missing-module diagnostics and 85 `typescript(no-unsafe-assignment)` diagnostics). Most missing modules are retired Base/Core/Warp/Palm pages; details were captured in `/tmp/access-finalcheck-bun-20261109.log`.                                                                                                                                                                                                                 |
| `PARALLEL_WORKERS=1 bin/rails test test/security`                     | Passed: 144 runs, 821 assertions, 0 failures, 0 errors, 0 skips.                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `RAILS_ENV=development bin/rails runner 'puts "rails_boot_ok"'`       | Passed.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `RAILS_ENV=test bin/rails runner 'puts "rails_boot_ok"'`              | Passed.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Host-header curl against a temporary loopback-only development server | Auth App/Org `/` and Visa App/Org `/` returned 404. Visa App/Org `/.well-known/openid-configuration` and `/.well-known/jwks.json` each returned 200. Each JWKS contained one public key and no private JWK members (`d`, `p`, `q`, `dp`, `dq`, `qi`, `oth`, `k`). Response bodies and key material were not printed. The temporary Rails server was stopped; port 3813 was closed afterward. Its debugger socket cleanup emitted an `Errno::ENOENT` while unlinking a socket during shutdown. |
| `git diff --check`                                                    | Passed after the documentation edits.                                                                                                                                                                                                                                                                                                                                                                                                                                                         |

The prior full-suite evidence `evidence/2026-11-09-access-separation-recheck-B5D6.md` recorded
14,882 runs, 115,444 assertions, 255 failures, and 21 errors; none of those errors were attributed
to removed route/controller references. This final-check request did not rerun the full suite.

## Retired-surface reference search

Search scope was `app/`, `config/`, `lib/`, and `test/`; `.env*` was not read. Searches covered
retired host environment keys and hostnames, route helpers, and controller constants. The broad
namespace scan also matches unrelated `Publishing::Docs/Help/Info/News` domain models and ordinary
names such as `edit`; those are not retired Rails draws.

### Intentionally retained references

- `config/environments/development.rb:193-225,250-321` and
  `lib/config_values_host_family_values.rb:136-251` retain host registrations and host-family
  parsing. This follows the owner's prior instruction that host registration is a separate work
  item. `test/lib/config_values/host_family_values_test.rb:10-45,51-84` covers this configuration
  contract.
- `app/values/oidc_client_registry.rb`, `app/values/oidc_client_stores_static_client_store.rb`, and
  `app/values/jump_rt_surface.rb` retain OIDC RP client registrations and issuer/callback origins
  for other repositories. This is the OP's external RP contract.
- Negative route/host assertions remain in `test/controllers/public_robots_routing_test.rb:21-26`,
  `test/integration/routes/auth_base_root_contract_test.rb:22-38`,
  `test/unit/security/acme_rename_inventory_test.rb:54-58`, and
  `test/integration/routes/retired_sign_out_route_test.rb`. Their purpose is to prove retired
  helpers or entrypoints are absent or rejected.
- `test/services/jump_rt/return_policy_test.rb:272-273`,
  `test/services/jump_rt/surface_identity_test.rb`, and related
  `test/services/jump_rt/issuer_test.rb` cases exercise validation and issuance for external RP
  targets, not Access-owned route draws.
- The only literal GUID retired-host hostname match was `guid.net.localhost` in
  `config/environments/development.rb:223`,
  `test/lib/config_values/host_family_values_test.rb:44,84`, and
  `app/values/fqdn_availability_registry.rb:60` (which also retains `guid.umaxica.net`).
  Host/identifier configuration was previously scoped to remain; this is not evidence of a GUID
  route.

### Remaining references needing reconciliation

- `app/controllers/concerns/browser_rp_authentication.rb:779` still calls
  `new_base_app_identity_withdrawal_session_path` in a Base-specific branch. The security invariant
  tests say current Auth/Visa controllers do not inherit this RP concern, but the helper call
  remains in executable source and is not a negative assertion or external URL. Its reachability and
  disposition need an explicit follow-up.
- `app/controllers/concerns/org_enforcement_case_page.rb:29-60` calls seven removed Base support
  route helpers. No `include OrgEnforcementCasePage` caller was found under `app/controllers`; this
  appears orphaned, but should be verified before deletion.
- `app/controllers/concerns/preference_write_boundary.rb:947-1012` still names 48
  `Base::*Controller` constants in its Base preference writer map. This is authorization-boundary
  code; it was not removed in this audit. Confirm whether the map serves a retained caller or is
  dead before changing it.
- `test/controllers/public_robots_routing_test.rb:21-26` and
  `test/integration/routes/auth_base_root_contract_test.rb:33-38` intentionally mention retired
  route helpers to assert they are absent. Test helpers in `test/resolvers/redirects/*` define local
  fake `base_app_root_path` methods for resolver examples.
  `test/concurrency/com_preference_write_purge_test.rb:83,89` still directly calls Base preference
  helpers and is not an absence check.
- Many integration tests still use Base/Core/Warp/Palm hosts and expect their UI or application
  flows (including `test/integration/surface_chrome_preference_controls_test.rb`,
  `test/integration/acme_roots_test.rb`, `test/integration/social_auth_app_flow_contract_test.rb`,
  `test/integration/html_title_contract_test.rb`,
  `test/integration/preference_get_edit_current_behavior_test.rb`, and other host-based acceptance
  tests). These are not all negative checks or external RP URL contracts. They remain for a separate
  test reconciliation; the failed `bun run check` also reflects deleted retired-page modules still
  imported by tests.
- `app/helpers/application_helper.rb:16-18` still describes health as served by
  `Base::App::HealthsController` and PWA as shared with Palm. This is a stale source comment.
- `test/integration/edge_health_routes_test.rb:13-14,46-47` contains nested `ENV.fetch` defaults for
  Core host variables. These are not changed as part of this final audit.

## Documentation

Corrected obvious current-topology errors in `README.md`: routing ownership, empty production
database configuration, development host exposure, and the current Auth/Visa/tool host table. Added
a scope notice to `docs/test.md` identifying its old surface cases as legacy and not current route
acceptance criteria. No other document was changed in this check.

Remaining documents that describe retired surfaces as current, or contain inventories requiring
owner reconciliation:

- `docs/srs.md:13-28,81-94,148-153` describes this repository as serving help/docs/news, BFF/API and
  other public surfaces.
- `docs/authorization_guide.md:42,125,141` describes Core/Base controllers and routes as active
  examples.
- `docs/design.md:37-40` describes Base/Core/Warp/Palm/Edit as RP surfaces and describes Base links
  as shared navigation.
- `docs/dds.md:7-9` has an old controller/draw inventory (though it points readers to the README for
  current topology).
- `docs/security/credential-gateway.md`, `authentication-remediation.md`, `logout-sequence.md`,
  `sign-in-sequence.md`, and `unified-enforcement.md` contain Base-owned RP, session, or route
  descriptions. Some may describe cross-repository flows; they need owner review before edits.
- `docs/reference/ui-view-inventory.md:56-57,87-97` says Base/Core/Warp remain authenticated
  surfaces, Base com routes remain, and Visa org is retired. This directly conflicts with the
  observed route set and should be reconciled before acceptance.
- `docs/security/cloudflare-access-org-authentication.md` and
  `docs/security/authentication-boundary-audit.md` describe Cloudflare Access policies for retired
  hostnames. Cloudflare state was not inspected or changed.
- `docs/engine.md` and `docs/dictionary/access-terms.md` describe docs/news/help as belonging to
  regional content or another repository; these appear to describe ownership outside Access and were
  not changed.
- `docs/operations/*` references to a Compose service named `core` describe the container/service,
  not the retired Core product surface; retained.

## Proposed commit boundaries (no commits created)

1. **Documentation:** README topology and local host guidance; reconcile current
   architecture/security inventories separately from archival specifications and external Cloudflare
   policy records.
2. **Route separation:** route draws and surface ownership changes, including remaining executable
   Base helper/controller references after their callers and authorization impact are confirmed.
3. **Test cleanup:** remove obsolete retired-UI acceptance tests and imports, preserve negative
   boundary checks, external RP contract coverage, and Auth/Visa security tests; split test-file
   changes from production routing if reviewability benefits.
4. **Configuration and dependency decisions:** Rails revision pin, explicit removal of Neon
   production config, GUID retirement while retaining identifier handling, and cache/MessagePack
   changes. Keep independently reviewable decisions separate if their deployment and recovery needs
   differ.

No commit was made. Cloudflare edge behavior and the live host alias configuration were not verified
from this local runtime.
