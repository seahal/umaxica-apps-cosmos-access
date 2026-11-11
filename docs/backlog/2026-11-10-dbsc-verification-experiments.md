# DBSC Verification Experiments (2026-11-10)

Owner: Access. Status: queued; run when the DBSC completion work starts
(`adr/dbsc-scope-authentication-refresh-tokens.md`, amended 2026-11-10). A Windows machine with a
TPM is prepared.

## Accepted risks (owner, 2026-11-10)

A DBSC-bound session stops working when the device key is lost: browser data cleared, profile or
device reset, TPM cleared, or a move to another device. The user then signs in again and a new key
is registered. This is intended; a session must not survive without its key.

## Experiment 1: stolen cookies without the key (owner, manual)

Development environment and test accounts only.

1. In Chrome with DBSC and a TPM, sign in and confirm registration succeeded (developer tools show
   the registration request succeeding).
2. Copy the site's access-token and refresh-token cookies into another browser, profile or client.
3. Let the short-lived bound cookie expire (or remove it) and call the refresh endpoint from the
   other client with only the refresh-token cookie.
4. Expected: refresh refused for lack of a DBSC proof; the session is revoked, so the original
   Chrome must also sign in again; no new access token is issued (check logs and records).
5. Delete the copied cookies afterwards.

## Experiment 1b: OP refresh during single sign-on to a new RP (owner, manual)

The OP session is the entry to every RP, so its DBSC binding matters most here.

1. Sign in once through Visa so the OP session is DBSC-bound (Visa's key).
2. Let Visa's short-lived bound cookie expire (or remove it), keeping the OP session alive on the
   server.
3. Open an RP that has no session yet (for example `edit.umaxica.org`), so the browser navigates to
   Visa's `/oauth/authorize` (a top-level navigation through Jump).
4. Expected: the browser pauses that navigation and calls Visa's refresh endpoint with a proof
   signed by Visa's key; Visa verifies it with its own stored key; the authorization continues
   without a new sign-in and the RP then registers its own, separate DBSC key.
5. Repeat with copied Visa cookies in another browser (no key): Visa refuses the refresh, revokes
   the OP session, and the authorization falls back to sign-in; no code is issued to the RP.
6. Confirm the OP never receives or stores any RP's DBSC public key: each site verifies only its own
   key.

## Experiment 2: key stolen with the profile (owner, manual, optional)

Chrome's manual-testing software-key flag keeps the DBSC key in the profile instead of the TPM.
Copying that profile to another Windows machine simulates theft of the key itself. Expected: refresh
succeeds, which confirms DBSC relies on the device protecting the key. Use a throwaway profile and
remove the flag afterwards; never use it in an everyday profile.

## Experiment 3: refresh endpoint refuses forged proofs (Codex, automated tests)

Work order for Codex in this repository:

```
Add Rails tests for the DBSC refresh path of the Visa OP sessions (app and org), using locally
generated test keys only. For a session already bound to a stored public key:
- a proof signed with a different key is refused;
- a reused or stale challenge is refused;
- a proof for another session ID is refused;
- a refresh request that carries a new public key (`jwk` header) is refused, and the stored key is
  unchanged (no key substitution);
- a refresh without any proof is refused and the session is revoked;
- a valid proof with the stored key succeeds, and the DBSC check runs before the refresh token is
  used (a refused proof never rotates or consumes the refresh token).
Read app/services/dbsc_verification_service.rb, app/lib/dbsc_proof_verifier.rb and the refresh
controllers first; reuse existing test helpers. Do not weaken verification to make a test pass. Do
not print keys or tokens. Record results in evidence/. No commit.
```

When RPs adopt DBSC, repeat Experiment 3 in each RP repository.
