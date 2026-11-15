# Access PS256 Migration — Current Verification

Observed on 2026-11-13 for `plans/2026-11-13-access-ps256-migration-work-order.md`. The core
implementation and original Red/Green cycle are recorded in
`evidence/2026-11-12-access-ps256-migration-K8M4.md`; this record revalidates the current dirty
worktree and adds browser cookie-size coverage.

## Revision and worktree

- Repository: Access; branch: `feature`.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- At evidence capture the worktree had 196 changed paths (112 modified, 68 deleted, 16 untracked).
  Results apply to this worktree, which contains previous ordered work and coverage changes.
- `config/credentials/` was clean. No production key was generated, provisioned, or edited. No
  commit or push was made.
- `git diff --check` passed.

## Current implementation contract

Access first-party JWT signers and verifiers use PS256 with RSA keys of at least 3072 bits. The
policy covers Auth access tokens, OIDC ID/logout tokens, Jump RT and return tokens, RP state, and
step-up/passkey/social ceremony contracts. JWK ingestion checks the RSA/PS256 key profile, public
key shape, signature algorithm and minimum modulus. Token families retain separate `typ`, issuer,
audience, purpose and claim validation. Discovery separates PS256-only ID tokens from the external
client-assertion boundary (`PS256` and `ES384`).

Production key requirements are documented for `AUTH_JWT_*`, each active `JWT_AUTH_APP_*`,
`JWT_AUTH_ORG_*`, `JWT_VISA_APP_*`, and `JWT_VISA_ORG_*` set, and the required
`OIDC_CLIENT_<NAMESPACE>_*` signers. Values must be matching unencrypted PKCS#8 RSA-3072-or-larger
keys; production `kid` values must be unique and identify the PS256 generation. Keys were not
provisioned. AWS KMS signing remains deferred.

The security review was checked against [RFC 7515](https://www.rfc-editor.org/rfc/rfc7515.html),
[RFC 7519](https://www.rfc-editor.org/rfc/rfc7519.html), and
[RFC 8725](https://www.rfc-editor.org/rfc/rfc8725.html). The algorithm/header agreement, explicit
typing, and mutually exclusive validation requirements match the implementation's fixed allowlist
and per-family validation. Tests cover algorithm confusion, weak keys, wrong token types/claims,
invalid signatures and key/JWKS failures.

## TDD and verification

- Original PS256 policy tests were Red at 31 runs, 53 assertions, 9 failures and 6 errors; after the
  key/JWK implementation they were Green at 31 runs, 70 assertions, no failures or errors. Those
  observations are retained in `K8M4` above.
- Current focused PS256 selection: 386 runs, 1,511 assertions, zero failures, errors or skips. It
  covered the JWT key/JWK/JWKS registry, access-token profiles, OIDC claims and Discovery, Jump RT
  services, client assertions, and ceremony token contracts.
- A broader selection including legacy integration expectations ran 409 tests and had 17 failures
  and 3 errors. The failures were in tests expecting retired `BASE`/`CORE`/`WARP`/`PALM` issuer
  namespaces, the removed `BASE_APP` client-assertion namespace, or sign-in routes that now return
  the intentional unavailable response. These paths are separate from the focused PS256 behavior; no
  assertion was weakened.
- Added `test/integration/op_browser_refresh_cookie_size_test.rb`: it issues browser refreshes
  through the APP and ORG public endpoints and checks that the production cookie name plus the
  returned PS256 access-cookie value stays at or below 4,096 bytes. The final focused run passed at
  2 runs, 6 assertions, zero failures/errors/skips. Its first draft read the raw `Set-Cookie`
  header, which Rails did not expose through that accessor; using the framework's parsed
  `response.cookies` made the test measure the actual cookie value. No product code changed for this
  check.
- `bin/rails zeitwerk:check`: passed.
- Scoped `bin/rubocop test/integration/op_browser_refresh_cookie_size_test.rb`: passed.
- `bin/rubocop`: 2,013 files, 61 offenses, 50 autocorrectable. The workflow fail-fast invocation
  also fails on four Layout offenses in the pre-existing modified
  `test/models/public_method_contract_values_test.rb`.
- ERB lint, both Brakeman invocations, frozen-string checks, i18n missing-key check, dependency
  audits, OpenAPI lint/verification, and JavaScript checks are recorded with current counts in
  `evidence/2026-11-13-ci-static-switch-V2K9.md`. In particular, `bun run check` still stops on four
  Playwright `Page` TS2322 errors; OpenAPI verification passes.
- Final full Rails run, including the new size test: 5,584 runs, 35,357 assertions, 103 failures,
  130 errors, 0 skips. The prior dirty-worktree full run was 5,582 / 35,352, 102 failures / 130
  errors. The only newly named failure was
  `Auth::App::SignUpCsrfFailureTest#test_a_telephone_sign-up_submission_without_a_token_is_refused_before_the_unavailable_response`;
  it passes alone (1 run, 2 assertions). This is an order-dependent failure in the later
  anonymous-flow work, not a PS256 cookie-test failure. Compared with the earlier coverage baseline
  (5,585 / 35,262, 102 failures / 145 errors), the dirty-tree suite is not fully green and the
  aggregate changes cannot all be attributed to this migration.

## Interoperability and remaining `ES384` references

Read-only GitHub search on the current default branches found:

- Governance at `f24fb7b49f0059ee66e932eb8a07bceac5b89cee` still signs first-party tokens with ES384
  in its keyring, JWK policy, Auth access, OIDC ID/logout and ceremony code. Cross-repository
  verification is therefore expected to fail until Governance migrates.
- Edge Jump at `0678dfb4027d3ff47e1a8731b9d6f0d4dd038cb0` still verifies and signs ES384/P-384 in
  `src/core/verify_jwt.ts`, `src/core/sign_outbound.ts`, `src/core/jump_jwks.ts`, and
  `docs/receiver-contract.md`. Access now requires PS256 for Jump returns. The deployed JWKS 503
  observation in `K8M4` was not rechecked live; live interoperability remains unverified.
- Sphere and Press returned no `ES384` code-search results; this does not establish their signing
  algorithms. Their local worktrees were unavailable and were not edited.

`rg -n 'ES384' app lib config docs adr openapi` reported 85 matching lines in 27 files. Remaining
references fall into these groups:

- External client assertions: `app/values/oidc_client_assertion_jwt.rb`, the external assertion path
  in `lib/jit_security_jwt_jwk.rb`, and its Discovery/runbook documentation. These remain
  dual-accepted until external RP owners migrate.
- DPoP client proofs: `app/lib/dpop_proof_verifier.rb` and `docs/architecture/dpop.md`; DPoP is an
  external proof protocol and was explicitly unchanged.
- The superseded Governance server-delivered revocation verifier is intentionally unchanged by this
  order and remains a follow-up.
- ChainSeal is a separate audit-signature format, not an Access JWT, so its ES384 implementation and
  runbook were left intact.
- The Edge Jump receiver still specifies ES384 as noted above.
- Superseded ADR/backlog text and documents explicitly marked historical (`docs/dds.md`,
  `docs/srs.md`, and `docs/vendor/identity/*`) retain old ES384 descriptions. The accepted
  Preference ADR and the current Discovery profile also retain Preference JWT wording from the
  retired Access behavior. Those Preference-document updates were assigned separately in the earlier
  database removal instruction and were not rewritten here.

The grep is therefore not literally limited to the unchanged external JWT protocols and historical
ADR text: it also includes the valid non-JWT ChainSeal format and the separately assigned stale
Preference documentation. No first-party Access JWT signer/verifier was found to retain ES384.
