# Pending Registration Handoffs (contract copied from Governance)

Source: Governance `adr/sign-up-finalization-in-auth.md`, section "Cosmos split amendment:
Governance-owned pending registration", accepted by the owner on 2026-11-15 with owner items O-1 to
O-6 decided as recommended (lifetime 30 minutes; a newer start with fresh proof supersedes; purge
after 7 days; telephone passcode moves after completion in Governance; completion writes `ACTIVE`;
an oversized credential handoff is refused with an explicit error). Copied verbatim on 2026-11-15;
Governance owns the text. Do not edit here; ask for a new copy when it changes.

Scope: App realm (Client) sign-up. Org realm sign-up is not part of this contract.

### Handoffs

All handoffs are compact PS256 JWS with an explicit `typ` header per kind, so a token of one kind is
never accepted as another. All have `exp - iat` of 120 seconds. All carry `jti`, which the receiver
consumes once. All carry `cer`, the SHA-256 of Access's ceremony reference (Access keeps the
reference itself in its own session). Governance-issued tokens are signed with the Base App key and
verified with Base JWKS. Access-issued tokens are signed with the Auth App key and verified with
Auth JWKS. Governance receivers are top-level GET navigations from Jump. They verify, commit, and
answer with a 303 to the next Jump URL, carrying `Cache-Control: no-store` and
`Referrer-Policy: no-referrer`, as the accepted front-channel ID Token callback does. Exact route
paths are left to the implementation order and `generic/routing.mdc`.

| ID  | Direction and `typ`                        | Purpose                                                                                                                                                                                                                    |
| --- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| H1  | Auth → Base, `registration-start+jwt`      | After Access has verified the identifier (email or telephone proof, or a verified Google/Apple identity) and collected the birthdate and, for social sign-up, the confirmation. Asks Governance to start the registration. |
| H2  | Base → Auth, `registration-answer+jwt`     | Answer to H1: `started` (reference, user handle, outstanding requirement, deadline), `completed`, or a refusal reason.                                                                                                     |
| H3  | Auth → Base, `registration-credential+jwt` | Delivers the one Auth credential that the outstanding requirement asks for.                                                                                                                                                |
| H4  | Base → Auth, `registration-answer+jwt`     | Answer to H3: `completed` (subject), or a refusal reason.                                                                                                                                                                  |
| H5  | Auth → Base, `registration-cancel+jwt`     | The person pressed Cancel in Auth while the registration was pending.                                                                                                                                                      |
| H6  | Base → Auth, `registration-answer+jwt`     | Answer to H5: `cancelled`, `completed` (cancel came too late), or `not_active`.                                                                                                                                            |

When a handoff cannot be verified at all (signature, `iss`, `aud`, `typ`, `exp` or malformed), or
when sign-up is unavailable, Governance answers with a fixed plain refusal page (400 or 503) and no
signed answer. Access then fails closed, as the fixed context requires.

Answer reasons are a closed set: `started`, `completed`, `cancelled`, `sign_in_instead`,
`ineligible`, `credential_rejected`, `conflict`, `not_active`, `unavailable`. A reason is never
derived from free text.

### Requirements for Access

Each item is a requirement on Access. It describes only what crosses the boundary, not Access
internals. Size estimates assume a protected header of about 115 characters and a 512-character
signature (overhead about 630 characters). They also assume a destination prefix of about 50
characters, which leaves about 1,370 Base64url characters (about 1,000 bytes of JSON) for claims.

| Step | Access sends or receives                                                                                                   | Claims                                                                                                                                                              | TTL   | Size estimate                                                                                                                                              |
| ---- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| H1   | Sends, after its own identifier proof, birthdate and (social) confirmation                                                 | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, `mth`, identifier (email ≤ 254, E.164 ≤ 16, or provider `iss` + `sub` ≤ 255), proof time, `bdt`, social confirmation flag | 120 s | ≤ 1,350 characters with a 254-character email                                                                                                              |
| H2   | Receives; consumes `jti` once; requires its own `cer`                                                                      | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, reason, `reg` (21), user handle (43), outstanding requirement, `dl`                                                       | 120 s | about 1,100 characters                                                                                                                                     |
| H3   | Sends exactly one credential for `reg` from H2 of the same ceremony                                                        | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, `reg`, `mth`, credential ID, COSE public key, `alg`, sign count, UV/BE/BS flags, transports, AAGUID                       | 120 s | ES256 with a 64-byte ID: about 1,370 characters. RS256 with a 64-byte ID: about 1,710. IDs above about 250 bytes with RS256 exceed 2,048 (owner item O-6). |
| H4   | Receives; enters canonical Sign In only when `cer` and `reg` match its live ceremony and the credential it just registered | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, reason, `reg`, `sub`, `act` (both the Client public ID), completion receipt ID, `mth`                                     | 120 s | about 1,100 characters                                                                                                                                     |
| H5   | Sends when the person cancels during `CREDENTIAL_PENDING`                                                                  | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, `reg`                                                                                                                     | 120 s | about 900 characters                                                                                                                                       |
| H6   | Receives                                                                                                                   | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, reason, `reg`                                                                                                             | 120 s | about 900 characters                                                                                                                                       |

Access must also:

- Publish its JWKS per realm, and follow the key rotation rule above.
- Use a fresh `jti` for every re-send. Never re-send a consumed token.
- Measure the full destination URL before redirecting. Above 2,048 characters, refuse with an
  explicit error and keep the ceremony at the credential step; never truncate a claim.
- Never create an OP session, token or ID Token from H2.
- Treat H4 as permission to start Sign In, not as Sign In.
- Keep Auth's sign-up entry at 503 until Governance's receivers are deployed and enabled.
