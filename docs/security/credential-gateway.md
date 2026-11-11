# Credential Gateway

Access currently serves Auth APP/ORG credential ceremonies and Visa APP/ORG session and OIDC
authority. Auth owns the credential entry, provider callback, and verification work exposed by its
retained routes. Visa consumes the admitted result and owns local session issuance, authorization,
token, and step-up freshness decisions.

## Auth responsibilities

Auth may own:

- passkey/WebAuthn, OTP, TOTP, and other retained credential ceremonies;
- social-provider callback verification and callback-bound ceremony state;
- credential enrollment and credential evidence for the current Auth APP/ORG actor;
- short-lived Auth ceremony continuity and its audit records.

Auth does not issue general login sessions, refresh tokens, Visa access tokens, authorization codes,
or downstream tokens. It does not decide Visa session limits or OIDC authorization.

## Visa responsibilities

Visa APP/ORG owns the OpenID Provider and Authorization Server contracts, including Root Sessions,
authorization transactions and codes, authority-token issuance, session limits, logout, and DBSC.
Visa applies only the credential evidence bound to its admitted transaction.

## External relying parties

Visa's approved external RP registrations remain available. The registered RP owns its callback, RP
session, token storage, product account pages, and post-login navigation in its own repository. An
OIDC registration does not create a local Access route or controller.

## Retained recovery boundary

Any Auth APP recovery endpoint remains a credential-recovery ceremony only. A restricted recovery
ceremony does not issue a Visa Root Session, RP session, or general authentication token. It does
not become a forgotten-password flow; those operations require a separate accepted credential and
session-revocation contract.

## History

Earlier Sign/Acme/Base responsibility descriptions remain in accepted ADRs, including
[`identity-authority-boundary`](../../adr/identity-authority-boundary.md) and
[`visa-op-host`](../../adr/visa-op-host.md). They do not establish current local routes. The
accepted cross-repository OIDC contract is in
[`cosmos-cross-repository-connection`](../../specs/cosmos-cross-repository-connection/spec.md).
