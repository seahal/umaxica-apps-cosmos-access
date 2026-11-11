# Credentials Exposed Through Public Git History: Investigation and Response (2026-11-11)

HEAD `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`, with substantial uncommitted changes (credentials
files changed by this response are uncommitted). No secret value appears in this record or was
printed during the work; decryption ran inside the Access development container, which printed only
entry names and yes/no comparisons. Follows
`docs/backlog/2026-11-10-credential-management-audit-followups.md`.

## Exposure

- `config/credentials/development.key` and `test.key` were committed in `fac157bb1` (2025-09-03) and
  removed in `2d3211c` (2025-10-02); the encrypted files of that time remain in history. Anyone with
  the history could decrypt them from 2025-09-03.
- All four Cosmos repositories (Access, Governance, Sphere, Press) are public on GitHub and carry
  this history. When the original single repository became public was not established.
- Also in history (names checked only): `es256_private.pem` (added 2025-08-04) and a tracked `.env`
  (about 2024-08 to 2025-09).

## Method

Historical keys and encrypted files from `2d3211c^` were decrypted in the container; each value was
compared with every current development and test credential value and every container environment
value, printing only names. The same comparison was run for every committed version of `.env`.

## Findings and response

| Exposed value                                                                                                                               | Still in use on 2026-11-11                                                             | Response                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Cloudflare Turnstile secret (Access `development-stealth` widget)                                                                           | yes (Access development)                                                               | secret rotated with immediate invalidation; new value written to Access development credentials; verified different from the exposed value                                                                                                                                           |
| AWS access key `AKIA…JQWF` (account `841162677945`, created 2025-05-02, last used 2026-03-19 15:30 JST, user with `AmazonSesSendingAccess`) | key present in all four repositories' test credentials; its secret also in development | entries removed from development and test credentials in all four repositories; the owner deleted the IAM user (and so its keys) on 2026-11-11. SES showed no sending activity. What the 2026-03-19 use was could not be determined (older than CloudTrail event history; no trail). |
| Resend API key                                                                                                                              | in all four repositories' development credentials, unused by code                      | Resend shows no API keys and no logs (already revoked); entries removed from all four repositories                                                                                                                                                                                   |
| Google OAuth client secret (client `991593585723-…`)                                                                                        | yes (Access development and test; copies in the other three)                           | new secret added and written to Access development; old secret disabled in Google Cloud on 2026-11-11; Access test set to a dummy; entries removed from Governance, Sphere and Press                                                                                                 |
| Google org OAuth client (not exposed)                                                                                                       | unused                                                                                 | entries removed from all four repositories                                                                                                                                                                                                                                           |
| Sign in with Apple private key, key ID, team ID                                                                                             | yes (Access development and test)                                                      | accepted risk (owner, 2026-11-11): membership lapsed, key probably cannot be revoked; kept in Access development only; removed from the other three; to be replaced before production (`docs/runbooks/cosmos-credential-value-rotation.md`)                                          |
| Twilio Account SID (`AC…c123`) and auth token                                                                                               | no                                                                                     | owner cannot sign in (MFA); low risk; `docs/backlog/2026-11-11-twilio-account-close.md`                                                                                                                                                                                              |
| Local development database password                                                                                                         | yes (local only)                                                                       | low risk; not yet changed                                                                                                                                                                                                                                                            |
| JWT private key, `secret_key_base`, Active Record encryption keys, OpenSearch, Redis URLs                                                   | no                                                                                     | no action                                                                                                                                                                                                                                                                            |

After each change: the changed entry verified, every other entry verified identical, and all four
applications booted (`bin/rails runner`). Temporary backups and plaintext files were deleted.

## Not done or not verified

- Git history was not rewritten and the repositories remain public (owner decision, 2026-11-11).
- `es256_private.pem` was not compared with any current key.
- Gitleaks' 247 historical candidates remain unclassified.
- Public disclosure: to be published on the News surface once it exists (Press
  `docs/backlog/2026-11-11-credential-exposure-disclosure.md`).
- Follow-ups: `docs/backlog/2026-11-11-aws-account-audit-trail-and-alerts.md`.

## Second exposure found on 2026-11-12: tracked development env file

`.env.container.devcontainer` is tracked in Git (first added 2026-10-19) in all four public Cosmos
repositories and holds 21 development secret values (Active Record encryption keys and salts for App
and Org, email and telephone HMAC keys, history keys, OTP verifier keys,
`ENFORCEMENT_*_IDENTIFIER_HMAC_KEY`, and the Flipper, Blazer and PgHero passwords). All 21 values in
the working tree equal those in HEAD, so they have been public since they were committed; the
2026-11-12 commit adds no new secret value. Owner decision (2026-11-12): commit as is; the
development container environment is about to be discarded; the values are replaced when the secrets
move to credentials (`docs/backlog/2026-11-10-secrets-from-credentials-only.md`), which also
requires rebuilding development databases encrypted with the old keys. Include this exposure in the
public disclosure.
