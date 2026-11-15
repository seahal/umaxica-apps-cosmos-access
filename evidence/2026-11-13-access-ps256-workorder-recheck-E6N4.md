# Access PS256 Migration Work-Order Recheck

## Revision and scope

- Repository: Access, branch `feature`; `git rev-parse HEAD`:
  `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree was already extensively modified and uncommitted. Results apply to that worktree, not
  a clean checkout. No commit, push, deployment, credential edit, or production key operation
  occurred.
- The Access PS256 implementation and original Red/Green cycle were already present. This pass
  revalidated the current implementation, refreshed the focused and full test results, and clarified
  that the older Access Preference JWT ADR is historical after decision 17 of
  `adr/access-is-a-pure-openid-provider.md`. It made no application or test behavior change.

## Implemented contract

Access-issued first-party JWT families use PS256 with RSA keys of at least 3,072 bits: Auth access,
OIDC ID/logout, Jump return, RP state, and step-up, passkey, and social ceremony contracts. The
first-party verifier/JWKS path rejects non-RSA keys, weak moduli, unsupported algorithms, private
JWK members, mismatched keys and invalid signatures. Each token family retains its own type, issuer,
audience, purpose, expiry, replay and redirect checks. Discovery advertises PS256. There is no
first-party ES384 compatibility period. AWS KMS signing remains deferred.

No production or real signing key was created or changed. Deployment owners must provision matching
unencrypted PKCS#8 RSA-3072-or-larger key material and unique PS256-generation `kid` values for the
configured Access OP key sets (`AUTH_JWT_*`, `JWT_AUTH_APP_*`, `JWT_AUTH_ORG_*`, `JWT_VISA_APP_*`,
`JWT_VISA_ORG_*`) and the required `OIDC_CLIENT_<NAMESPACE>_*` signers. The precise required
variable/credential names and unresolved coordination are detailed in
`evidence/2026-11-13-access-ps256-migration-6D2A.md`.

External client assertions remain a separate input protocol and continue accepting the existing
ES384 keys while external RPs migrate. DPoP is a separate proof protocol. The legacy
`GovernanceRevocationCommandVerifier` remains unchanged because its server-delivered design is
superseded and its removal belongs to the later handoff implementation stage, which is not in this
PS256 scope.

## Verification

- Original Red/Green: PS256 key/JWK policy tests first reported 31 runs, 53 assertions, 9 failures
  and 6 errors; after implementation they passed at 31 runs, 70 assertions, with no failures or
  errors. See `evidence/2026-11-12-access-ps256-migration-K8M4.md`.
- Current focused PS256 selection:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/unit/jit/security/jwt test/services/jump_rt test/services/jump_rt_keyring_test.rb test/services/oidc/discovery_document_test.rb test/services/oidc/end_session_request_test.rb test/services/oidc/logout_request_test.rb test/services/oidc_client_assertion_jwt_test.rb test/services/oidc_issuer_test.rb test/services/oidc_refresh_token_issuer_result_test.rb test/services/oidc_refresh_token_issuer_surface_test.rb test/services/security_jwt_auth_access_token_codec_coverage_test.rb test/services/identity/step_up_ceremony_contract_test.rb test/controllers/auth/oidc_logouts_controller_test.rb test/values/identity_ceremony_contract_guard_test.rb test/values/jump_rt_return_url_value_test.rb test/values/jwt_temporal_validation_test.rb test/values/security_jwt_access_token_negative_cases_test.rb test/values/security_jwt_auth_access_token_codec_failures_test.rb test/values/security_jwt_rfc9068_access_token_profile_test`
  — 450 runs, 1,691 assertions, 0 failures, 0 errors, 0 skips.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails zeitwerk:check` — passed.
- Full Rails coverage run:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 COVERAGE=true RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`
  — 5,695 runs, 37,008 assertions, 100 failures, 102 errors, 0 skips. This dirty-worktree result is
  not green and cannot be attributed solely to PS256. Observed failure classes include removed
  model/fixture references and old Auth/Preference route expectations; the focused PS256 selection
  passed. The 2026-11-12 full run was 5,583 / 35,228 with 95 failures and 152 errors; it too was a
  dirty-tree aggregate and did not provide a clean pre-migration failure baseline.
- SimpleCov reported line coverage 22,746 / 24,895 (91.36%), branch 3,153 / 4,810 (65.55%), and
  all-method coverage 3,756 / 4,126 (91.03%). It excluded 16 stale subprocess reports after the
  merge timeout and stopped normal processing after test errors.
- Current Ruby/ERB/Brakeman/JavaScript/OpenAPI/audit results are recorded in
  `evidence/2026-11-13-ci-static-checks-source-switch-D8K4.md`. RuboCop and `bun run check` remain
  non-green for the unrelated worktree offenses and Playwright `Page` TS2322 mismatches recorded
  there.
- `git diff --check` passed. No config/credentials file changed.

## Remaining `ES384` references

`rg -n 'ES384' app lib config docs adr openapi` reports 85 lines in 27 files. The seven active code
hits are limited to:

- External RP client assertion verification in `lib/jit_security_jwt_jwk.rb` and
  `app/values/oidc_client_assertion_jwt.rb`.
- DPoP proof verification in `app/lib/dpop_proof_verifier.rb`.
- The explicitly deferred legacy Governance revocation-command verifier in
  `app/adapters/governance_revocation_command_verifier.rb`.

The other hits describe external Jump's still-ES384 published receiver contract, external RP
assertion overlap, separate ChainSeal/DPoP protocols, or historical and superseded material. The old
Preference JWT ADR is now explicitly marked historical for Access in the ADR itself and
`adr/README.md`, because current Access decision 17 assigns preferences to Governance. Historical
SRS/DDS and vendor identity snapshots already identify themselves as superseded. No first-party
Access signer or verifier retains ES384.

## Interoperability limits

Read-only repository observations in the earlier PS256 evidence remain current: Governance's
first-party signer still used ES384; the Edge Jump receiver contract still specified ES384 and live
JWKS verification was unavailable; Sphere and Press signing behavior was unconfirmed. The other
repositories and live endpoints were not fetched or contacted in this recheck. Cross-repository
sign-in, production key provisioning and live Jump return interoperability remain unverified.
