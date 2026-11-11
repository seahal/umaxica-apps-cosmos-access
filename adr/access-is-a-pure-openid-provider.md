# Access Is a Pure OpenID Provider: Sign-in and Sign-out Only (2026-11-10)

## Status

Accepted (owner, 2026-11-10), architecture only. Implementation and migration are follow-up work.

Amends `adr/cosmos-identity-authentication-global-authorization-split.md` decision 12 ("Global
stores `sub` and no copy of credentials or profile data") and replaces the Avatar placement in
`docs/architecture/database-authority-placement.md` ("Avatar Boundary"). Other decisions of the
split record stand unless stated below.

Amended 2026-11-11 (owner, after consultation): Identity's source of truth is Governance. Accounts,
`sub`, sign-in identifiers (email addresses, telephone numbers), credentials (passkeys, TOTP,
recovery codes, social sign-in links) and profiles are owned and stored by Governance; Access keeps
none of them and reads what a ceremony needs through the credential lookup. Access keeps the Auth
subdomain and runs the ceremonies there (WebAuthn RP ID and social callback URIs unchanged).
Decisions 2 and 3 below are read with this amendment. Who generates an account and its `sub` during
sign-up, and how a sign-up interrupted between Access and Governance is completed or discarded,
remain open.

## Context

After the Cosmos split, Access (Identity) still carries code and databases beyond authentication:
profile and preference settings, avatars, settings dashboards, notifications and similar features
inherited from the single repository. Each such feature widens what an attacker reaches through the
component that holds credentials and signs tokens, and each one invites the next feature to be added
"because the data is already here".

Jump and Away (`umaxica-apps-edge-away`, `adr/0001-independent-away-responsibility.md`) show the
intended shape: a component with one responsibility, a fixed list of what it does, and no room to
grow into neighbouring work.

## Decision

1. **Access is the sign-in and sign-out component, nothing else.** It is the OpenID Provider and
   OAuth authorization server, and it runs the authentication ceremonies. Its responsibility ends
   when it has authenticated a person, issued or refused tokens, or ended a session.
2. **Access owns only what authentication needs:**
   - OpenID Connect and OAuth endpoints: authorization (with PAR), token, userinfo, JWKS,
     revocation, logout (including back-channel logout to relying parties);
   - ceremony screens: sign-in, sign-up, step-up, credential enrollment and removal reached by
     redirect from a relying party and returning to it, sign-out confirmation;
   - credentials: none stored (amended 2026-11-11); ceremonies verify against records looked up from
     Governance, the source of truth for Identity;
   - OP sessions, DBSC bindings, consent and tokens;
   - client registrations, as code (split record, decision 11);
   - a read-only copy of the signed snapshots Governance publishes;
   - its own audit records (`chronicle`).
3. **Access holds no other data and serves no other behavior.** Profiles, display names, avatar
   images, preferences, avatars and their assignments and memberships, organizations, roles,
   settings dashboards, credential lists, notifications, search and any business data live in
   Governance or in the relying party that uses them. Access does not write, edit or display them.
4. **Governance is where people and operators write such information.** Governance screens are an
   Access relying party (split record, decision 9). When a Governance screen needs an authentication
   ceremony (adding a passkey, changing a sign-in email), it redirects to Access and receives the
   result; it never handles the credential itself.
5. **Token claims beyond authentication come from Governance snapshots.** If a claim such as a
   display name must appear in an ID token, Governance publishes it in a signed snapshot and Access
   copies it into the token without interpreting or editing it. Otherwise relying parties read it
   from Governance by `sub`.
6. **The boundary is enforced by tests, not by convention.** Access keeps allow-lists of its route
   paths, its databases (`config/database.yml`) and its abstract `*Record` classes, guarded by
   static invariant tests (`project/static-invariant-guards.mdc`). A change to any list requires
   amending this record.

## Credential lookup (decided 2026-11-10, revised 2026-11-11)

7. **Governance down means no sign-in.** Access keeps no copy or cache of credentials; when
   Governance cannot answer in time, new sign-in, sign-up and step-up fail closed.
8. **Lookups are a server-to-server HTTPS API** (revised 2026-11-11; the earlier browser-carried
   JAR/JARM design is withdrawn). Access calls a Governance endpoint over public HTTPS, the same
   kind of call as PAR and the token endpoint. They share no database and no private network, only
   each other's JWKS. A lookup is:
   - a request signed by Access carrying the lookup key, the flow ID, a nonce, the audience
     (Governance) and a short expiry;
   - a response signed by Governance carrying `sub`, the Access-signed credential records, the
     current permission for the requested operation (account state), the credential versions and,
     for one-time codes, the delivery address;
   - finite timeouts (Faraday through the shared outbound connection); no answer in time means no
     permission. Access verifies Governance's signature, the nonce and flow binding, then its own
     signature on each credential record. Governance refuses lookups without a valid Access
     signature, answers from its primary database, and refuses a credential whose version is lower
     than one it has recorded. Access answers the person the same whether or not an account exists.
9. **Lookup keys.** Passkeys by credential ID; email and telephone one-time codes by a blind index
   that Access computes with a key only Access holds (the address itself is not sent); social
   sign-in by an index of the external `iss` and `sub`. Governance stores addresses encrypted with
   its own key for display and notices.
10. **Passkey records do not change after registration.** Access neither checks nor stores
    `signCount` (WebAuthn leaves counter handling to the relying party; synced passkeys mostly
    report 0) or the Backup State flag (BS), which can change over time. The Backup Eligible flag
    (BE) is fixed at creation and is stored at registration, for a possible later AAL3 policy
    requiring device-bound keys (BE = 0). Sign-in therefore only reads from Governance. Current code
    differs (observed 2026-11-11) and is aligned when credential data moves to Governance, not
    before: `sign_count` is stored and checked at sign-in
    (`app/controllers/concerns/passkey_sign_in_flow.rb`); `backup_state` is stored at registration
    and never updated; `backup_eligible` and `backup_state` are nullable booleans (an existing
    violation of the NOT NULL rule). BE is self-reported (attestation `none`), so it serves display
    and guidance only; an AAL3 policy would need attestation. Only FIDO2 passkeys are accepted:
    registration requires a discoverable credential and user verification, so U2F-only
    authenticators are not supported (owner, 2026-11-11; not deployed, no backward compatibility
    needed). WebAuthn is the only browser API used. Deleted credentials are marked revoked (an
    explicit NOT NULL state), not removed, so a re-inserted old record is detected; decisions read
    from the primary (`docs/backlog/2026-11-11-no-automatic-replica-reads.md`).

## Why the Auth ceremonies stay in Access (decided 2026-11-11)

With Identity's source of truth in Governance, two placements were compared:

|                                   | A. Auth in Access (chosen)                                                                                                                                           | B. Auth in Governance (Ory Hydra + Kratos shape)                    |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Where a passkey is verified       | Access, with records looked up from Governance                                                                                                                       | Governance, against its own database                                |
| Access <-> Governance             | lookup, registration write, permission, revocation                                                                                                                   | an authentication result per login challenge                        |
| Size of Access                    | larger (ceremonies)                                                                                                                                                  | smallest (protocol and tokens)                                      |
| Effect of a Governance compromise | no impersonation: Access rejects credential records without its own signature; an attacker can deny, delete or roll back, which revocation state and versions detect | impersonation of anyone: Access trusts Governance's "this is sub X" |

The URL is not the deciding factor: `auth.umaxica.*` could be served by either deployment, and
nothing is deployed yet. The deciding factor is that impersonation must require compromising both
Access (its signing key) and Governance. This is the consultation's purpose (limit how far a
compromise of one side spreads) and its rule that Access never skips its own WebAuthn verification
even with Governance's permission. B's simplicity is rejected because Governance is a large
application with administration screens.

14. **Auth stays in Access.** Access runs every ceremony (WebAuthn, social sign-in callbacks,
    step-up, one-time codes) and verifies it itself. Governance stores the records and grants
    permission; it never verifies a credential on Access's behalf.
15. **Credential records are signed by Access with a dedicated key.** Passkey records (credential
    ID, `sub`, public key, BE, version, realm) and social sign-in links (external `iss` and `sub`,
    `sub`) are signed at registration with an Access key used only for credential records, separate
    from token signing keys. On rotation the old public keys stay available for verification only,
    or all records are re-signed; the choice is part of key-rotation design.
16. **One exchange shape for all Access <-> Governance calls.** Lookup and registration (Access to
    Governance) and revocation commands (Governance to Access) share one component: a signed request
    with an ID, a signed response, finite timeouts, idempotent handling of a repeated ID, and no
    success until the signed acknowledgement is verified. A registration exists only after
    Governance's acknowledgement; an interrupted registration is retried with the same ID or
    discarded.

Feasibility and order (2026-11-11). Existing parts are reused: `OutboundHttp::Connection` (Faraday),
the `jwt` gem and JWKS publication, consumed-`jti` tables, the current WebAuthn verification and the
per-tab flow handle (`adr/browser-flow-handle-per-tab.md`). Hard parts: sign-up interrupted between
Access and Governance (Governance creates the account and `sub`; when unfinished sign-ups are purged
is open), long-lived signatures across key rotation (decision 15), and tests spanning two
repositories (both run in development through their tunnels; the OIDC side is checked with
`umaxica-apps-mock-oidc` and the OpenID conformance suite). Build one thin slice first and widen:

1. App-realm passkey sign-in through the lookup API, against records already in Governance.
2. Passkey registration (sign, store, verify the acknowledgement).
3. Revocation commands from Governance.
4. Social sign-in, email and telephone one-time codes, the org realm, sign-up.
5. Clean-up: drop `sign_count` and `backup_state`, move Valkey state to PostgreSQL.

## Revocation commands from Governance (decided 2026-11-11)

11. **Governance commands, Access executes.** Refresh tokens and OP sessions live in Access, so only
    Access can revoke them. Governance decides (PDP) and sends a revocation command; Access does not
    ask Governance on each refresh. Sources of a command: the person themselves (Governance app
    screens, own sessions only), an operator (Governance org admin screens, a client's app
    sessions), and a senior operator (another operator's org sessions). Operator commands require
    step-up at Access before they are issued.
12. **Transport: HTTPS API, not a shared database.** Governance calls an Access endpoint over public
    HTTPS with a request signed by Governance and verified against Governance's JWKS, with finite
    timeouts (Faraday). Access never exposes its database to Governance (split record, decision 12
    stands). A message queue may replace the HTTPS call later if the deployment cannot carry it; the
    command and acknowledgement contents stay the same.
13. **Success only on a signed acknowledgement.** A command carries an ID, realm, target `sub`,
    scope (all sessions or one), actor and reason. Access executes it once per ID (a resend is a
    no-op), records it in its audit records, and returns an acknowledgement signed by Access naming
    the command ID. Governance shows success only after verifying that acknowledgement; on timeout,
    error or an invalid acknowledgement it shows "not completed" and offers a resend with the same
    ID. Success means Access's refresh tokens and OP sessions for the target are revoked;
    back-channel logout to relying parties follows asynchronously, and already issued access tokens
    expire within their lifetime (5 minutes).

This replaces, for refresh, the consultation's row "refresh denied while Governance is unavailable":
refresh is not gated by a Governance query; revocation reaches Access as a command whose completion
is visible and retryable. New sign-in, sign-up and step-up still require Governance's permission and
fail closed without it.

## Consequences

- Access loses its settings, profile and avatar code and databases. Features still needed move to
  Governance (or a relying party) before or with the removal; features nobody needs are deleted.
- Account deletion and other lifecycle changes flow both ways as events: Access to Governance for
  credentials and sessions, Governance to Access for snapshot data it no longer publishes.
- Access becomes smaller to review and to harden; the component that signs tokens has no features
  unrelated to signing them.
- Relying parties that need profile data make a Governance read or rely on snapshot-derived claims.

## Rejected Alternatives

- **Keeping profile and avatar data in Access for convenience.** It keeps unrelated writers next to
  credentials and token signing, and it is the path by which Access grew beyond authentication.
- **Governance storing copies of credentials or sign-in identifiers.** It would add a second place
  where credentials leak; ceremonies stay in Access only.
- **A written rule without tests.** Allow-lists without enforcement drift as the split record's
  unenforced boundaries did.

## Open Questions

- Whether Access remains the policy decision point for common authorization (split record,
  decision 2) by evaluating Governance snapshots, or only enforces authentication strength and
  leaves all authorization to relying parties.
- Which existing databases move to Governance (`avatar`, `*_setting`, parts of the principal and
  `zenith` stores) and which are deleted; recorded in the database ownership inventory.
- The snapshot fields Access accepts for token claims, and their maximum age.
- Service authentication and message shape between Access and Governance (signed request JWT, HTTP
  Message Signatures, mTLS, an interim Cloudflare Access service token, Standard Webhooks, or the
  OpenID AuthZEN and Shared Signals Framework standards). Options considered without a decision:
  `research/2026-11-12-access-governance-service-communication-options.md`.

## References

- W3C Web Authentication (signature counter, BE and BS flags): https://www.w3.org/TR/webauthn-3/
- RFC 7519, JSON Web Token (claim names): https://www.rfc-editor.org/rfc/rfc7519.html
