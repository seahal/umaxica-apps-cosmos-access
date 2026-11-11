# JWT key handling must be redesigned for the Cosmos split

Status: Deferred; recorded at the owner's request on 2026-11-08. The owner gives priority to moving
routes and code into the four repositories and keeps the existing key handling until then. This
entry authorizes no change to credentials, keys, the local keyset installer, the JWT registry or
client verification code. Work starts after the Cosmos repository split is complete.

Decision record: `adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md` (accepted 2026-11-09): PS256
with RSA 3072-bit keys, OP signing through AWS KMS, EKS Pod Identity as the first candidate.

Owner: Access. Access holds the OP signing keys, the OIDC client registrations and the client
assertion verification, so the redesign is led here; Governance, Press and Sphere follow for their
own RP keys.

## Background

- In development and test, `config/initializers/jwt.rb` calls
  `JitSecurityJwtLocalKeysetInstaller.install!` at boot. It reuses keys saved in
  `tmp/local_jwt_keysets.json` and generates new key pairs when a keyset is missing or the file is
  absent or unreadable. JWT signing keys were removed from development and test credentials on
  2026-11-08 (`docs/backlog/2026-11-08-github-actions-master-key-rotation.md`), so this file is the
  only local source.
- The installer, `JitSecurityJwtRegistry` (`private_key_required?`) and `OidcClientRegistry` assume
  one application that holds the OP keys and every RP's private client key.
- Production reads keys through `Rails.app.creds` (`lib/jit_security_jwt_key_source.rb`).
- `adr/runtime-secret-isolation-deferred.md` (amendment 2026-10-23) sets AWS KMS as the direction
  for OP signing keys.
- A proposed redesign is recorded in `adr/cosmos-signing-key-management.md` (Proposed, on hold).

## Problems to solve

1. **Silent key generation.** Starting Rails can create new private keys; tokens signed with the old
   keys then fail verification without an obvious cause.
2. **Unneeded private keys in Access.** Without registry changes, Access still requires and holds RP
   private client keys after it stops serving RPs. Removing RP routes from Access does not remove
   these keys.
3. **Client assertions across repositories.** Each repository generates its own keys in its own
   `tmp/`. When an RP in another repository (first Governance Base App) authenticates to the Access
   OP with `private_key_jwt`, the OP has no matching public key. This blocks the second work unit of
   `adr/cosmos-base-surface-decomposition.md` (First Step: Hard Reset), so this entry must be
   resolved before Governance's RP authenticates against Access.

   **Decided 2026-11-09 (owner): each RP publishes its own JWKS, and Access fetches it.** The
   OP-to-RP direction already works this way: the local-cell path (`RpRequestAuthenticator`) fetches
   Visa's public JWKS through `OidcOpJwksClient`. Only the RP-to-OP direction is missing, because
   Access looks up RP keys in its own `JitSecurityJwtRegistry`. The resolution:

   - Each RP serves its public client keys at `/.well-known/jwks.json` on its public host, starting
     with Governance Base App at `https://www.umaxica.app/.well-known/jwks.json`.
   - Each Access client registration names that URL as `jwks_uri`. Access verifies `private_key_jwt`
     client assertions against keys fetched from it and no longer holds RP private keys (problem 2).
   - Development uses the same public hostnames, through each repository's Cloudflare Tunnel. Where
     Cloudflare Access blocks these server-to-server fetches (both the RP JWKS paths and Visa's
     Discovery and JWKS paths), exempt the paths with a Bypass policy, or authenticate the fetch
     with a Cloudflare Access service token. The JWKS documents hold public keys only.
   - Keys must stay stable across restarts (problem 1); an RP key that changes on every boot breaks
     Access's cached copy.
   - No private key is copied between repositories, so the shared development key transition below
     is no longer needed for client assertions.
   - Decided 2026-11-10 (`adr/cosmos-development-on-vms-with-local-tls.md`,
     `adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md` amendment): RP client keys follow the OP's
     KMS design. Production signs through KMS and builds the RP JWKS from `GetPublicKey`;
     development and test stub KMS with a key kept in credentials, created by a person, and a
     missing key stops boot. `OutboundHttp::LocalBackChannel` is removed, so these fetches always
     use the public HTTPS URL.
   - Decided 2026-11-10: one key set and one JWKS per repository, shared by all its clients and also
     used for its non-OIDC JWTs; tokens must carry and verifiers must check `typ`, `iss`, `aud` and
     purpose claims (`adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md`).

4. **Production key storage.** KMS, CloudHSM, Secrets Manager, Parameter Store and EKS secret
   options are under research by the owner; Sphere regions may not have AWS or KMS.

5. **Signing algorithm.** Decided: PS256 with RSA 3072-bit keys
   (`adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md`).

## Until resolved

- Keep the existing installer, registry and client verification code unchanged.
- Before starting Rails, confirm without printing values that the keys the installer requires can be
  loaded from the saved store; if any is missing, do not start.
- Never print key material in logs, documents, test output or reports.

## Implementation proposal

Proposal only; each step needs its own approval. Line references are from
`umaxica-apps-cosmos-access` at `281a9e5c5` and were not re-verified.

### Current code to replace

- Algorithm constants: `AuthenticationToken::JWT_ALGORITHM` and `SecurityJwtOidcIdTokenCodec` are
  `"ES384"`; access and preference token codecs follow `SecurityJwtRfc9068AccessTokenProfile`. ES384
  also appears in the OP verifiers (`app/adapters/oidc_op_*_verifier.rb`), ceremony contracts
  (`app/values/identity_*_ceremony_contract.rb`), `OidcStateJwt`, the Jump RT codec,
  `JumpRtReturnVerifier`, `lib/jit_security_jwt_keyring.rb`, `lib/jit_security_jwt_jwk.rb` and
  `lib/chain_seal.rb`. Each is classified as OP-signed, RP-signed or externally signed before
  changing it; `app/lib/dpop_proof_verifier.rb` verifies client-generated DPoP proofs and is not an
  OP signing site.
- Discovery: both algorithm fields in `app/values/oidc_discovery_document.rb` read one constant;
  split them.
- Keys: `JitSecurityJwtLocalKeysetInstaller` (local generation), `JitSecurityJwtRegistry`
  (`private_key_required?`), `JitSecurityJwtKeySource` (`Rails.app.creds`) and `OidcClientRegistry`
  (client key checks).
- Libraries already present: `jwt` 3.3.0, `aws-sdk-kms` 1.138.0, `openssl` 4.0.2.

### Proposed design

1. **One KMS signer for every environment.** Codecs ask the signer for a JWS signature over the
   signing input and never touch private keys. Production, development and test all run the same KMS
   signer code path; development and test differ only in the `Aws::KMS::Client` they use (see
   "Development and test without AWS"). There is no separate local signer.
2. **KMS signer.** Rails builds the signing input `BASE64URL(header).BASE64URL(payload)`, computes
   its SHA-256 digest, and calls `Sign` with `message_type: "DIGEST"` and `RSASSA_PSS_SHA_256`. With
   `DIGEST`, KMS does not hash again and the 4096-byte `RAW` message limit does not apply. KMS uses
   MGF1 with SHA-256 and a 32-byte salt; the RSA-PSS signature goes into the JWS unchanged (RFC
   7518). Test the result against `jwt` 3.3.0 verification. Errors, timeouts and throttling fail
   token issuance; no retry hides a failure beyond a bounded, logged retry. The AWS Region and key
   identifiers come from required configuration (`ENV.fetch` or `Rails.app.creds.require`), never
   from a code default.
3. **JWKS from KMS public keys.** At boot, fetch each active key's public key (`GetPublicKey`),
   refuse to start unless the key reports `KeySpec` `RSA_3072`, `KeyUsage` `SIGN_VERIFY` and
   `RSASSA_PSS_SHA_256` among its signing algorithms, convert it with `OpenSSL::PKey` to an RSA JWK
   (`kty`, `kid`, `use: sig`, `alg: PS256`, `n`, `e`), and build the JWKS; verification stays local.
   This changes the rule in `docs/runbooks/jwt-key-rotation.md` that request handlers make no KMS or
   network calls: issuance calls `Sign`; JWKS rendering and verification still do not call KMS.
   Update the runbook.
4. **Discovery and registrations.** Advertise PS256 only in `id_token_signing_alg_values_supported`;
   manage `token_endpoint_auth_signing_alg_values_supported` separately for accepted client
   assertion algorithms; set `id_token_signed_response_alg` to `PS256` in every client registration.
5. **Access stops requiring RP private keys.** Remove the RP private key requirement from the
   registry and client verification in Access; Access keeps only what it needs to verify client
   assertions.

### Development and test without AWS

Developers never receive AWS credentials. `aws-sdk-ruby` provides `stub_responses` for this:
`Aws::KMS::Client.new(stub_responses: true)` makes no network call, needs no credentials, still
validates request parameters against the KMS API model, and returns responses the application
defines.

- Stub `sign` with a procedure that signs the received SHA-256 digest with a development or test RSA
  3072 key using RSASSA-PSS (SHA-256, MGF1 with SHA-256, 32-byte salt), and stub `get_public_key`
  with that key's public key, `KeySpec` `RSA_3072`, `KeyUsage` `SIGN_VERIFY` and
  `RSASSA_PSS_SHA_256`. The resulting signatures are real PS256 signatures that `jwt` verifies, so
  the production signer code, `DIGEST` handling and JWKS construction run locally.
- `stub_responses` is enabled only in development and test, and only where the KMS client is built.
  Never set it globally through `Aws.config`, so other AWS clients are unaffected. If production
  configuration enables it, the application refuses to start.
- The development and test RSA keys live in that environment's credentials, are created deliberately
  by a person, and are distinct from production keys. A missing key stops boot.
- The development and test stub keys may be shared among the four repositories as a bounded
  transition, so OP and RP keys match before JWKS fetching works between repositories. Conditions:
  development and test only, never production (production keys stay inside KMS and cannot be
  shared); each shared key is marked as non-production in its `kid` (for example by including the
  Rails environment, as the current installer does) so it cannot be mistaken for a production key or
  appear in a production JWKS; key material moves only between encrypted credentials, never through
  chat or git. Exit condition: RPs fetch the OP's JWKS and the OP fetches each RP's `jwks_uri`
  (`adr/cosmos-signing-key-management.md`, decision 8), so each repository holds only its own
  private keys. While shared, development cannot detect an RP signing with the wrong key; that is
  tested when sharing ends.
- Stubs cannot show IAM permissions, KMS throttling or outages, or CloudTrail records. These are
  verified only against real KMS in a staging environment in a separate AWS account that developers
  cannot reach.
- Fallback if stubbing proves insufficient: a KMS emulator such as fakecloud, whose `kms` support is
  listed but not configured or verified for `RSA_3072` with `RSASSA_PSS_SHA_256`
  (`docs/operations/local-aws-fakecloud.md`).

### Gem policy

- AWS KMS is reached only through the official `aws-sdk-kms` gem (already in `Gemfile.lock`), with
  `aws-sdk-core` as its dependency. Unofficial KMS-and-JWT integration gems are not used.
- The existing `jwt` gem stays for JWT encoding, decoding and claim validation; only the signing
  step is delegated to the KMS signer. Writing JWT handling by hand would move algorithm pinning and
  `iss`, `aud` and `exp` validation into code the project maintains. Whether `jwt` 3.3.0 accepts a
  custom signing algorithm object for this, or the signer must assemble the compact JWS itself
  around `jwt` for verification only, is confirmed at implementation.
- `aws-sdk-rails` is not needed. It can read AWS credentials from Rails credentials, which would
  compete with EKS Pod Identity in the credential chain; signing-capable AWS credentials must not be
  in Rails credentials (`adr/runtime-secret-isolation-deferred.md`).

### Key ledger

Reference (not adopted): `research/2026-11-09-jwt-signing-s3-cloudfront-jwks-reference-design.md`
proposes S3 as the source of truth for public key history and serving the JWKS from S3 through
CloudFront.

Asymmetric KMS keys do not rotate automatically. Access keeps a ledger of key generations; each
entry records `kid`, KMS key ARN, public JWK, signing start, signing end and verification end.
Rotation uses it: add the new public key to JWKS first, switch issuance to the new key, and remove
the old public key only after the longest-lived token signed with it and every JWKS cache have
expired. Whether the ledger lives in code, configuration or a database is decided at implementation.

### EKS integration (to confirm at implementation)

- An Access-only ServiceAccount associated with the signing IAM role through EKS Pod Identity; EKS
  Pod Identity Agent installed; AWS SDK version that supports Pod Identity credentials.
- IAM policy: `kms:Sign` and `kms:GetPublicKey` on the designated key ARNs only, with a
  `kms:SigningAlgorithm` condition for `RSASSA_PSS_SHA_256`. The KMS key policy matches the IAM
  policy and grants nothing to RP roles.
- Block pod access to node credentials (restrict IMDS), so pods cannot fall back to the node role.
- KMS reached through a VPC interface endpoint; CloudTrail records every `Sign` call; alarms on
  unexpected callers or volume.
- Behaviour during KMS outages: issuance fails visibly; no fallback key.

### Threats and countermeasures for KMS signing

**What KMS does and does not protect.** Compared with a private key held in the Access Rails process
(today), KMS is equal or better on every point; it is not worse on any.

| When Access Rails is compromised           | Private key in Rails (today)                                 | Signing through KMS                                             |
| ------------------------------------------ | ------------------------------------------------------------ | --------------------------------------------------------------- |
| Forged tokens while the attacker is inside | Possible                                                     | Possible (same)                                                 |
| Pre-signed future-dated tokens             | Possible                                                     | Possible (same)                                                 |
| Signing after the attacker is evicted      | Possible indefinitely, from anywhere, once the key is copied | Not possible once the permission is revoked                     |
| How long pre-signed tokens can keep coming | Until the key is rotated                                     | Only those made while inside                                    |
| Knowing how much was signed                | Unknown; local signing leaves no record                      | Every `Sign` call is in CloudTrail                              |
| Response after detection                   | Key rotation is always required                              | Revoking the permission may suffice if the scope can be bounded |

KMS does not stop forged tokens while an attacker controls Access; assuming it does is the dangerous
misreading. What KMS adds is that the key cannot be stolen, the damage is limited to the period of
compromise, signing is recorded, and it can be stopped at once. It limits damage after other
defences fail. The defences against forgery during a compromise are elsewhere: reducing Access's
attack surface (the split leaves Access with Visa and Auth only), a narrow signing component that
sets times itself (threat 1 below), and checking access tokens against server state (threat 2
below). The owner judges the benefit worth the cost and effort.

With KMS, an attacker targets the permission to sign rather than the private key. A JWT signed
through stolen `kms:Sign` access is cryptographically genuine. These are design threats, not
confirmed vulnerabilities in the current code.

1. **Pre-signed future tokens.** `iat`, `nbf` and `exp` are part of the signed content, not a KMS
   timestamp. While an attacker holds `kms:Sign`, they can sign tokens valid hours later; RP time
   checks cannot reject them, because by then `iat` looks current. Waiting out the token lifetime
   after revoking the permission is therefore not proof of safety. The only structural defence is
   that the component holding `kms:Sign` sets `iat` to the current time and `exp` within the allowed
   lifetime itself, and signs only fixed token shapes. If the Access Rails process holds `kms:Sign`
   directly, a compromised process can sign anything. Whether to move signing into a narrow signing
   component is an open design decision; a generic "sign these bytes" service would not help.
2. **Unequal impact by token type.** A forged ID token is hard to use in the authorization code
   flow, because RPs receive ID tokens from the token endpoint, not from the browser. A forged
   access token is usable directly as a bearer token; DPoP does not help when the attacker also
   forges `cnf`. Checking access tokens against server state (`jti`, `sid`; compare
   `RpRequestAuthenticator`) rejects forged tokens that were never issued, at the cost of part of
   stateless verification.
3. **Separate keys per token type.** Separate KMS keys for ID tokens and access tokens prevent token
   confusion (RFC 8725). They isolate a compromise only if the signing permissions are also held by
   different workloads.
4. **Narrow permissions.** Limit the Pod Identity trust to the cluster, namespace and
   ServiceAccount; keep `kms:Sign` separate from key administration and policy changes; allow
   production signing only through the VPC endpoint (`aws:sourceVpce`); use separate keys for
   development, never production signing permission.
5. **Detection.** Reconcile CloudTrail `Sign` events with Rails issuance audit records (token type,
   `kid`, client ID, time, result, internal request ID; never the token itself or sensitive claims).
   More `Sign` calls than recorded issuances indicates signing outside Rails.
6. **Incident response.** When `kms:Sign` may have been misused:
   - if the period and the forged tokens can be bounded and reliably rejected, the key may stay;
   - otherwise rotate: stop the permission, create a new key, publish the new `kid`, switch
     issuance, stop trusting the old key at every RP immediately (remove it from JWKS and add it to
     the revoked kids, such as the existing `AUTH_JWT_REVOKED_KIDS`), and revoke sessions and grants
     obtained with forged tokens. Legitimate users must sign in again.
   - Disabling the KMS key stops new signatures only; the published public key keeps verifying old
     tokens until RPs stop trusting it.
   - Keep RP JWKS cache lifetimes short enough that an emergency removal takes effect quickly.

### Migration order (after the split)

1. Resolve RP client keys across repositories (problem 3), so Governance Base App can authenticate
   to Access with `private_key_jwt`.
2. Introduce the signer interface with the local-credentials implementation, still ES384, and remove
   silent key generation. Behaviour is unchanged apart from fail-fast boot.
3. Add PS256 keys alongside ES384: publish both public keys in JWKS by `kid`, keep verifying ES384.
4. Switch issuance to PS256 for one token type at a time (ID token, access token, then the others),
   checking cookie and header sizes for each.
5. Switch Discovery and client registrations to PS256 once every RP verifies PS256.
6. Wait for the longest-lived ES384 token to expire, then remove ES384 keys and verification.
7. In production, create the KMS keys and IAM wiring, switch the signer to KMS, and verify JWKS and
   issuance. Key creation and AWS changes need the owner's approval.

### Open points

- Key per purpose (ID token, access token, other JWTs) or a shared key.
- RP `private_key_jwt` key storage, including Sphere regions without AWS
  (`adr/cosmos-signing-key-management.md`, on hold).
- Development and test signing material and its runbook.
- Rotation, revocation and emergency key switch procedures.
