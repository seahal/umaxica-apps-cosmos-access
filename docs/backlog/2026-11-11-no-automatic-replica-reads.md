# Access: No Automatic Replica Reads (2026-11-11)

Owner: Access. Status: decided (owner), queued.

## Problem (observed 2026-11-11)

`config/initializers/multi_db.rb` enables Rails automatic role switching:

```ruby
config.active_record.database_selector = { delay: 10.seconds }
config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
```

GET and HEAD requests read from a replica unless the same browser session wrote within the delay.
The delay protects only against a browser not seeing its own writes. A revocation written by someone
else (an operator's force sign-out, a disabled account, a revoked passkey) is not covered: the
affected person's browser has not written recently, so a following `GET /oauth/authorize` can read a
lagging replica, see the revoked OP session as valid and issue a code silently. Increasing `delay`
does not help, and replica lag can exceed any delay during incidents.

## Decision (owner, 2026-11-11)

Access reads everything from the primary. Remove the three automatic-switching settings. Access is
an OpenID Provider only and nearly all its reads are authentication or authorization decisions;
there is little to offload. Performance is measured first if it becomes a concern
(`docs/backlog/2026-11-10-access-postgres-first-state-storage.md`).

## Work order (Codex)

```
Remove database_selector, database_resolver and database_resolver_context from
config/initializers/multi_db.rb so every read uses the primary. Check that no code relies on
connected_to(role: :reading) for authentication, authorization, OP session, token, credential or
account-state reads; report any other reading-role use. Add a request test: after an OP session is
revoked by a server-side write outside the browser's session, an immediate GET /oauth/authorize from
that browser does not issue a code. Run the affected tests and bin/rubocop. No commit.
```
