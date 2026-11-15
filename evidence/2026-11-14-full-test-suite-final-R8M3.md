# Full Test Suite Final

## Scope and revision

- Repository: Access.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree remained extensively uncommitted; those changes affect this result. No commit or push
  was made.
- This record closes the second ordered task in the current request. It follows the earlier failure
  classification in [the suite triage record](2026-11-14-full-test-suite-triage-F3Q8.md).

## Red / Green

- Red: the full suite first reported 5 failures and 0 errors. Four related failures reproduced in
  isolation: a destroyed sign-up binding did not surface its database restriction, the sign-in-flow
  test referenced a removed class-attribute API, the OP authority invariant's existing Device
  Session exception did not match its source line, and a concern test asserted the removed
  include-time layout derivation behavior.
- Changes: removed the newly added `ClientAuthAdmissionBinding#sign_up_flows` dependent association
  so the existing PostgreSQL `ON DELETE RESTRICT` remains the deletion boundary; changed the sign-in
  test to exercise public `cycle_status_id`; corrected the existing OP authority invariant pattern;
  removed the test whose include-time concern behavior no longer exists after explicit host layout
  declarations.
- Green: the affected sign-up, admission-binding, ceremony, authority-invariant and branch tests
  passed together: **57 runs, 759 assertions, 0 failures, 0 errors, 0 skips**.

## Full suite

- Command: `RAILS_ENV=test bin/rails test` (the test-only database preparation flag was unset for
  this invocation; no shared or production database was used).
- Result: **5,573 runs, 36,860 assertions, 1 failure, 0 errors, 0 skips**.
- Remaining failure:
  `OpenapiRouteCoverageTest#test_no_Auth_or_Visa_route_is_missing_from_its_surface_description`
  requires a description for `POST /api/v0/revocation_commands`.
- Disposition: the endpoint implements the superseded server-push design in ADR decision 18. Its
  removal/caller cleanup belongs to the explicitly excluded Jump handoff Stage 4. Adding an OpenAPI
  description would document that superseded API; deleting or exempting the route test would weaken
  coverage. No route, contract, or assertion was changed. The failure remains for the owner/Stage 4
  work.
- Earlier triage classified 197 unique failures as 103 delete (removed subjects), 86 update (changed
  contracts), 7 code fixes, and 1 blocked contract decision; see the linked triage record for
  details.

## Limits

- The suite is not fully green. The only remaining observed failure is the Stage 4 route-coverage
  conflict above; all other tests passed in the recorded full run.
- No secrets or environment values were recorded.
