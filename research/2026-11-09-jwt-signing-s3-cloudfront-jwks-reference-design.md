# Reference design: KMS signing with S3 key history and CloudFront JWKS (2026-11-09)

Not adopted. Kept as a reference for the JWT signing redesign
(`docs/backlog/2026-11-08-jwt-key-handling-after-cosmos-split.md`). The accepted decision is
`adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md`; nothing below changes it. The design was
proposed in a ChatGPT discussion and summarized here in English.

## Proposed design

| Item                               | Proposal                                                     |
| ---------------------------------- | ------------------------------------------------------------ |
| Algorithm and key                  | PS256, RSA 3072 asymmetric key                               |
| Private key generation and storage | AWS KMS                                                      |
| JWT signing                        | KMS `Sign`                                                   |
| Public key retrieval               | KMS `GetPublicKey`                                           |
| Public key history                 | Amazon S3, as the source of truth                            |
| History protection                 | S3 Versioning, optionally Object Lock                        |
| JWKS publication                   | S3 behind CloudFront (Origin Access Control), private bucket |
| JWT issuance                       | Access (Rails)                                               |
| AWS authentication                 | EKS Pod Identity in production                               |
| Ruby library                       | Official `aws-sdk-kms`; existing JWT library kept            |

Relying parties (Governance, Press, Sphere) verify JWTs from the JWKS served by CloudFront and never
connect to KMS.

### Key history in S3

Asymmetric KMS keys do not rotate automatically, so each generation is a new KMS key. Before a key
is disabled or deleted, its public key is stored in S3 with:

- the public JWK of each generation;
- the mapping from `kid` to KMS key ARN;
- creation time, signing start and end, and JWKS inclusion and removal times;
- rotation history.

The Rails database holds no public key history. The public JWKS lists only the keys needed for
current verification, not every past key.

### Rotation

1. Create a new RSA 3072 KMS key.
2. Fetch its public key with `GetPublicKey`.
3. Assign a new `kid` and store the public JWK and key metadata in S3.
4. Publish old and new public keys in the JWKS.
5. Wait for JWKS caches to refresh.
6. Switch Access signing to the new key (a KMS alias may point at the current key, but each `kid`
   stays bound to the key that actually signed).
7. Keep the old public key until tokens signed with it and caches have expired.
8. Revoke signing on the old key and disable it if needed.
9. Remove the old public key from the JWKS; keep its S3 history.

Emergency switching is a separate procedure from normal rotation.

### Permission split

| Permission                       | Principal                                    |
| -------------------------------- | -------------------------------------------- |
| `kms:Sign`                       | Access signing workload                      |
| `kms:GetPublicKey`               | Key management and public key update process |
| KMS key creation and disabling   | Key administration principal                 |
| Writing public key history in S3 | Dedicated update process                     |
| Reading the JWKS                 | RPs through CloudFront                       |

JWKS tampering directly undermines JWT trust, so updating public keys is separated from Access's
normal runtime permissions.

### Stated goals

- No private key in Rails or Kubernetes Secrets.
- Key generation, storage and signing delegated to KMS.
- Public keys and their history kept on the AWS side, not lost with the Rails database.
- RPs worldwide verify JWTs without KMS.
- Rotation and emergency switching as standard operations.

### Open items listed by the proposal

Automating public key updates (for example with Lambda); S3 metadata format and integrity checks;
JWKS URL and Discovery settings; CloudFront cache control; rotation permissions and approval;
separating production and development keys; emergency switching and RP cache invalidation; the
OpenID Connect RS256 requirement; handling ES384 tokens issued before migration.

## Points to weigh before adopting any part

These notes compare the proposal with the current backlog entry; they are observations, not
decisions.

- **JWKS location.** The backlog entry builds the JWKS inside Access at boot from `GetPublicKey`.
  This proposal serves it from S3 and CloudFront instead, separating publication from Access's
  runtime. Discovery's `jwks_uri` may point to any HTTPS URL, so either is standards-compatible.
- **Key ledger location.** The backlog entry leaves the ledger's location open (code, configuration
  or database); this proposal makes S3 the source of truth and excludes the Rails database.
- **Emergency removal.** With CloudFront in front of the JWKS, removing a compromised key also needs
  a CloudFront invalidation, in addition to RP cache lifetimes.
- **Extra components.** S3, CloudFront, Object Lock and an update process (possibly Lambda) each add
  permissions to secure and failure modes to handle.
