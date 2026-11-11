# Public Entrypoints

## Scope

This inventory covers local Auth APP/ORG and Visa APP/ORG Rails routes. Auth serves credential
ceremonies; Visa serves the OpenID Provider and Authorization Server. Visa's external RP client
registrations remain available, but RP callbacks, browser sessions, and local completion routes are
owned by the external RP repositories. Mission, Flipper, Blazer, PgHero, Coverband, and Swagger are
operator tools, not public product entrypoints.

Every application entrypoint is private by default unless its concrete controller/action declares
`AUTHENTICATION_MODE = :bare`, `:open`, or `:guest`.

| Mode        | Login required?         | Meaning                                                                                               |
| ----------- | ----------------------- | ----------------------------------------------------------------------------------------------------- |
| `:bare`     | No                      | No application authentication lifecycle; used for health, protocol metadata, and telemetry intake.    |
| `:open`     | No                      | Anonymous and authenticated actors may enter; invalid credentials still fail through normal handling. |
| `:guest`    | No for anonymous actors | Guest ceremony entry; signed-in actors are rejected or redirected by the flow.                        |
| `:private`  | Yes                     | Normal authenticated endpoint; not public.                                                            |
| `:deny_all` | Not reachable           | Fail-closed endpoint; not public.                                                                     |

## Public route families

The category IDs below are the maintained inventory for the retained public route families. Adding a
public route requires assigning it to an owned category and updating its enforcement coverage.

| ID                            | Local routes                                                                                             | Boundary                                                                                                                                     |
| ----------------------------- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `PUBLIC_LOCAL_AUTH_ADMISSION` | Auth `GET /ceremony_bindings`; Visa APP/ORG ceremony-binding confirmation                                | Opaque, short-lived references attach to the exact browser and transaction; confirmation remains guarded.                                    |
| `PUBLIC_HEALTH`               | Auth and Visa APP/ORG `/health`, `/health/*`, `/api/v0/health.json`                                      | Health output exposes no topology or configuration. Public edge isolation follows [`health-check.md`](../operations/health-check.md).        |
| `PUBLIC_REVISION`             | Auth and Visa APP/ORG `/revision`, `/api/v0/revision.json`                                               | Deployment identifier only; no database, actor, session, or environment listing.                                                             |
| `PUBLIC_CSP_REPORTS`          | Auth and Visa APP/ORG `POST /csp-violation-report`                                                       | Unauthenticated browser telemetry only; it cannot mutate actor, session, or account state.                                                   |
| `PUBLIC_WELL_KNOWN`           | Auth and Visa APP/ORG `GET /.well-known/jwks.json`; Visa APP/ORG `GET /.well-known/openid-configuration` | Public signing keys and Visa OIDC metadata. Auth is not an OIDC Provider or RP.                                                              |
| `PUBLIC_ROBOTS_SITEMAPS`      | Auth and Visa APP/ORG `/robots.txt`; Auth APP/ORG `/sitemap.xml`                                         | Crawler metadata only.                                                                                                                       |
| `PUBLIC_PREFERENCE`           | Auth APP/ORG `GET`/`PATCH /api/v0/preferences/{cookie,theme}`                                            | Own-host chrome state only; it does not grant identity or session authority.                                                                 |
| `PUBLIC_WEB_EDGE`             | Auth APP Email OTP delivery; Visa APP/ORG `/edge/v0/token/{check,dbsc,refresh}`                          | Public transport endpoints retain their delivery, token, DBSC, browser-binding, and rate-limit checks.                                       |
| `PUBLIC_OAUTH_OIDC_SSO`       | Visa APP/ORG `/oauth/*` and `/oidc/*`; Auth OIDC handoff                                                 | Client registration, redirect, state, nonce, PKCE, token, and session checks remain enforced. Visa is the local OP/AS.                       |
| `PUBLIC_SIGN_IN_UP`           | Auth APP/ORG sign-in and supported sign-up entries, cancellation and switch; APP provider sign-in/up     | Anonymous entry is ceremony-bound. Provider state, browser continuity, CSRF, rate limits, and action-specific authorization remain required. |
| `PUBLIC_AUTH_STEP_UP`         | Auth APP/ORG `/verification*`, Auth APP `/settings/totps*`; Visa APP/ORG sensitive-admission endpoints   | Ceremony and registration evidence is purpose-bound and does not itself establish session freshness.                                         |
| `PUBLIC_SOCIAL`               | Auth APP/ORG social link and provider callback routes                                                    | Provider/state validation and ceremony records own execution safety.                                                                         |
| `PUBLIC_APPLE_NOTIFICATIONS`  | Auth APP `POST /apple/notifications`                                                                     | Apple Server Notifications V2 webhook; JWS verified, not session-authenticated.                                                              |

The exact host constraints and verb/path inventory are the live Auth and Visa route files under
`config/routes/`. The PWA offline category and all non-Auth/Visa product surfaces are outside the
current public-entrypoint inventory.

## Host availability gate

The per-host availability gate applies to Auth APP/ORG and Visa APP/ORG controller surfaces. Its
only slots are `auth_service`, `auth_staff`, `visa_service`, and `visa_staff`, each controlled by
its corresponding `fqdn_available_<slot>` Flipper feature. A disabled or unwritten availability
feature refuses the host before rate limiting, session access, authentication, or controller
execution. The slot comes from the host registry, not the request's Host value. Mounted operator
tools use their own authentication and are outside this controller gate.

Health endpoint edge exposure remains governed by the health isolation policy; changing a public
surface availability flag does not change that separate edge policy.

## Default rule

Routes not in an explicit public family must resolve to `:private` or `:deny_all`, and their
concrete controller/action must declare that classification. A registered external RP client does
not make its callback or session routes public in Access because those routes are not served here.
