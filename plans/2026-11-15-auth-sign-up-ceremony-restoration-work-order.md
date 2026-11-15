Task (umaxica-apps-cosmos-access only): reopen App sign-up in Auth on top of Governance's pending
registration, using the browser handoffs H1 to H6. No commit. Never print secrets, key material,
tokens or environment values. Never edit config/credentials/*.yml.enc. Do not read .env contents. No
push, no deploy, no Cloudflare change, no change outside this repository. Ask before dropping
databases or volumes.

## Prerequisites (check first; stop and report if any is missing)

1. `plans/2026-11-14-front-channel-id-token-sign-in-work-order.md` is complete (its evidence says
   so).
2. `plans/2026-11-15-auth-sign-in-ceremony-restoration-work-order.md` is complete: sign-in works end
   to end, and sign-up registration ends by entering canonical Sign In.
3. `docs/pending-registration-handoffs-contract.md` exists (the contract, copied from Governance).
4. `docs/pending-registration-routes-contract.md` exists (Governance's receiver paths, copied by the
   owner after Governance implements its side). Without it, do items 1 to 4 below and stop before
   wiring redirects to Governance.

## Decision (owner; do not reopen)

- The contract in `docs/pending-registration-handoffs-contract.md` is binding: typs, claims, 120 s
  TTL, single-use `jti`, fresh `jti` per re-send, `cer` = SHA-256 of Access's ceremony reference,
  measure the URL (refuse above 2,048 characters, keep the ceremony at the credential step), no OP
  session or token from H2, H4 is permission to start Sign In, not Sign In.
- Governance owns the pending registration. Access keeps no registration state beyond its ceremony
  (no Access-local account rows). `sub` and `act` are `Client.public_id`.
- No server-side call between applications except JWKS reads (Base App JWKS for H2, H4, H6).
- Terminology: restore under ingress, availability (`sign_up_available_app`), eligibility,
  requirements; this finishes `plans/backlog/2026-11-14-sign-flow-terminology-rename-work-order.md`
  for sign-up. No aliases for old paths (`/sign/up/sentry`, `guard`, `checkpoint`).
- Scope: App realm only. Org sign-up stays 503. Telephone passcode is Governance's step after
  completion (owner O-4); Auth does not collect it.

## Facts

- Removed sign-up code is at `f84c87b060876a25994e30e9274420d9067f1367` (before `727cdb560`):
  `sign/ups`, `sign/up/sentries`, `sign/up/emails`, `sign/up/telephones`, `sign/up/guard/*` (email,
  google, apple), social registration, and the models `ClientSignUpFlow`, `SignUpArtifactCleanup`,
  `SignUpExpiryJob`. Much of their cleanup and expiry logic is replaced by Governance's lifecycle;
  restore only what the ceremony needs.
- Base App origin `https://www.umaxica.app`; JWKS `<origin>/.well-known/jwks.json`, PS256.

## Work

1. Inventory the removed sign-up code; classify: needed by the Auth ceremony / replaced by
   Governance (do not restore) / other. Mark anything that wrote registration state or called
   Governance server-side.
2. Ingress `/sign/up/ingress` (availability, Visa handoff) and the identifier proof per method
   (email, telephone, Google, Apple) and birthdate and social confirmation as requirements.
3. H1 issuer, H2 receiver, H3 issuer (exactly one credential: passkey where the requirement asks),
   H4 receiver that enters canonical Sign In, H5 issuer (Cancel), H6 receiver; each with the
   contract's checks.
4. Remove `GovernanceLookupUnavailableError` raises on the sign-up path in favour of the handoffs;
   report any that remain.
5. Wire redirects to Governance through Jump using the paths in the routes contract.

Stop and report (continue the rest) when an item needs a contract that differs from the copied
files, a new environment variable or credential, or an irreversible migration.

## Tests (Red first)

Through public endpoints without mocking the ceremony; Governance's answers signed with test Base
keys: each method to H1; H2 started/completed/refusal reasons; passkey to H3; H4 completed enters
Sign In and ends in the front-channel ID Token to Base; cancel H5/H6 (cancelled, too late,
not_active); replayed or foreign `jti`, wrong `typ`, wrong `cer`; oversized H3 refused with the
ceremony kept; availability off 503; old paths 404; Org sign-up 503. Static guard as in the sign-in
order.

## Checks and report

As in the sign-in ceremony order. Evidence:
`evidence/YYYY-MM-DD-auth-sign-up-ceremony-restoration-XXXX.md` (full `git rev-parse HEAD`):
inventory and classification, restored and replaced pieces, measured H1/H3/H5 sizes, test results,
stopped items, owner items, confirmation that config/credentials files are unchanged.
