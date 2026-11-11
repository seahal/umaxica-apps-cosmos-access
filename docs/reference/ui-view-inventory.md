# Auth and Visa UI surface inventory

Snapshot date: 2026-11-10. This inventory covers the local browser and operator surfaces retained in
Access. Host values are omitted; host ownership is defined in the route files and boot config. The
OIDC client registry contains external redirect destinations, but those registrations do not create
local relying-party routes in this repository.

## Auth and Visa

| Surface  | Routes in current `bin/rails routes` output | Route owner                                             | Local UI source                                                    |
| -------- | ------------------------------------------: | ------------------------------------------------------- | ------------------------------------------------------------------ |
| Auth app |                                         138 | `config/routes/auth.rb`; `auth_service` host constraint | `app/controllers/auth/app`, `app/views/auth`, `src/pages/auth/app` |
| Auth org |                                          46 | `config/routes/auth.rb`; `auth_staff` host constraint   | `app/controllers/auth/org`, `app/views/auth`, `src/pages/auth/org` |
| Visa app |                                          37 | `config/routes/visa.rb`; Visa app host constraint       | `app/controllers/visa/app`, `app/views/visa`, `src/pages/visa/app` |
| Visa org |                                          36 | `config/routes/visa.rb`; Visa org host constraint       | `app/controllers/visa/org`, `app/views/visa`, `src/pages/visa/org` |

Auth owns credential and identity browser flows. Visa owns the OpenID Provider browser and protocol
flows, including the existing logout presentations. These surfaces keep their own routes, sessions,
and authorization boundaries; shared view components do not combine those boundaries.

## Operator tools

| Surface   | Routes in current `bin/rails routes` output | Route owner                                             |
| --------- | ------------------------------------------: | ------------------------------------------------------- |
| Mission   |                                          24 | `config/routes/mission.rb`; Mission Control Jobs engine |
| Flipper   |                                           0 | `config/routes/flipper.rb`; Flipper UI                  |
| Blazer    |                                          31 | `config/routes/blazer.rb`; Blazer engine                |
| PgHero    |                                          25 | `config/routes/pghero.rb`; PgHero engine                |
| Coverband |                                           0 | `config/routes/coverband.rb`; Coverband report app      |
| Swagger   |                                           0 | `config/routes/swagger.rb`; Rswag engines               |

Counts reflect the current route command invocation. Optional engine routes are present only when
the corresponding engine is loaded in that process; zero does not remove the owned host constraint
or tool configuration.

## Unregistered hosts

The one hostless root route belongs to `UnknownHostsController` and returns the shared JSON 404 for
unregistered hosts. It is infrastructure for the retained host boundaries, not a product surface.

For the complete route-by-route and controller-namespace inventories, see
[`evidence/2026-11-10-surface-hard-reset-M7Q4.md`](../../evidence/2026-11-10-surface-hard-reset-M7Q4.md).
