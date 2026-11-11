# Local Auth/Visa Boundary and External RP Registrations

This document describes the current local ownership after the 2026-11-10 surface reset. Earlier
Base-led and multi-RP architecture remains in
[`adr/base-auth-ceremony-and-seven-rp-boundary.md`](../../adr/base-auth-ceremony-and-seven-rp-boundary.md)
as decision history; it does not define current Access routes or controllers.

| Role                                   | Local Access owner                                   | Current responsibility                                                                       |
| -------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| OpenID Provider / Authorization Server | Visa APP and ORG                                     | Discovery, JWKS, OAuth/OIDC authorization and token endpoints, logout, and DBSC endpoints    |
| Credential ceremonies                  | Auth APP and ORG                                     | Auth-owned credential entry and provider callbacks; no general login-session or OP authority |
| Operator tools                         | Mission, Flipper, Blazer, PgHero, Coverband, Swagger | Repository-local operational interfaces                                                      |

Visa remains the only local OpenID Provider. Auth provides credential-ceremony continuity and does
not issue general login sessions, refresh tokens, or Visa OP authority. Each local surface keeps its
own host, credentials, routes, controllers, views, and state.

Visa's external relying-party client registrations remain protocol configuration. Their registered
client identifiers, exact return URIs, issuer/JWKS bindings, and other accepted OIDC properties do
not create local RP routes or controllers in Access. Each external RP owns its callback, local
session, browser interface, and sign-out completion. Keep those registrations available to the
external clients that use them.

The earlier Base, Core, Warp, Palm, Edit, Tech, and other browser-RP flows documented by the ADR are
not current local Access surfaces. Models, migrations, and database connections associated with
those flows remain pending the separate model/database report and follow-up decision; their presence
does not establish an active route, controller, or writer.
