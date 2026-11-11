# Access Surface Ownership

Current implementation scope, 2026-11-10: this repository serves only the Auth and Visa application
surfaces and its operator tools.

| Owner             | Local surface                                        | Responsibility                                                                                              |
| ----------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Auth              | APP, ORG                                             | Credential ceremonies, provider callbacks, and the surfaces' own browser preference controls                |
| Visa              | APP, ORG                                             | OpenID Provider and Authorization Server, including discovery, JWKS, OAuth/OIDC, logout, and DBSC endpoints |
| Access operations | Mission, Flipper, Blazer, PgHero, Coverband, Swagger | Repository-local monitoring and operator tools                                                              |

This repository has no Base, Core, Warp, Palm, Edit, Tech, Press, News, Help, Info, Docs, or GUID
browser route/controller surface. External relying-party registrations remain available through
Visa. Their callbacks, local sessions, and browser interfaces belong to their own repositories; a
registered client does not imply a local Rails controller or host here.

Auth owns credential-ceremony continuity. It does not issue a general login session or act as the
OpenID Provider. Visa remains the only local OpenID Provider and owns the APP and ORG authority
flows. Each surface keeps its own host, credentials, routes, controllers, views, and state.

Models, migrations, and database connections associated with removed surfaces remain in this
repository pending the separate model/database inventory and follow-up decision. Their presence does
not establish an active route, controller, or writer.

## Historical decisions

The following accepted decisions explain earlier surface layouts. They remain provenance and do not
describe the current local route inventory:

- [`adr/acme-sign-core-base-port-boundary.md`](../../adr/acme-sign-core-base-port-boundary.md)
- [`adr/base-auth-ceremony-and-seven-rp-boundary.md`](../../adr/base-auth-ceremony-and-seven-rp-boundary.md)
- [`adr/visa-op-host.md`](../../adr/visa-op-host.md)
- [`adr/tech-and-palm-browser-rp-participation.md`](../../adr/tech-and-palm-browser-rp-participation.md)
- [`adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`](../../adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md)
