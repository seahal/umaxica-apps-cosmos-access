# Governance revocation receiver verification

Date: 2026-11-12. HEAD: `f84c87b060876a25994e30e9274420d9067f1367`.
Status: locally verified in the combined regression and coverage run. Real Governance
integration is not configured. Pre-existing, concurrent,
and task-owned uncommitted changes affect this worktree. This record does not establish completion
of the overall database-removal task.

## Approved boundary

The owner approved a signed Governance command receiver and one dedicated receipt table in each
OP realm. The new Visa APP/ORG resource is `POST /api/v0/revocation_commands`. Commands and completed
acknowledgements use distinct JWT types and ES384 signatures. Request claims bind issuer, audience,
realm, subject, command UUID, scope, authorizing actor, reason, and an optional scope-bound session
public identifier. Transport timestamps are excluded from the immutable semantic digest so a fresh
signed retry can acknowledge the same command without selecting later sessions.

The receipt and existing root-stop primitive share the realm OP transaction. No Governance epoch is
invented. Empty all-session targets produce a command receipt without a synthetic principal stop.
Existing back-channel logout participants remain the durable asynchronous delivery mechanism.

The owner separately approved exactly two historical-navigation exceptions:
`OpAppGrant.client_token` and `OpOrgGrant.operator_token`. Their ORM APIs and inverse associations
remain present. New grants require a persisted issuing root bound to the required stable device;
historical root IDs remain required and both root/device references are read-only after creation.
Only navigation to an old physically purged root can be absent. No root foreign key, optional
device association, schema change, checker exclusion, or broader association exception was added.
Reference immutability is an ORM guarantee here. The direct SQL tests establish NOT NULL and the
existing device foreign key; they do not claim database-level rejection of every reference update.

## Configuration and integration limit

The real Governance issuer and JWKS URLs are unknown. No URLs or trust defaults were invented.
The receiver requires `GOVERNANCE_APP_REVOCATION_ISSUER`,
`GOVERNANCE_APP_REVOCATION_JWKS_URL`, `GOVERNANCE_ORG_REVOCATION_ISSUER`, and
`GOVERNANCE_ORG_REVOCATION_JWKS_URL`; missing configuration produces an explicit unavailable response.
Real Governance interoperability remains unverified. Unit and HTTP test inputs use disposable
signing keys and fake external JWKS retrieval. HTTP transport is separately exercised through a
fake public Faraday request boundary; no outbound network permission was enabled in the Rails tests.

## Verified observations

- `bundle exec ruby test/values/governance_revocation_command_value_test.rb`: 4 tests,
  51 assertions, zero failures/errors.
- `bundle exec ruby test/adapters/governance_revocation_command_verifier_test.rb`: 5 tests,
  56 assertions, zero failures/errors. Coverage includes real ECDSA verification, forged signatures,
  wrong token types, key confusion, realm/audience mismatch, expiry, private or ambiguous keysets,
  key-count/kid/body-size boundaries, HTTP failure, timeout, malformed JSON, and destination refusal.
- Initial unit tests failed before the implementation classes existed. A later destination-refusal
  test failed because `InsecureEndpointError` escaped the dependency boundary; the narrow exception
  mapping now passes without permitting the destination.
- Direct PostgreSQL verification accepted two valid receipt shapes and refused 19 invalid inserts
  per realm. All fixture transactions rolled back. This verifies the primary key, all five NOT NULL
  columns, digest length, realm, required JSON facts, scope/target shape and unknown-field rejection.
  It does not verify signature authentication or application revocation behavior.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test bin/rails test`
  with `test/operations/governance_revocation_command_test.rb`,
  `test/controllers/visa/governance_revocation_commands_controller_test.rb`, and
  `test/concurrency/governance_revocation_receipt_concurrency_test.rb`: 13 tests, 312 assertions,
  zero failures/errors/skips. Both realms exercise actual root/grant revocation, unrelated-principal
  isolation, rollback, persisted replay, no later-session selection, signed HTTP acknowledgements,
  unavailable configuration, signature refusal, and direct SQL contracts. Concurrency tests observe
  actual PostgreSQL lock waits for duplicate receipts and refresh-versus-revocation serialization.
- The HTTP outer-transaction case reached the old codec's late `ArgumentError` before the fix.
  The coordinator now refuses an enclosing transaction before any mutation, returns an explicit
  unavailable response, and signs an acknowledgement only after its own receipt transaction has
  committed. The codec receives scalar claims and has no Active Record dependency.
- After the additional approved association fix,
  `test/models/op_grant_historical_root_contract_test.rb` plus
  `test/operations/governance_revocation_command_test.rb` passed ten tests and 210 assertions with
  zero failures/errors/skips. The new contracts first failed on missing scalar-ID validation and
  mutable root ownership. Both realms then passed physical deletion of the old rotating root,
  continued grant usability through the current device parent, and actual command revocation.
- Final combined execution included the two standalone unit files and four Rails files listed
  above, with `tmp/governance_receiver_coverage.rb` loaded before `bin/rails test`: 26 tests,
  509 assertions, zero failures/errors/skips. The run includes implicit create-time device binding,
  rejection of an unsaved issuing root, immutable references, preserved historical IDs after
  revocation, both realm HTTP endpoints, and both PostgreSQL concurrency cases.
- Scoped coverage across the nine receiver files and two changed grant models: lines 351/368
  (95.38%), branches 110/126 (87.30%), methods 40/42 (95.24%). This is not whole-application coverage.
- An early automatic preparation applied the two empty generator scaffolds before their bodies
  were complete. The first Rails contract run exposed missing `command_id` columns. Each table was
  confirmed to contain only `id` and zero rows in its named local test OP database, then only its
  own migration was rolled back and reapplied. No retained table or production database was dropped.

## Limits and follow-up

A further regression case covers a grant whose historical issuance root has been
purged while its stable device has a current root. D3 permits this history. Its first execution
failed in the receiver's overly strict historical-root guard. That guard now follows the device
parent. The next execution reached the existing grant save and exposed a missing historical-root
validation; translated exception formatting initially masked it. Public `valid?`/`errors.details`
then confirmed `{client_token: [{error: :blank}]}` while the retained grant was still active:
one test, five assertions, one failure, zero errors. The owner then approved the two explicit
historical-navigation exceptions above, and the regression passed in both realms. No foreign key,
locale, or validation bypass was changed by this receiver slice. Original D3 missing-root-FK
checker reports remain deliberately unresolved; they are not hidden by this fix.

Successive early Rails boots encountered removed feature constants; no behavioral Red was inferred
from those boot failures. The first complete batch exposed fixture setup mistakes: an omitted ORG
browser kind, a grant expiry slightly beyond its root cap, and cached lock-observation queries.
Those fixtures now name the accepted kind, use a strict expiry ordering, and observe locks uncached;
no production invariant was relaxed. The physical ORG token default of zero, which names a missing
kind row, remains a separate pre-existing database-consistency finding for the owning task.

RuboCop passed for the receiver files and the additional model contracts. Fresh whole-database rebuilds, development preparation,
the complete application suite, and DatabaseConsistency remain owned by the parent task.

Temporary command logs and scoped verification scripts are under `tmp/` and are not
committed evidence. Existing architecture documents were not rewritten by this receiver slice.
Claude's documentation follow-up includes the two explicit exceptions in
`docs/reference/forbidden-rails-methods.md` and the D3 association-validation explanation; the
historical association API and no-token-FK decision remain intact.
