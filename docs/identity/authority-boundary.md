# Identity Authority Boundary

## Current Access contract

Access serves four application surfaces: Auth APP/ORG and Visa APP/ORG. It also mounts Mission,
Flipper, Blazer, PgHero, Coverband, and Swagger as operator tools.

| Surface        | Current authority                                                                                                          |
| -------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Auth APP/ORG   | Credential ceremonies and provider callbacks. Auth does not issue general login sessions or own OpenID Provider authority. |
| Visa APP/ORG   | OpenID Provider and Authorization Server, including local session, token, OIDC, logout, and DBSC behavior.                 |
| Operator tools | Tool-specific monitoring and operations; no product identity authority.                                                    |

Visa remains the only local OpenID Provider. Its external relying-party registrations remain
available to their approved clients. A registration does not create an RP route or session in
Access: each external RP owns its callback, browser interface, and local session in its own
repository.

Auth and Visa retain separate hosts, controllers, credentials, sessions, and persisted state. A
credential ceremony result is consumed only by the Visa flow that owns the corresponding
transaction. No surface inherits another surface's authentication or authorization.

## Persisted data

Identity, session, token, preference, and audit models and their database history remain in place
pending the separate model/database usage report. A retained model or database connection does not
establish a current route, controller, or write owner. Do not infer current ownership from the
former Base, Core, Warp, Palm, Edit, Tech, or COM route names.

## Historical decisions

Earlier migration and multi-RP decisions remain available as history in
[`adr/identity-authority-boundary.md`](../../adr/identity-authority-boundary.md),
[`adr/base-auth-ceremony-and-seven-rp-boundary.md`](../../adr/base-auth-ceremony-and-seven-rp-boundary.md),
and [`adr/visa-op-host.md`](../../adr/visa-op-host.md). Their former local route layouts do not
describe current Access behavior. The accepted cross-repository OIDC connection contract is in
[`specs/cosmos-cross-repository-connection/spec.md`](../../specs/cosmos-cross-repository-connection/spec.md).
