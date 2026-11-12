# Governance command and browser root refresh races

HEAD: `f84c87b060876a25994e30e9274420d9067f1367`. Substantial existing uncommitted
retirement, receiver and OP-boundary changes affected this verification.

The committed-record PostgreSQL concurrency suite now runs the real typed
`AuthRefreshTokenIssuer.call` against an ES384-signed command verified by the real
Governance verifier. Its JWKS fetcher supplies an explicit test key; no external network
or guessed production trust configuration is involved. Queues hold the first device lock,
and uncached PostgreSQL lock-wait observations prove that the other operation is blocked.
The new cases use no sleeps and introduce no test helpers.

Both orders are tested in both realms:

- Browser rotation commits first: the command stops the newly created replacement,
  all roots, the stable device and its grants.
- Governance stop commits first: browser refresh fails inactive, creates no replacement
  and leaves the original root unrotated.

A targeted source review found a stale selected-device gap. The issuer initially reads
a root, locks its device, then reloads the root under lock. It previously did not verify
that the root still belonged to that device before rotation. The new test holds the old
device lock, observes the refresh waiting, and commits a same-actor reparent to a second
device with both current-root pointers updated consistently. Native constraints stay enabled.
The original issuer incorrectly returned successful rotation: actual Red was one test,
one assertion, one failure, zero errors. No production caller that reparents roots was found;
the test establishes the supported persistence/invariant boundary without a schema bypass.

The approved fix is one explicit `FlowConfigurationError` guard immediately after the
root reload and before the precondition or rotation. A stale device selection now rolls
back without creating a root or changing either device pointer. No immutable-model,
schema, route, trust-configuration or checker-exclusion changes were introduced.

Command:

```sh
env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test \
  bin/rails test test/concurrency/governance_revocation_receipt_concurrency_test.rb \
  test/services/op_browser_refresh_rotation_test.rb
```

Result: **7 runs, 129 assertions, zero failures, errors or skips**.
Log: `tmp/governance-browser-root-races-green.log`.
The final focused reparent rerun using `--include /reparented/` passed one test and
12 assertions with zero failures, errors or skips (`tmp/browser-refresh-stale-device-green.log`).
RuboCop passed the changed issuer and concurrency-test files with no offenses.

The source review also checked typed realm selection, response-signing rollback,
replay device/root/grant revocation and shared device-first lock order. No other material
finding was identified in that scope. DBSC binding concurrency, full-suite results and
real Governance integration are not claimed by this record.
