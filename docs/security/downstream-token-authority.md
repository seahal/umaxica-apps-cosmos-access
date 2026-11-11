# Downstream Token Authority

> **Supersession (2026-06-12):** Use `adr/acme-sign-core-base-port-boundary.md` and
> `docs/architecture/acme-sign-core-base-port.md` for the target component model. Acme is the only
> IdP / Authorization Server. Palm is the native bearer-token API Resource Server. Older references
> to `acme/www`, `core`, and `line` as downstream-token consumers are historical where they conflict
> with the Acme / Sign / Core / Base / Palm boundary.

> **Historical contract (2026-09-23):** The former Base/Auth transition described Visa as the sole
> local OIDC authority and Base as a local browser RP. The 2026-11-10 surface reset removed the
> local Base RP routes. Preserve this notice as history; it does not define current Access routes.

> **Historical participation update (2026-10-13):** Palm and Tech were recorded as local browser
> RPs. The 2026-11-10 surface reset removed their local routes; their external registrations and
> persisted history are not deleted by this document change.

> **Current OIDC boundary (2026-11-10):** Visa APP/ORG is the sole local OIDC authority and issues
> authority/downstream tokens under its own issuer and key namespace. Auth APP/ORG provides
> credential ceremonies. External relying parties own their local callbacks, browser sessions, and
> RP credentials; Visa's approved external client registrations remain available. See
> `adr/visa-op-host.md` and `docs/architecture/base-auth-seven-rp-boundary.md`.

## Authority

The historical `acme/www` downstream-token Authority is now represented by Visa's OIDC authority
boundary.

`core`, `line`, and future downstream services must trust authority-issued downstream tokens only.
They must not trust sign-issued session, access, refresh, or downstream tokens.

## Requirements

Downstream tokens must be:

- issued by Visa's configured authority;
- audience-bound to the downstream service;
- purpose-bound to the downstream action or API family where applicable;
- short-lived;
- verifiable by the downstream service through the Visa JWKS or the current authority verification
  channel.

## Non-Goals

- Do not use credential ceremony results as downstream tokens.
- Do not let `sign/id` mint tokens for `core`, `line`, or future downstream services.
- Do not infer downstream authority from physical token table placement.

## Related

- `docs/security/session-token-authority.md`

## Delivered reconciliation (2026-10-06)

Visa-issued authority credentials and each RP's local credentials are the only active browser/RP
token contracts in this cycle. Issuer, audience, subject and RP-session binding are checked before a
token is accepted; Auth ceremony results are not downstream access tokens. A parent security context
can authorize an explicitly bound RP operation but never authenticates a missing RP credential.
Legacy Sign/Acme wording above is migration history and is superseded by the Base/Warp registry.

## Browser RP participation update (2026-10-13)

Core, Warp, Edit, Palm and Tech use Base-issued browser RP credentials bound to their own client,
issuer, audience and host-local cookie. Tech also checks the current `tech.access` capability.
Palm's former `palm-api` bearer resource-server path is retired; this update does not create a
general-purpose downstream API token contract.
