# OP browser session request boundary

Date: 2026-11-12. HEAD: `f84c87b060876a25994e30e9274420d9067f1367`.
Results include substantial uncommitted retirement, OP subject, receiver, refresh and logout changes in the shared worktree. They do not describe clean HEAD.

## Accepted scope and implementation

The approved retirement removes local actor databases while preserving existing OP session authority. Visa APP and ORG explicitly include AuthenticationBase metadata and OpBrowserSessionRequest, with concrete realm token classes, scalar owner references, DBSC endpoints, risk payloads and audit models. No fake actor or current_resource API is supplied.

Each controller explicitly registers the Actor cleanup wrapper, normal no-store/FQDN/CSRF controls, existing Jump/rate checks and the fail-closed boundary guard. Only an explicitly declared open action passes the new boundary. The request wrapper clears Actor before callbacks and in ensure, including refusal paths. Parent-owned logout leaves explicitly opt into expired access credentials; ordinary endpoints do not.

The request reader delegates to the real OP browser resolver. Status preserves numeric owner IDs and the device public session ID. Refresh delegates to the typed issuer, checks idle/DPoP/DBSC prerequisites under its Device-to-root locks, and builds a signed numeric-subject JWT inside the issuer transaction. Verified binding/idle refusal stops the root through the authoritative stop writer after the failed savepoint unwinds. Successful rotation retains the risk event, coarse-network change detection, root risk enforcement and scalar durable-recovery Chronicle audit before installing cookies.

Access JWT encoding accepts an explicit nonblank String subject, including numeric browser subjects. The ID token subject contract is unchanged. Cookie names and lifetimes come from their canonical owners.

DBSC refresh-cookie lookup verifies the secret digest, active root, usable device and current-root pointer. Registration and bound-cookie refresh take Device-to-root locks and recheck the selected credential before writing. Status GET only advertises an already recorded live challenge; creating a fresh challenge belongs to POST. This follows the existing W16 rule that GET/HEAD are read-only.

No retained schema, queue internals or CI configuration changed in this browser slice.

## Observed verification

- Initial behavior Red: two runs, two assertions, one failure and one error. Explicit numeric subject encoding returned nil, and actual Visa status raised missing logged_in?. Log: `tmp/op-browser-request-red.log`.
- First focused Green: eight tests, 69 assertions, zero failures/errors/skips. Real PostgreSQL fixtures and real JWT signatures covered both realm status and refresh, revoked roots, no status GET DML, DBSC challenge expiry immediately below/at/above the limit, missing DPoP proof, forged refresh verifiers, actual ES256 DBSC registration and stopped-root refusal. Log: `tmp/op-browser-request-green.log`.
- The first Green attempt exposed test setup defects: host-scoped secure cookies were missing and the codec fixture omitted mandatory sid. The setup was corrected without weakening assertions.
- Final focused and regression batch: 22 runs, 245 assertions, zero failures/errors/skips (`tmp/op-browser-request-final-coverage.log`). It includes 13 browser/codec cases plus nine existing real-root resolver, typed rotation, existing-session refresh and logout cases. The latter include parent-owned valid/expired logout, invalid pending confirmation and swapped-device refusal cases.
- The final browser cases add idle timestamps one microsecond below, exactly at and one microsecond above the inclusive limit; missing/body refresh transport refusals; and a missing HMAC configuration adapter value. The configuration failure returns HTTP 500 with the root attributes and current-root pointer unchanged, because required HMAC calculation now precedes rotation. This configuration case has observed Green only; no separate behavioral Red is claimed for it.
- The first boundary run exposed fixture ordering: rotate_refresh_token! refreshes last_used_at. Moving the boundary assignment after credential generation exercised the intended persisted timestamp and preserved every assertion.
- Native Ruby Coverage across nine selected browser/codec files measured 395/505 executable lines (78.22%), 88/176 branch arms (50.00%) and 64/100 methods (64.00%). The new request concern measured 121/140 lines, 40/74 branches and 25/27 methods. Both status controllers measured 14/14 lines and 6/6 branches. These are scoped measurements, not repository-wide coverage or a claim that every branch is tested. Exact per-file counters are in the temporary `tmp/browser-session-full-batch-coverage.json`.
- An initial operational coverage reporter incorrectly expected browser files in Rails' schema-preparation subprocess. It failed before tests; the temporary reporter now exits without a report when that target is absent. No application or test-environment configuration was changed to bypass this harness error.
- Twelve owned Ruby files passed RuboCop; scoped diff whitespace checks passed.

## Limits

The DBSC stopped-root test is serial. A concurrent Governance stop versus DBSC registration has not been exercised by this slice; the Device-to-root lock order and locked recheck were inspected. Separate parent/receiver root refresh concurrency checks are not claimed here.

Required network HMAC configuration is checked before rotation. Subsequent network persistence or principal-wide risk database errors remain visible after rotation commit and before cookie installation; such a failure can require a fresh login rather than delivering the new credential. Principal-wide risk enforcement is deliberately outside the individual device lock transaction. Authoritative audit uses the existing nonbang durable-recovery writer. No production execution or full-suite success is claimed.

The parent subsequently assigned the specific device-bound proof integration gap. Two new tests were authored before execution and passed immediately: two runs, 72 assertions, zero failures/errors/skips (`tmp/op-device-bound-dbsc-proof.log`). Each exercises APP and ORG with real EC signatures, public device.bind_dbsc!, exact stored session digests, canonical query-free DBSC audiences despite refresh query parameters, actual key verification and cookies. Success rotates once while preserving bindings; a different private key refuses, records a root stop, rotates nothing, preserves the recorded root/device bindings and clears all three credential cookies. No production fix was needed and no Red is claimed for these already-correct branches. The original 22-case batch was not rerun after adding these tests; the two runs are reported separately. The device-only coverage counters are separate in `tmp/browser-session-device-proof-coverage.json` and are not added to the earlier counters as if they were a merged coverage result.
