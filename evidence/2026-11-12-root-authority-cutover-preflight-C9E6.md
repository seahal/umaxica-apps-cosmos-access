# Pre-retirement root-authority cutover check

Date: 2026-11-12. HEAD: f84c87b060876a25994e30e9274420d9067f1367. Uncommitted script changes affected results. This is an operational pre-retirement check, not a retained actor cache or runtime compatibility path.

## Approved boundary

The user approved preserving exact device-session principal subjects and removing old actor dependencies. Removing old actor checks could otherwise make an existing ACTIVE OP root usable again despite a withdrawn/locked actor, stale epoch or administrative JWT cutoff. The exporter now checks these prerequisites before writing any CSV. It invokes the actual old actor active/admin predicates, AuthenticationEpochValue equality and the old administrative cutoff predicate with integer root-creation time as the earliest possible JWT iat. Both lower and higher root epochs are refused when unequal.

The preflight also refuses a finite old actor purge deadline earlier than the root expiry, including nonfinite/missing root expiry. Equal deadlines are accepted: the retained root-expiry guard refuses authority at the deadline. It does not shorten deadlines, fabricate flags or revoke records. Device/actor ownership must match. Failure messages contain category counts only.

The conservative scope is every ACTIVE-status root, including expired or rotated history. This can refuse legitimate historical rows that no longer authorize anything; it is deliberately not a universal production-migration guarantee. Historical non-ACTIVE device rows still require exact subject mapping under the original contract.

## Required operational order

1. Stage both tracked scripts in the pre-removal deployment/worktree: export_device_session_principal_public_ids.rb and device_session_principal_export_preflight.rb. The actual old actor models and configured writers must still exist there.
2. Pause old principal/root mutation writers for the cutover. Separate OP and actor read-only snapshots are not a shared distributed snapshot. Keep writes paused until subject import and the new signed Governance authority handoff are ready; do not assume future commands retroactively cover an unobserved gap.
3. Run the script directly with Ruby, not through a prebooted Rails runner, with explicit environment and `PGOPTIONS='-c default_transaction_read_only=on'`. The script refuses missing/off PGOPTIONS before Rails boot, so startup or model connections cannot write PostgreSQL.
4. Keep private mode0600 CSVs and separately verified hashes; apply the approved scoped OP migrations, then verify exact subjects before retiring source configuration/data. No new persisted fields or claim shapes are introduced by preflight.

Example, from the staged pre-removal tree:

```sh
PGOPTIONS='-c default_transaction_read_only=on' RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec ruby scripts/export_device_session_principal_public_ids.rb app /private/app-subjects.csv
PGOPTIONS='-c default_transaction_read_only=on' RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec ruby scripts/export_device_session_principal_public_ids.rb org /private/org-subjects.csv
```

A refusal requires an authoritative cutover decision. The exporter never repairs, ignores or automatically revokes the affected roots. Re-run from a stable old-source snapshot after resolving the cause. No production migration or external Governance producer behavior was verified here.

## Observed verification

- An isolated git archive of the stated HEAD booted in test mode with PostgreSQL read-only enforcement; no migrations or test preparation were invoked. Seven old actor/authority source files matched git HEAD byte-for-byte, and the originally removed actor files had been clean. Current runtime actor code/configuration was not restored.
- Real test writers contained two ACTIVE-status roots per realm. The actual-source predicate matrix passed: one run, 66 assertions, zero failures/errors/skips. Every checked PostgreSQL writer reported transaction_read_only=on.
- Negative predicate cases used detached copies of the actual old Active Record instances: withdrawn actor, root epoch lower/higher, admin lock, fractional administrative cutoff, future actor deadline minus one microsecond/equal/plus one microsecond, nil and infinity. Original database rows were never modified. These are not claims of persisted negative-fixture or concurrency testing.
- Genuine deadline Red: the plus-one-microsecond case expected refusal and initially raised nothing (one run, 25 assertions, one failure). After adding the deadline guard, the full 66-assertion matrix passed. Earlier missing-helper/deprecated-accessor/temporary-fixture errors were setup failures, not behavioral Red.
- Final staged APP and ORG CLI runs each checked two roots and exported two mappings. Output bytes exactly matched the already imported original subject CSVs, with mode0600. No identity mappings are printed or recorded in evidence.
- Original development OP writer databases were inspected read-only: zero roots and zero devices in each realm; the empty preflight returned zero. Development was not migrated or booted in development mode for this check.
- Missing and explicitly off PGOPTIONS commands both exited 1 before Rails boot and created no CSV. These operational environment checks were run directly, not added to the standard test suite.
- RuboCop inspected the two scripts with zero offenses. No actor/root/database/schema writes, root revocations, CI edits or existing architecture-document rewrites occurred in this slice.

The parent owns retained runtime issuance, receiver authority, global tests and final DatabaseConsistency. This record does not mark those complete.
