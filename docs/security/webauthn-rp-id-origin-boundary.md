# WebAuthn RP ID and Origin Boundary

Auth APP/ORG owns the WebAuthn ceremony routes and validates RP ID, origin, challenge, and
credential response against the current host and admitted Auth flow. A ceremony result is evidence;
it does not itself issue a Visa session or authorize an external RP session.

Visa owns the APP/ORG OpenID Provider transaction and consumes credential evidence only when it is
bound to that transaction. External relying parties own their WebAuthn interfaces, callback routes,
browser sessions, and local credential state in their own repositories.

Passkey credential management outside retained Auth routes is not served by Access. Persisted
identity and credential records remain pending the separate model/database usage report; they do not
establish a removed Base or RP route.

See [Passkeys](passkeys.md), [Credential Gateway](credential-gateway.md), and the accepted
[`visa-op-host` decision](../../adr/visa-op-host.md).
