# Client Assertions: PS256 Only

## Scope and revision

- Repository: `umaxica-apps-cosmos-access`, branch `feature`.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree already had 344 changed paths before this item, including the earlier Access PS256
  migration. This result therefore describes the dirty worktree, not a clean-HEAD comparison. No
  commit or push was made.
- No change was made under `.github/` or `config/credentials/`. The Governance revocation-command
  verifier, DPoP, DBSC, WebAuthn and Apple/Google/Entra verification remain outside this change.

## Changes

- `OidcClientAssertionJwt` now accepts only PS256. JWT decoding pins the verifier algorithm to
  Access's PS256 constant rather than taking an algorithm from the untrusted JWT header.
- Client assertion public keys use the same JWK policy as other Access issuer keysets: RSA, PS256,
  public material only, and a modulus of at least 3072 bits. Removed the separate ES384
  client-assertion parsing/import path and its conditional issuer-builder plumbing.
- Discovery advertises only PS256 for `token_endpoint_auth_signing_alg_values_supported`.
- Updated the current JWT ADR, OIDC Discovery profile, JWT rotation runbook, active cross-repository
  spec, and the relevant implementation plans with the owner’s 2026-11-13 decision. Older dated
  plan/archive text remains historical and is identified as superseded by the current records.

## TDD and verification

- Red: before the implementation change, the focused run reached 32 tests and showed the ES384
  client assertion authenticating and the external ES384 JWK parser failing to raise. The tool
  output did not include a completed run summary before implementation proceeded; these are the two
  observed failing cases.
- Green:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES bin/rails test test/services/oidc_client_assertion_jwt_test.rb test/services/oidc/discovery_document_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/ps256_key_policy_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_builder_configuration_errors_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/registry_validation_test.rb`
  — 67 runs, 286 assertions, 0 failures, 0 errors, 0 skips.
- Coverage includes a valid externally signed PS256 assertion; ES384, RS256 and PS384 refusal;
  refusal to load an ES384 verification key; exact 3071-bit rejection, 3072-bit acceptance and
  3073-bit acceptance; and PS256-only Discovery metadata. Exact-width JWK moduli exercise the size
  validator because OpenSSL key generation may return a neighboring modulus width.
- `bundle exec rubocop` over the 10 changed Ruby files — 10 files inspected, no offenses.
- `git diff --check` — passed.
- The first test invocation stopped before tests at the test-database safety check. The successful
  invocation unset the optional `POSTGRESQL_TEST_PREPARE_DATABASES` variable; no database was
  dropped. Database catalog output was filtered from the command output and is not recorded here.

## Remaining historical references

- `docs/backlog/2026-11-08-jwt-key-handling-after-cosmos-split.md` is marked superseded and retains
  historical migration language.
- Archived authentication plans retain their dated ES384 requirements. The active integrated-auth
  plan now has an amendment that supersedes its earlier ES384 observation and REQ-008 algorithm.
- The original out-of-scope paragraph in `specs/cosmos-cross-repository-connection/spec.md` remains
  as history, with the 2026-11-13 owner amendment explicitly superseding its client-assertion
  algorithm clause.

No key material was created or changed, no compatibility path remains for ES384 client assertions,
and no suppressions, exclusions, allow-lists or TODO entries were added.
