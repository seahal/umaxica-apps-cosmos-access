# Access Security Suite and Full Rails Test Results

- Date: 2026-11-08.
- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- The worktree is dirty (1,065 changed, deleted, or untracked paths at recording time). The results
  describe that worktree; no commit was created.

## Security test cleanup

- `test/security/invariants/withdrawal_gate_invariant_test.rb` now keeps one retired-service route
  invariant covering GET `/identity/sessions`, GET `/identity/secrets`, POST `/identity/withdrawal`,
  and GET `/identity/withdrawal/new`. Four duplicate route checks for the first path were removed.
- Removed the obsolete withdrawal journey setup and copied test helpers that only served the deleted
  Base withdrawal flows. The invariant that application controllers cannot skip the withdrawal gate
  remains.
- Retained host-registry, OIDC RP registration, `AuthenticationBase`, Rails
  `ActionController::Base`, and OP database connection references: those are still active
  configuration/framework/security contracts. Retired-host checks remain negative route assertions.
- `bin/rails test test/security`: 144 runs, 821 assertions, 0 failures, 0 errors, 0 skips.
- `git diff --check`: passed.
- `bin/rubocop test/security/invariants/withdrawal_gate_invariant_test.rb`: 1 file inspected, no
  offenses.

## Full Rails suite

- `bin/rails test` completed once with exit status 1: 15,850 runs, 112,380 assertions, 510 failures,
  965 errors, 0 skips. The test database was used; no development database or volume was reset.
- The command output was not saved as a complete log. The visible output contained these examples
  clearly caused by removed draws/routes:
  - `PreferenceCookieConsentLifecycleTest#test_APP_cookie_screen_reads_consent_only_when_its_browser_binding_matches`
    raised `NoMethodError` for the removed `base_app_preference_cookie_path` helper.
  - `BaseRetiredEdgeCookieRouteTest#test_the_API_cookie_endpoint_stays_routable_on_every_Base_surface`
    raised `RoutingError` for a route on the retired `www.umaxica.app` host.
  - `CoreRpBrowserFlowTest#test_regional_core_roots_are_exposed_by_host` received the expected
    unknown-host 404 after its old route was removed.
  - `ComPreferenceCommitFailureTest#test_setting_commit_failure_rolls_back_a_consent_change_and_emits_no_preference_cookies`
    raised `NoMethodError` for `base_com_api_v0_preferences_cookie_path`.
  - `RevisionEndpointTest#test_docs/org_routes_both_revision_endpoints_to_its_own_controllers`
    raised `RoutingError` for the retired Docs host.
- The original pre-change aggregate recorded by the user was 17,164 runs, 146,002 assertions, 302
  failures, 192 errors, and 0 skips. Its individual failure names/details were not retained. A later
  full run on an earlier dirty state recorded 16,049 runs, 112,313 assertions, 652 failures, and
  1,020 errors (`evidence/2026-11-08-visa-step-up-binding-E7K2.md`). The tested worktree has since
  removed or revised tests for retired draws, so these aggregates have different test populations.
- Classification: the examples listed above are change-related because they still expect a deleted
  draw, route, or helper. The remaining failures/errors cannot be assigned individually to the
  changes or to the pre-existing baseline: the original named baseline is unavailable, and this full
  run's complete output was not persisted. The count difference alone does not establish cause.

## Limits

- No credentials, signing keys, development database, volume, container, external service, or
  Cloudflare state was changed. No commit was created.
- This record contains no credential, token, cookie, or secret values.
