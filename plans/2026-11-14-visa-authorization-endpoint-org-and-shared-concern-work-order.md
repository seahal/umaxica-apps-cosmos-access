Task (umaxica-apps-cosmos-access only): reopen the authorization endpoint on both Visa realms
through one shared concern. This extends and restructures
`plans/2026-11-14-visa-app-authorization-endpoint-reopening-work-order.md`: everything that order
says about boundary, what is not restored, stop conditions, tests and checks still applies; only the
differences are written below. If that order is not finished yet, do both together and build the
shared concern from the start. No commit. Never print secrets, key material or environment values.
Never edit config/credentials/*.yml.enc. No push, no deploy, no Cloudflare change, no change outside
this repository.

## Decision

Owner, 2026-11-14: open Org together with App. Shared parts live in concerns; realm controllers only
declare what differs.

## Observed

- At `727cdb560~1`, `app/controllers/visa/app/authorization_base_controller.rb` and
  `app/controllers/visa/org/authorization_base_controller.rb` were near-copies (109 differing lines
  in about 300). For the authorization start in scope, they differ only in: Auth host variable
  (`PUBLIC_AUTH_SERVICE_URL` / `PUBLIC_AUTH_STAFF_URL`), resource (`current_client` /
  `current_operator`, `Client` / `Operator`), Auth sign-in sentry route helper (`auth_app_…` /
  `auth_org_…`), result surface (`"app"` / `"org"`), and route helpers for the Visa realm. The
  remaining differences (secret sign-in finalisation for App, session-limit refusal for Org) belong
  to the result handling that this work does not restore.
- The two `oauth/authorizations_controller.rb` files were identical apart from the module name.
- Governance is restoring Base Org next (`base-org-ww`, Base Org origin, `/oidc/callback`); Jump has
  the `base-org-ww` ↔ `visa-org-ww` edges. Visa Org is `https://visa.umaxica.org`.
- Org has no public sign-up (`config/routes/auth.rb` comments: "Org has no public sign-up").

## Work

1. Put the authorization start (request size and rate limits, request resolution, error responses,
   `prompt=none` → `login_required`, transaction and handoff issue, redirect through Jump to the
   realm's Auth sign-in sentry) in concerns under `app/controllers/concerns/`. Reuse the concern
   names from history where they fit (`OauthAuthorizeRateLimit`, `OauthAuthorizeRequestSizeLimit`,
   `OidcAuthorizationRequestErrors`) and add one concern for the start itself. Realm controllers
   provide private hook methods with no default (a missing hook raises): surface, resource and its
   class, resource type, Auth host, sentry URL builder, Visa route helpers. No `case realm` inside a
   concern. Follow `generic/rails-concerns.mdc` and
   `docs/architecture/method-visibility-and-concerns.md`.
2. `Visa::App::Oauth::AuthorizationsController` and `Visa::Org::Oauth::AuthorizationsController`
   become thin (include, declare mode, hooks). Do not restore the two
   `authorization_base_controller.rb` copies unless something outside this scope needs them; if they
   come back, they hold hooks only.
3. Route both realms' `authorization` resource (`show`, `create`) to their controllers; remove the
   authorization entries from the unavailable ceremony controllers' routing. Auth ceremonies stay
   503 on both realms.
4. Org specifics: an App client on the Org endpoint and an Org client on the App endpoint are
   refused before any redirect; `prompt=create` on Org follows what the history did (find it and
   keep it; if history accepted it, report it as an owner question rather than changing it).
   `Operator` is used where App uses `Client`.

## Tests

Run the App tests from the App order; then cover Org with the same cases, preferring one test body
run for both realms where helpers allow. Add: cross-realm client refused both ways; Org request from
`base-org-ww` exactly as Governance will send it answers 303 through Jump to the Auth Org sign-in
sentry; `ceremony_unavailable_test.rb` no longer expects 503 from either authorization route.

## Checks and report

As in the App order. Evidence in
`evidence/YYYY-MM-DD-visa-authorization-endpoint-org-and-shared-concern-XXXX.md`: hook list, what
moved from the history's base controllers into concerns and what was dropped, App and Org results,
owner items, and confirmation that config/credentials files are unchanged.
