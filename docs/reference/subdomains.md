# Subdomain Map

Local hosts are entry points for independent host-constrained surfaces. Access currently serves Auth
APP/ORG, Visa APP/ORG, and six operator tools.

## Application surfaces

| Surface  | Default local host   | Responsibility                                            |
| -------- | -------------------- | --------------------------------------------------------- |
| Auth APP | `auth.app.localhost` | Credential ceremonies and provider callbacks              |
| Auth ORG | `auth.org.localhost` | Organization credential ceremonies and provider callbacks |
| Visa APP | `visa.app.localhost` | APP OpenID Provider and Authorization Server              |
| Visa ORG | `visa.org.localhost` | ORG OpenID Provider and Authorization Server              |

Auth and Visa hosts remain separate. Visa's external RP registrations do not add local RP hosts or
callbacks to this map; those hosts belong to their own repositories.

## Operator tools

| Tool      | Development host               | Public canonical host          |
| --------- | ------------------------------ | ------------------------------ |
| Mission   | `mission.core.dev.localhost`   | `mission-access.umaxica.dev`   |
| Flipper   | `flipper.core.dev.localhost`   | `flipper-access.umaxica.dev`   |
| Blazer    | `blazer.core.dev.localhost`    | `blazer-access.umaxica.dev`    |
| PgHero    | `pghero.core.dev.localhost`    | `pghero-access.umaxica.dev`    |
| Coverband | `coverband.core.dev.localhost` | `coverband-access.umaxica.dev` |
| Swagger   | `swagger.core.dev.localhost`   | `swagger-access.umaxica.dev`   |

The tool hosts are separate from Auth/Visa product hosts and use their own access controls. No
additional local application surface is defined by this map.

## URL configuration names

Use the existing `PUBLIC_*_URL` names for browser-facing URLs and `PRIVATE_*_URL` names for internal
ingress URLs. Required and optional environment access follows
[`adr/env-fetch-without-default.md`](../../adr/env-fetch-without-default.md); this map does not
define code-side defaults or compatibility names.
