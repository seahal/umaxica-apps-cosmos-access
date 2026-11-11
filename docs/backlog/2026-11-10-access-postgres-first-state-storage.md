# Access: PostgreSQL First for All State; Faster Stores Only When Measured (2026-11-10)

Owner: Access. Status: decided (owner), guidance for current design work.

## Decision (owner, 2026-11-10)

Access designs all state on PostgreSQL first, including short-lived flow records, challenges,
authorization codes and attempt counters. Valkey and PostgreSQL `UNLOGGED` tables are not used for
any of these until a measured performance need appears. Static data (client registrations, JWKS,
configuration) lives in process memory or code.

Reason: Valkey can lose atomicity (for example a failover to a lagging replica), stop, or lose data.
For one-time values and limits that can turn into the unsafe direction (a used value accepted again,
or a limit reset). PostgreSQL keeps one authority with transactions.

## Write cheap SQL from the start

- Compare-and-set in one statement: `UPDATE ... WHERE id = ? AND version = ? RETURNING`, not a
  separate `SELECT ... FOR UPDATE` followed by `UPDATE`.
- One-time values consumed in one statement:
  `DELETE ... WHERE id = ? AND expires_at > now() RETURNING` (or an equivalent conditional
  `UPDATE`), so only the first caller gets the row.
- External calls (Turnstile, mail delivery, Governance lookups) stay outside transactions.
- Keep the number of SQL statements per sign-in and per token request small and known; a test may
  pin it later.

## When a faster store is considered later

Choose by the direction each data kind fails in when the store loses, stops or reorders writes:

| Store                       | Allowed only for                                                                    | When it fails      |
| --------------------------- | ----------------------------------------------------------------------------------- | ------------------ |
| Valkey cache                | copies of PostgreSQL data, invalidated on change                                    | read PostgreSQL    |
| Valkey pre-filter           | quick refusal of already-used values; PostgreSQL still decides acceptance           | PostgreSQL decides |
| Valkey short throttle       | second-level request bursts; account lockouts stay in PostgreSQL                    | fail closed        |
| PostgreSQL `UNLOGGED` table | data whose loss makes it unusable (flow records, challenges, codes), never counters | flows restart      |

Valkey never holds the authority for one-time use, limits, sessions or credentials. Record a
measured reason (`evidence/`) before adopting any of these.
