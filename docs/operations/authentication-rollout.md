# Auth/Visa Authentication Rollout Contract

This document covers the local Access authentication boundary: Auth APP/ORG credential ceremonies
and Visa APP/ORG OpenID Provider behavior. It does not authorize deployment or route changes in an
external relying-party repository.

## Local ownership

Visa is the only local OpenID Provider and owns its APP/ORG discovery, JWKS, OAuth/OIDC, logout, and
DBSC routes. Auth owns credential ceremonies and provider callbacks; it does not issue general login
sessions or provide RP callback routes. The public route and trust boundary is described in the
[Auth/Visa ownership contract](../architecture/base-auth-seven-rp-boundary.md).

## External relying parties

Visa's approved external client registrations remain available. Keep each registered client ID,
issuer, JWKS binding, exact redirect URI, and logout URI aligned with the owning RP's accepted
configuration. A registration does not authorize Access to host that RP's callback, session, or
browser UI. Changes to an external RP's keys or routes are owned and verified in that repository.

The cross-repository connection and its acceptance criteria are recorded in the accepted
[Cosmos connection spec](../../specs/cosmos-cross-repository-connection/spec.md). Follow that spec
for coordinated OP/RP integration work; this page does not replace its protocol checks.

## Rollout controls

- Verify the target Auth or Visa APP/ORG host and its route contract before changing provider or
  edge configuration.
- Preserve exact issuer, audience, redirect, cookie, CSRF, and key boundaries. Do not use one
  surface's credentials or session on another surface.
- Keep production keys and shared database changes within their separately approved operating
  procedures. A local route cleanup does not rotate credentials, change external registrations, or
  authorize a database migration.
- Record only verification outcomes and public identifiers in operational evidence; never record
  credentials, tokens, cookies, or private key material.
