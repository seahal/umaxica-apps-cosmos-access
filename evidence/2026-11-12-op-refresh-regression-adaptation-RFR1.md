# Retained OP refresh regression adaptation

HEAD: `f84c87b060876a25994e30e9274420d9067f1367`. The worktree contained substantial
uncommitted retirement and OP-boundary changes; these results include that work.

Six existing regression files now construct real OP device sessions with explicit scalar
principal IDs and immutable public-subject snapshots. They pass the required browser
`resource_type`; the refresh-result contract includes `response`. Copied, unused helpers
for retired account, email, social-login and credential storage were removed. No new test
helpers or production test branches were added.

The sole removed behavior case was
`TokenStatusManagementTest#token revocation closes admitted continuity before at and after expiry on all three surfaces`.
It created local Client/Operator passkeys and established new step-up authorizations through
retired identity data. New credential enrollment and step-up admission are explicitly unavailable
until Governance exists. Its successful issuance premise no longer belongs to Access.
All standalone status, expiry, revoke, replay, rotation and clock assertions remain. The parent
owns replacement retained ceremony revocation and explicit-unavailable boundary coverage.

Actual verification:

- Six adapted files: `55 runs, 287 assertions, 0 failures, 0 errors, 0 skips`.
- The same six plus `test/models/op_grant_historical_root_contract_test.rb`:
  `59 runs, 379 assertions, 0 failures, 0 errors, 0 skips`.
- Commands used `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test bin/rails test`
  followed by the six files and, for the combined run, the historical-contract file.
  Logs: `tmp/refresh-regressions-first.log`, `tmp/refresh-regressions-final.log`.

The additional historical grant-only stop regression first failed with
`ActiveRecord::RecordNotFound` in `OpAuthorityStopCommitter#lock_grant_chain` after real
browser rotation and direct physical deletion of the original root. The operation still
locked the historical root ID. Its chain now follows the existing RpSession chain:
stable device, the current root scoped to that device, then the grant. A locked grant must
still belong to that device. The historical root ID remains immutable and unchanged;
no FK, schema, checker exclusion or association changes were made for this fix.
The final focused run passed `1 run, 32 assertions, 0 failures, 0 errors, 0 skips`
(`tmp/historical-grant-stop-green.log`). The regression also refuses a current-root
pointer into another device and preserves the replacement root and device after a
successful grant-only stop. RuboCop passed all eight changed Ruby files with no offenses.

No full-suite, real Governance integration or production database validation is claimed here.
