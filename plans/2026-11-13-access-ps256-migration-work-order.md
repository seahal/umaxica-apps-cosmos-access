Task (umaxica-apps-cosmos-access): migrate every JWT that Access signs or that Jump signs for Access
from ES384 to PS256, completely, with no dual-algorithm period. No commit. Never print secrets, key
material or environment values. Never edit config/credentials/*.yml.enc. Do not deploy, do not
change Cloudflare and do not edit other repositories (read them for contracts only).

This order comes before `plans/2026-11-13-jump-front-channel-handoff-work-order.md`.

## Decision

`adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md` (Accepted 2026-11-09) chose PS256. Owner,
2026-11-13: Access migrates now and completely; the ADR's "accept both, then switch, then remove"
sequence and "implementation starts after the split" are replaced for Access by a single cut-over,
because nothing is launched and no unexpired ES384 token needs to survive
(`generic/no-compatibility-layer.mdc`). Amend the ADR's Status with this in the same change. Signing
through AWS KMS stays deferred: keys are still loaded the way they are today.

Observed 2026-11-13: ES384 is fixed in `lib/jit_security_jwt_keyring.rb`,
`lib/jit_security_jwt_jwk.rb` (`P-384`), `app/values/security_jwt_jump_rt_token_codec.rb`,
`app/values/jump_rt_return_verifier.rb`, `app/values/security_jwt_oidc_id_token_codec.rb`,
`app/values/security_jwt_rfc9068_access_token_profile.rb`,
`app/controllers/concerns/authentication_token.rb`, the identity ceremony contracts
(`identity_step_up`, `identity_passkey`, `identity_social`) and
`app/adapters/governance_revocation_command_verifier.rb`. The Jump gateway's key is already PS256
(RSA 3072).

## Scope

In scope (first-party JWTs): every token Access issues (Jump `rt`, ID tokens, RFC 9068 access
tokens, logout tokens, browser/auth access JWTs, ceremony contract tokens and any other family found
by search), verification of those tokens inside Access, verification of Jump return tokens, Access's
published JWKS, and Discovery metadata (`id_token_signing_alg_values_supported` and related
`*_signing_alg_values_supported`), OpenAPI documents, docs and ADR text that say ES384.

Unchanged (other parties' algorithms, not ours to choose): DPoP proofs from clients
(`dpop_proof_verifier.rb`), DBSC (`dbsc_proof_verifier.rb`), WebAuthn, and Apple, Google and Entra
ID tokens (RS256). Owner update, 2026-11-13: Governance, Sphere and Press now sign `private_key_jwt`
assertions with PS256, so Access accepts PS256 only and advertises PS256 only for client assertions.
This supersedes the earlier conditional client-assertion follow-up in this work order. Do not edit
the other repositories as part of this Access task.

`app/adapters/governance_revocation_command_verifier.rb` and its callers belong to the superseded
server-to-server design; do not migrate them. Leave them untouched and report them (removal is
decided in the handoff order).

## Required behaviour

1. One algorithm: PS256 with RSA keys of 3072 bits or more. ES384, RS256, PS384, `none` and HMAC are
   refused for first-party tokens. No fallback, no per-`kid` algorithm choice, no feature flag.
2. A verifier accepts a key only when its JWK is `kty` RSA, `alg` PS256, `use` sig, public members
   only; the token header `alg` must be PS256. Below-floor modulus is refused (test 2048 as the
   nearest practical value below and say so; 3072 and 4096 accepted).
3. Every other check keeps its order and strictness (`typ`, `iss`, `aud`, expiry, `jti` consumption,
   return-target policy, `kid` format and duplicate refusal, JWKS cache and refetch, fail closed
   when no valid key).
4. Because one key signs several token kinds, each family keeps its own `typ` and purpose checks.
5. Missing or wrong-type key configuration fails at boot with the variable or credential **name**
   only (`generic/fail-fast.mdc`); an EC key where an RSA key is required is a configuration error,
   not a fallback.
6. No token, key or URL value in logs.

## Key material (stop point)

PS256 needs RSA private keys where EC keys are configured today. You must not create or store real
keys and must not edit credentials. Do this instead:

- development and test: use the existing local/throwaway keyset mechanism
  (`JitSecurityJwtLocalKeysetInstaller` or whatever the tree has) and make it generate RSA 3072;
  tests generate their own keys.
- for any environment whose key comes from credentials or ENV: report the exact names that must now
  hold an RSA 3072 PKCS#8 key and the `kid` convention. The owner provisions them.

## Tests (Red first)

Per token family: issue and verify with PS256; ES384-signed token refused; header `alg` mismatch
refused; RS256 and PS384 on the RSA key refused; undersized key refused; tampered signature;
expired; wrong `aud`; wrong `typ`; replayed `jti` where the family consumes it. JWKS endpoint
publishes only RSA PS256 public keys. Discovery advertises PS256. Remove tests that only assert
ES384 behaviour; update fixtures. No test-only branches in production code.

## Coordination facts to report (do not fix here)

- RPs: Governance, Sphere and Press verify Access's ID and access tokens and logout tokens; after
  this change they must verify PS256. List the files in each that fix ES384 (read-only) so the owner
  can issue follow-up orders. Until then cross-repository sign-in is expected to fail; say so.
- Jump: the gateway must verify the PS256 `rt` Access now issues. Read `umaxica-apps-edge-jump`
  (`docs/receiver-contract.md`, `docs/protocol.md`, sources) and state whether the code there
  already does; the PS256 gateway code may exist only on the other machine.
- Live verification is impossible while the deployed Jump fails closed (JWKS 503); verify by tests
  and add the live check to the remaining list. Cross-repository tests belong in
  `umaxica-qa-test-integration`.

## Checks and report

bin/rails zeitwerk:check, bin/rubocop, bundle exec erb_lint --lint-all, bin/brakeman --quiet
--no-pager --exit-on-warn --exit-on-error, bun run check (OpenAPI), the affected test files, then
bin/rails test (separate pre-existing failures from the 2026-11-12 baseline).
`grep -rn ES384 app lib config docs adr openapi` must show only the unchanged external-protocol
items and historical ADR text; list what remains and why. Record in
evidence/YYYY-MM-DD-access-ps256-migration-XXXX.md (full `git rev-parse HEAD`; uncommitted changes
affected results): families migrated, files and reasons, key names the owner must provision, test
results, coordination facts, unverified items, and confirmation that config/credentials files are
unchanged.
