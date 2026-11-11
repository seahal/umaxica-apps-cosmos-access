# Session And Token Authority

## Current Access ownership

Visa APP and ORG are the only local OpenID Provider and Authorization Server surfaces. Visa owns
their OP device/session state, root and grant authority, and OIDC token issuance, refresh,
revocation, and logout.

Auth APP and ORG own credential-ceremony continuity. Auth does not issue a general login session, OP
refresh token, downstream token, or session-bound step-up freshness. Credential evidence becomes
authority only when the owning session authority validates and commits it.

Access does not provide local Browser RP routes for Base, Core, Warp, Palm, Edit, Tech, or other
external relying parties. Visa's external RP client registrations remain available. Each RP owner
controls its callback, host-local session and cookies, access/refresh credential storage, and local
logout completion. A Visa OP cookie never authorizes mutation of an external RP session, and an RP
credential never substitutes for the Visa OP session.

Models, migrations, and database connections associated with removed RP surfaces remain pending the
separate model/database report. Persisted history does not establish that an RP route, controller,
session writer, or token issuer remains active in Access.

## Step-up evidence

Auth may perform an admitted credential ceremony, but successful ceremony output is evidence only.
The authority that owns the affected session and protected operation must validate the evidence,
recheck current policy, and commit any freshness state. Access does not create an external RP
session or make an external RP's step-up decision.

## Historical decisions

Older Acme/Core/Sign and Base/RP authority descriptions are preserved in accepted decisions and
dated records. They do not change the current local ownership above. See the
[Visa OP host decision](../../adr/visa-op-host.md), the
[external RP registration boundary](../architecture/base-auth-seven-rp-boundary.md), and the
[logout contract](logout-session-management.md).
