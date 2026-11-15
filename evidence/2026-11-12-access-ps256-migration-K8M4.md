# Access PS256 Migration

Observed on 2026-11-12 for `plans/2026-11-13-access-ps256-migration-work-order.md`.

## Revision and worktree

- Repository: Access
- Branch: `feature`
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`
- The worktree was extensively modified and uncommitted before this work. It includes the preceding
  Access database-retirement changes and the static-check source switch recorded in
  `evidence/2026-11-12-ci-static-checks-zero-N4K7.md`. Their changes were preserved. No commit or
  push was made.
- No `config/credentials/*.yml.enc` file changed. No production key was created, provisioned, or
  edited.

## Implementation

Access now uses PS256 with RSA keys of at least 3072 bits for its first-party JWTs: Auth access
tokens, OIDC ID and logout tokens, Jump RTs, OIDC RP state, and the step-up, passkey, and social
ceremony contracts. Access also verifies Jump return tokens as PS256. Discovery advertises PS256 for
ID tokens. Access-issued client assertions use PS256. The inbound external client-assertion boundary
continues to accept PS256 and the existing ES384/P-384 keys, and Discovery advertises both until the
RP owners migrate.

`JitSecurityJwtJwk`, JWKS parsing, key loading, the issuer registry, and the development/test local
key installer now enforce RSA PS256 for first-party records. Private keys are unencrypted PKCS#8 PEM
or Base64-encoded PKCS#8 DER. Active private/public key mismatches, EC keys in first-party records,
unsupported algorithms, and RSA keys below 3072 bits fail closed. The local installer generates RSA
3072-bit keys with `ps256` in its `kid` values. No test-only production branches were added.

The application and runbook key names the owner must provision are:

- Auth keyset: `AUTH_JWT_ACTIVE_KID`, `AUTH_JWT_PRIVATE_KEYSET`, `AUTH_JWT_PUBLIC_KEYSET`, and
  `AUTH_JWT_REVOKED_KIDS`.
- Surface signers for each of `AUTH_APP`, `AUTH_ORG`, `VISA_APP`, and `VISA_ORG`:
  `JWT_<NAMESPACE>_ACTIVE_KID`, `JWT_<NAMESPACE>_PRIVATE_KEY`, `JWT_<NAMESPACE>_PUBLIC_KEYSET`, and
  `JWT_<NAMESPACE>_REVOKED_KIDS`.
- OIDC client signers use the corresponding
  `OIDC_CLIENT_<NAMESPACE>_{ACTIVE_KID,PRIVATE_KEY, PUBLIC_KEYSET,REVOKED_KIDS}` names. The registry
  currently requires private signing material for `BASE_RP_APP_WW`, `BASE_RP_ORG_WW`, `WARP_APP_JP`,
  `WARP_ORG_JP`, and `TECH_ORG_WW`; the owner must provision matching RSA 3072-bit or larger PKCS#8
  keys.

Production `kid` values must be globally unique and identify the PS256 generation (the runbook
example is `visa-app-ps256-prod-2026-11-a`). Development/test `kid` values are generated locally.
These are configuration requirements only; key material was not provisioned.

## TDD and verification

- Red: the new PS256 key-policy unit selection initially reported 31 runs, 53 assertions, 9
  failures, and 6 errors. Green after the key/JWK implementation: 31 runs, 70 assertions, zero
  failures or errors.
- A full-suite run exposed stale token-encoder coverage setup that called the current API without
  its required `resource_type` and instantiated retired `Client` / `Operator` models. The test now
  supplies ID-only resource objects matching the codec contract. Its focused run passed: 8 runs, 28
  assertions, zero failures or errors.
- Focused JWT, Jump service, OIDC assertion/discovery/logout, RFC 9068, and ceremony contract tests:
  340 runs, 1,318 assertions, zero failures, errors, or skips.
- Token-claim and issuer-consistency integration selection: 4 runs, 47 assertions, zero failures,
  errors, or skips.
- `bin/rails zeitwerk:check`: passed.
- `bundle exec erb_lint --lint-all`: passed for 541 files.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: passed with zero warnings and
  errors.
- `bun run openapi:lint` and `bun run openapi:verify`: passed; the bundled API documents remained
  unchanged.
- `git diff --check`: passed. RuboCop passed for the PS256 policy and access-token coverage tests.
- Full `bin/rubocop`: 2,012 files inspected, 61 offenses, 50 autocorrectable. The changed-Ruby
  selection had four remaining offenses in unrelated pre-existing worktree files:
  `test/security/audit_record_integrity_test.rb`,
  `test/security/invariants/op_authority_stop_single_writer_invariant_test.rb`,
  `test/services/branch_coverage_batch28_concern_easy_arms_test.rb`, and
  `test/services/branch_coverage_batch38_threshold_push_test.rb`.
- `bun run check`: failed at Oxlint/TypeScript with four `TS2322` Playwright `Page` type-copy
  mismatches in unchanged `e2e/ui-components-acceptance.spec.ts`, `e2e/ui-erb-presentation.spec.ts`,
  `e2e/ui-foundations.spec.ts`, and `e2e/ui-presentation.spec.ts`. The same toolchain problem was
  recorded before this implementation in the static-check evidence. OpenAPI checks were run
  independently and passed.
- Final `bin/rails test` with the verified active test-database allow-list completed with 5,583
  runs, 35,228 assertions, 95 failures, 152 errors, and zero skips. This is not a clean suite
  result. The preceding worktree had already removed Access flows and models; examples include route
  tests now reaching the intentional `unavailable_ceremonies` 503 response, assertions for retired
  Jump issuer namespaces, and tests referring to removed models or fixtures. The static-check
  evidence records that Rails tests were not run at that earlier point, so a pre-PS256 full-suite
  count is unavailable; these failures cannot all be claimed as reproduced baseline failures. No
  failing test was suppressed or deleted for this migration.

## Interoperability and residuals

Read-only public GitHub snapshots do not yet demonstrate end-to-end interoperability:

- Governance default-branch snapshot `f24fb7b49f0059ee66e932eb8a07bceac5b89cee` still fixes ES384 in
  `lib/jit_security_jwt_jwk.rb`, `lib/jit_security_jwt_keyring.rb`,
  `app/values/security_jwt_jump_rt_token_codec.rb`,
  `app/values/security_jwt_auth_access_token_codec.rb`,
  `app/values/security_jwt_oidc_id_token_codec.rb`, `app/values/oidc_logout_token_codec.rb`, and the
  identity ceremony contracts. Its discovery profile still advertises ES384. Governance must migrate
  its inbound Access token verifiers before cross-repository sign-in works.
- Sphere and Press returned no `ES384` code-search results in the available public GitHub index;
  that is insufficient to confirm their current verification algorithms. Their local worktrees were
  unavailable and were not edited.
- Edge Jump public snapshot `0678dfb4027d3ff47e1a8731b9d6f0d4dd038cb0` still specifies ES384 in
  `src/cloudflare.ts`, `src/core/sign_outbound.ts`, `src/core/jump_jwks.ts`, and
  `docs/receiver-contract.md`. The deployed Jump JWKS check previously returned 503. Live
  return-token interoperability and cross-repository tests remain unverified; Access was not
  weakened to accept ES384 first-party tokens.
- `ES384` remains in Access source only for external client assertions, the unchanged
  Governance-revocation command verifier, and external DPoP proofs. These are distinct protocols; no
  first-party Access signer/verifier retains ES384.
- The ignored local `tmp/local_jwt_keysets.json` has 20 active PS256 RSA-3072 public JWKs and two
  dormant legacy Preference EC entries. These private key values were not printed or changed; the
  current registry has no Preference issuer namespace. The ignored local store remains a cleanup
  item, not a production-key migration.
- `docs/runbooks/jwt-key-rotation.md` and `docs/security/oidc-discovery-profile.md`, along with
  Preference-specific historical ADR material, still describe retired Preference token behavior.
  They were left for the documentation owner because the preceding instruction explicitly assigned
  those stale-document updates to Claude.
- Live RP/Jump verification, key provisioning, and cross-repository tests remain outstanding.

The Access cut-over is complete in local code and focused tests, but repository and deployment
interoperability is not complete while external verifiers remain on ES384.
