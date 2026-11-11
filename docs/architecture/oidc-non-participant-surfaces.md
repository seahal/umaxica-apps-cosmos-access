# Local Route and OIDC Participation Boundary

## Current Access surfaces

Access serves only the Auth APP/ORG credential-ceremony surfaces, the Visa APP/ORG OpenID Provider
surfaces, and its operator tools: Mission, Flipper, Blazer, PgHero, Coverband, and Swagger. The
route inventory is defined by `config/routes.rb` and its retained route files.

Auth hosts credential ceremonies and provider callbacks. It does not issue general login sessions or
act as the OpenID Provider. Visa owns discovery, JWKS, OAuth/OIDC, logout, and DBSC endpoints for
APP and ORG. Each surface retains its own host, credentials, controllers, views, and state.

The operator tools have dedicated host constraints and their own configured access controls. They
are not Auth or Visa product surfaces and do not participate in OAuth/OIDC.

## External relying parties

Visa's external client registrations remain available to approved relying parties. A registered
client does not create an RP route, controller, session, or browser interface in Access. Each
external RP owns those parts in its own repository. Keep accepted client identifiers, exact return
URIs, issuer/JWKS bindings, and other registration properties unless their owner approves a change.

## Removed local surfaces

Access no longer serves Base, Core, Warp, Palm, Edit, Tech, Press, Info, Docs, News, Help, GUID,
Performance, or Xper product routes. Their former local route and controller contracts are not
current Access behavior. Models, migrations, and database connections are retained pending the
separate model/database usage report and owner decision; their presence does not establish a route,
controller, or active writer.

## History

Earlier participation and route decisions remain in their accepted ADRs, including
[`oidc-oauth-participation-allowlist-and-non-participant-surfaces`](../../adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md),
[`base-auth-ceremony-and-seven-rp-boundary`](../../adr/base-auth-ceremony-and-seven-rp-boundary.md),
and [`tech-and-palm-browser-rp-participation`](../../adr/tech-and-palm-browser-rp-participation.md).
They preserve decision history and do not describe the current Access route inventory.
