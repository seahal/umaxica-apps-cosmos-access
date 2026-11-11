# Move Authentication State Off Valkey and Lua to PostgreSQL (2026-11-11)

Owner: Access. Status: decided (owner), deferred; do it later. Governance has its own backlog with
the same date and name.

## Decision (owner, 2026-11-11)

Authentication state whose correctness depends on one-time use or limits moves from Valkey (with Lua
scripts) to PostgreSQL, following `docs/backlog/2026-11-10-access-postgres-first-state-storage.md`.
Atomicity is not traded for performance. The owner regrets the Valkey choice: Lua scripts inside
Valkey hold security decisions (issued -> consumed, replay detection, failure budgets) where a
failover to a lagging replica could accept a used value again, and the logic is hard to review.

## Valkey configuration (observed 2026-11-11)

`config/valkey.yml`: `cache` (Rails.cache; development `valkey-cache` db 1, production
`CACHE_REDIS_URL`), `rate_limit` (`valkey-kvs` db 3, `RATE_LIMIT_REDIS_URL`), `auth_state`
(`valkey-kvs` db 5, `AUTH_STATE_REDIS_URL`), `coverband` (diagnostic Valkey db 13). Namespaces:
`lib/umaxica/valkey/namespaces.rb`.

## A. Security decisions held in Valkey: move to PostgreSQL or delete

| Decision                                    | Code                                                                                                             | Mechanism                                    | Action                                                                                |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------- |
| Authorization code single use               | `app/services/valkey/auth_state/authorization_code_store.rb`                                                     | Lua `issued` -> `consumed`, replay tombstone | move to PostgreSQL                                                                    |
| Base <-> Auth opaque admission codes (60 s) | `app/services/valkey/auth_state/opaque_admission_store.rb`                                                       | Lua CAS                                      | check whether the flow survives the OP-only cleanup; move if it does, delete if not   |
| OTP verification failure budgets            | `app/models/email_otp_verification_failure_budget.rb`, `app/models/telephone_otp_verification_failure_budget.rb` | Lua `INCR`                                   | move to PostgreSQL (a lost counter resets the limit)                                  |
| Sign-out notices                            | `app/services/valkey/auth_state/sign_out_notice_store.rb`                                                        | Valkey                                       | display only; delete if no longer needed (`generic/no-flash-messages.mdc`), else move |

## B. Rate limits: keep in Valkey, with conditions

Rails `rate_limit` (`app/controllers/concerns/rate_limit.rb`) and the authorization endpoint counter
(`app/controllers/concerns/oauth_authorize_rate_limit.rb`, `increment`) count in the `rate_limit`
Valkey. When Valkey is unavailable they answer 503 (`errors.rate_limit.backend_unavailable`): fail
closed. A lost or reordered counter restarts the count, so Valkey stays only for short per-request
bursts (seconds to minutes). Verify that every account-level limit, lockout and cooldown lives in
PostgreSQL; move any that does not.

## C. Caches: keep

Apple and Entra JWKS caches
(`app/adapters/external_authentication/apple_notification_jwks_cache.rb`,
`app/lib/external_sign_in/entra_jwks_cache.rb`, `Rails.cache`): loss means a refetch; a missing key
fails. Safe.

## D. Diagnostics: keep

Coverband on the diagnostic Valkey.

## E. Already in PostgreSQL (the model to follow)

- Client assertion `jti`: `OpAppConsumedJti`, `OpOrgConsumedJti`, `SecurityConsumedJti` (purged by
  `SecurityConsumedJtiPurgeJob`).
- DPoP proof `jti`: `DpopJtiReplayGuard` -> `DpopProofStateStore` -> `ClientDpopProofState` /
  `OperatorDpopProofState`.

## Keep when moving

- Authorization code lifetime 10 seconds (`adr/sign-in-path-continuation-protocol.md`, decision 3),
  single use, the checked fields, replay detection and revocation of the token family issued from a
  replayed code (RFC 6749 section 4.1.2; FAPI 2.0).
- One-statement atomicity: consume with
  `UPDATE ... SET state = 'consumed' WHERE digest = ? AND state = 'issued' AND expires_at > now() RETURNING ...`
  (or `DELETE ... RETURNING` plus a replay record), never read-then-write. Counters with
  `UPDATE ... SET count = count + 1 ... RETURNING`.
- Only digests of raw codes are stored, never the codes.
- Explicit states with NOT NULL columns (AGENTS.md); purge expired rows.

## Work order (Codex, later)

```
Move or delete the Valkey stores in section A of
docs/backlog/2026-11-11-move-valkey-auth-state-to-postgresql.md. Delete stores whose flow no longer
exists after the OP-only cleanup instead of moving them; move the rest to PostgreSQL in the OP
database following section E's pattern. Keep the behavior listed under "Keep when moving". Check
section B: list every account-level limit and where it is stored, and move any held only in Valkey.
Add public-boundary tests for single use, expiry, field mismatch, replay with family revocation,
two concurrent redemptions of one code (exactly one succeeds) and concurrent OTP failures (the
budget is never exceeded). Remove the Lua scripts and unused Valkey auth-state code and namespaces.
No compatibility layer; no commit. Record evidence/.
```
