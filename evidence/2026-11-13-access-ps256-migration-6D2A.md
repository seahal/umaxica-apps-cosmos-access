# Access PS256 Migration — Ordered Work-Order Completion

Completed and revalidated `plans/2026-11-13-access-ps256-migration-work-order.md` on 2026-11-13. The
implementation and original Red/Green cycle predated this revalidation and are detailed in
`evidence/2026-11-12-access-ps256-migration-K8M4.md` and
`evidence/2026-11-13-access-ps256-current-P4J2.md`.

## Revision and worktree

- Repository: Access; branch `feature`; `git rev-parse HEAD`:
  `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- At this capture the worktree had 263 changed paths. Earlier authorized changes were preserved;
  results apply to the dirty worktree.
- No `config/credentials/*.yml.enc` file changed. No production key material was generated,
  provisioned, printed, or edited. No commit or push was made.
- `git diff --check` passed. This revalidation made no application or test-file changes.

## Implemented contract

Access first-party JWT signers and verifiers use PS256 with RSA keys of at least 3072 bits. This
covers Auth access tokens, OIDC ID/logout tokens, Jump return tokens, RP state, and step-up,
passkey, and social ceremony contracts. Discovery publishes PS256 for ID tokens; Access-issued
client assertions use PS256. Per-family `typ`, issuer, audience, purpose, expiration, replay, key
identity, and redirect checks remain distinct and fail closed. Key loading/JWK/JWKS policy refuses
wrong key types, undersized RSA moduli, unsupported algorithms, mismatched private/public keys, and
invalid signatures. No ES384 overlap remains for first-party Access JWTs.

External client assertions remain a separate RP input protocol and currently accept PS256 plus ES384
while Governance and other RPs migrate. The old Governance revocation-command verifier stays
unchanged for the later handoff work. DPoP client proofs and ChainSeal signatures are separate
protocols and remain outside this JWT cut-over.

Production owners still need to provision matching unencrypted PKCS#8 RSA-3072-or-larger keys for
`AUTH_JWT_ACTIVE_KID`, `AUTH_JWT_PRIVATE_KEYSET`, `AUTH_JWT_PUBLIC_KEYSET`, `AUTH_JWT_REVOKED_KIDS`;
the active `JWT_AUTH_APP_*`, `JWT_AUTH_ORG_*`, `JWT_VISA_APP_*`, and `JWT_VISA_ORG_*` key sets; and
the required `OIDC_CLIENT_<NAMESPACE>_*` signers. Production `kid` values must be unique and
identify the PS256 generation. No values were provided or changed here. AWS KMS signing remains
deferred.

## TDD and current verification

- Original policy Red: 31 runs, 53 assertions, 9 failures, 6 errors. After implementing the RSA
  PS256 key/JWK policy, Green: 31 runs, 70 assertions, no failures or errors. See K8M4.
- Current focused selection for JWT key/JWKS policy, access-token codecs/profile, Jump RT services,
  OIDC discovery/logout/assertions/issuer, refresh-token issuer, ceremony contracts, and temporal
  validation:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/unit/jit/security/jwt test/services/jump_rt test/services/jump_rt_keyring_test.rb test/services/oidc/discovery_document_test.rb test/services/oidc/end_session_request_test.rb test/services/oidc/logout_request_test.rb test/services/oidc_client_assertion_jwt_test.rb test/services/oidc_issuer_test.rb test/services/oidc_refresh_token_issuer_result_test.rb test/services/oidc_refresh_token_issuer_surface_test.rb test/services/security_jwt_auth_access_token_codec_coverage_test.rb test/services/identity/step_up_ceremony_contract_test.rb test/controllers/auth/oidc_logouts_controller_test.rb test/values/identity_ceremony_contract_guard_test.rb test/values/jump_rt_return_url_value_test.rb test/values/jwt_temporal_validation_test.rb test/values/security_jwt_access_token_negative_cases_test.rb test/values/security_jwt_auth_access_token_codec_failures_test.rb test/values/security_jwt_rfc9068_access_token_profile_test.rb`
  — 450 runs, 1,691 assertions, zero failures, errors, or skips.
- A broader 461-test selection that also included legacy route/audience integration contracts had 20
  failures and 3 errors. They expect retired sign-in routes, `BASE`/`CORE`/`PALM`/`WARP` issuer
  namespaces, or old client-assertion audiences; these are existing Access-split worktree contracts,
  not PS256 cryptographic failures. A related selection including `Security::TokenLifetimesTest` had
  one additional error because it references the removed `AuthenticationBase::ACCESS_TOKEN_TTL`
  constant. Those tests were not weakened or removed.
- `bin/rails zeitwerk:check`: passed (`All is good!`).
- Current `bin/rubocop`: 2,026 files, 56 offenses, 45 autocorrectable. Workflow fail-fast RuboCop
  stops at `script/public_protected_method_coverage.rb:65` (`Lint/AssignmentInCondition`); this is
  an unrelated untracked file from earlier work. Full current static results are in
  `evidence/2026-11-13-ci-static-checks-9J2M.md`.
- Current full Rails coverage run:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 COVERAGE=true RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`
  — 5,649 runs, 36,594 assertions, 99 failures, 128 errors, 0 skips. It is a dirty-worktree
  aggregate and cannot be attributed solely to this migration.

## Remaining `ES384` references and interoperability

`grep -rn ES384 app lib config docs adr openapi` found 85 matching lines across 27 files. Remaining
code references are the external RP client-assertion verifier
(`app/values/oidc_client_assertion_jwt.rb`, `lib/jit_security_jwt_jwk.rb`), the superseded
Governance revocation-command verifier, and DPoP proof verification. ChainSeal uses ES384 as a
separate signature format. Current Jump receiver documentation still specifies ES384. Old Preference
and pre-cut-over design text remains in superseded/historical ADRs, backlog, SRS/DDS, and vendor
identity documents; these are not active first-party Access JWT verifiers.

Existing read-only coordination findings remain current: Governance still signs first-party tokens
with ES384; Edge Jump still documents/implements ES384 and its deployed JWKS was previously observed
as 503; Sphere and Press algorithms are unconfirmed. Cross-repository sign-in, live Jump return
verification, production key provisioning, and cross-repository integration tests remain unverified.
Access was not weakened to accept ES384 first-party tokens.

The Access cut-over is complete locally and its current focused contract selection is green. The
end-to-end service is not interoperable until the external verifiers and production keys are updated
by their owners.
