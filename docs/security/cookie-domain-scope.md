# Cookie Domain Scope

## Current Behavior

Authentication and RP credential cookies are host-local transport slots. The cookie name describes
the transport role, not the logical credential kind.

| Role                | Secure context name   | Insecure dev/test name |
| ------------------- | --------------------- | ---------------------- |
| Auth access         | `__Host-auth_access`  | `auth_access`          |
| Auth refresh        | `__Host-auth_refresh` | `auth_refresh`         |
| Auth DBSC / binding | `__Host-auth_dbsc`    | `auth_dbsc`            |
| RP access           | `__Host-rp-access`    | `rp-access`            |
| RP refresh          | `__Host-rp-refresh`   | `rp-refresh`           |

The RP access and refresh cookie rows describe external RP-owned transport only. Access does not
set, clear, or validate those cookies.

These credential cookies are host-only and use `Path=/`; secure contexts use `Secure` and the
`__Host-` prefix. They never carry a `Domain` attribute.

Preference transport has a separate contract:

| Role                         | Cookie                      | Scope and use                                                            |
| ---------------------------- | --------------------------- | ------------------------------------------------------------------------ |
| Anonymous Preference JWT     | `__Secure-preference`       | Realm-domain scoped, `HttpOnly`, signed snapshot used for runtime reads  |
| Language display mirror      | `language`                  | Realm-domain scoped and JavaScript-readable                              |
| Experience display mirror    | `__Secure-experience`       | Realm-domain scoped and JavaScript-readable                              |
| Consent and Web Push binding | `__Host-preference_binding` | Host-only, `HttpOnly`; proves browser ownership for bounded reads/writes |

The shared Preference cookies are issued from the same database snapshot for retained APP and ORG
realms. Their tokens remain realm-separated even where sibling host rules permit the same cookie
scope. Retained COM records do not create a current COM host or route. A signed Preference JWT does
not authorize consent reads by itself; the host-only binding remains required. Preference refresh,
Preference DBSC/assurance, actor consent mirrors and per-item Preference cookies are retired.

Cookie names must not encode a cross-surface shared authority. Auth ceremony continuity and Visa
session/token cookies are host-local; a cookie from one Auth/Visa host is not accepted as another
host's credential.

## JavaScript-readable Preference Mirrors

Rails writes only the non-secret `language` and `__Secure-experience` display mirrors. They are
apex-scoped (for example, `.umaxica.app`) for browser UI, Hono compatibility and edge rendering.
Rails request code does not use them as authoritative Preference input. The signed JWT is the
runtime display projection.

These mirrors must not carry session IDs, access tokens, refresh tokens, Preference JWTs, DBSC
values, authorization grants, ceremony secrets, one-time tokens, raw credentials, or
credential/session authority data. Request context such as `ri` remains in the URL and is not
mirrored to a cookie.

Browser-visible hosts and internal Rails/pod origins should use the `PUBLIC_` and `PRIVATE_`
boundary vocabulary in docs and config. That keeps cookie transport discussions separate from
host-ownership discussions.

## Authority and Transport Boundaries

Credential kind is enforced by issuer, audience, validator contract, client classification, and
transport binding:

- Visa is the only local Authorization Server and token authority.
- Auth owns credential-ceremony continuity, not a general login session or RP session.
- External relying parties store their Visa-issued tokens and local browser sessions in their own
  host-local cookies. They validate the registered client, issuer, audience, and resource type in
  their own repositories.
- Access does not issue or consume external RP browser cookies. Visa and each external RP keep
  separate host-local credential and session boundaries.

Because `__Host-` requires `Path=/`, authentication and RP refresh cookies are not path-restricted.
Refresh endpoint exclusivity is a server-side transport and endpoint contract. Preference cookies
have their own documented domain scopes and do not use Preference refresh or DBSC endpoints.

## Related

- `adr/cookie-domain-scope-by-surface.md` — historical cookie naming decision; its Preference
  refresh/DBSC rows are superseded by the current Preference architecture.
- `docs/security/refresh-token-rotation.md`
- `docs/reference/subdomains.md`
