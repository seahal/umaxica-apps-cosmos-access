# Credential Management Audit Follow-ups

Status: Backlog; recorded at the owner's request on 2026-11-10. This entry records findings and
proposed closure criteria, not authorization to rotate credentials, rewrite Git history, change
external services, or destroy data.

## Audit scope and evidence

Read-only inspection covered the current worktree, Git tracking and available history, Rails
credential key files, container build exclusions, CI secret scanning, and provisioning guidance. The
inspected HEAD was `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`; substantial existing uncommitted
changes affected the inspected files. Findings describe that worktree, not HEAD alone. No credential
values are retained here. No provider authentication or production change was attempted.

## Priority 1: historical Rails keys and retirement of credential values

- `config/credentials/development.key` and `config/credentials/test.key` were present in commit
  `fac157bb13cae19b5124b02caaa8a4df2dd5fe19` (2025-09-03), and removed in
  `2d3211c5391480f6fbeebe7df9a74b43eb8dfe1c` (2025-10-02). Removal leaves earlier copies retrievable
  from history.
- Both historical files have the expected 32-character hexadecimal key format. Neither matches its
  current local counterpart. The audit did not decrypt the historical payloads or establish whether
  their contained credentials remain valid.
- Replacing an encryption key does not revoke provider passwords, signing keys, or other values
  exposed by an earlier decryptable payload.

Coordinate with
[the existing master-key and credential-value rotation backlog](2026-11-08-github-actions-master-key-rotation.md)
and [the credentials-only decision](2026-11-10-secrets-from-credentials-only.md). Those entries
record the existing cross-repository schedule; this audit does not supersede it. The rotation
backlog also records shared historical values and pending CI key provisioning; those statements were
not independently verified against other repositories or GitHub in this audit.

Closure requires a read-only inventory of affected credential entry names and consumers, followed by
authorized retirement or rotation of the underlying values and verification of affected callers.
Record completion without values. Any history rewrite or shared-data change needs its own scoped
approval and recovery plan. History cleanup alone does not retire credentials.

## Priority 2: container build exclusions

`Containerfile` uses `COPY . .` in `production-build` and copies that application directory into the
production stage. Both `.dockerignore` and `.containerignore` exclude `.env*`, `.secrets/`,
`config/master.key`, and `config/credentials/*.key`, but neither excludes `.aws/`. Git's ignore rule
for `.aws` does not protect a filesystem build context.

No `.aws/credentials` or `.aws/config` file was present during inspection. This is a potential image
inclusion path, not evidence of a published image containing AWS credentials.

Closure requires synchronized exclusions for local credential directories in both build ignore
files, and a disposable build-context or image inspection proving that synthetic credential markers
are absent. Review the actual deployment build context and published image separately; do not use
real secrets as verification fixtures.

## Priority 3: provisioning instructions disclose decrypted values

`docs/operations/development-credential-provisioning.md` describes verification without displaying
secrets, but recommends `bin/rails credentials:show --environment development` and the equivalent
test command. These commands display decrypted credential contents.

Replace these instructions with a check that reports only decryption success or failure. Check
adjacent guidance for terminal, CI, and diagnostic output exposure. Closure requires confirming that
the documented check does not emit credential values on either success or failure.

## Existing protections and verification limits

- Current local development/test key files and `.env` are outside Git tracking and have mode `0600`.
  `.env` contains database password candidates; no attempt was made to validate them.
- Gitleaks directory scans of `app/`, `lib/`, `config/`, and `src/` reported no findings. This does
  not establish the safety of encrypted credential contents or every local file.
- The CI workflow defines Gitleaks scanning with full checkout history and failure on detection.
  Actual CI execution, branch protection, and GitHub secret configuration were not inspected.
- A Gitleaks scan of available Git history reported 247 candidates. They include test and research
  material and have not all been classified; the count is not a count of confirmed leaked secrets.
  The initial attempt failed because Git invoked the Rails credentials text-conversion helper. A
  retry used a process-local Git configuration override to read encrypted blobs as ciphertext; it
  completed without the prior Git error. No repository Git configuration was changed.
- Production IAM permissions, credential validity and revocation, public registry images, remote
  repository visibility, provider access logs, and actual exfiltration remain unverified.

Do not infer that no leak occurred from an empty current-source scan. Completion requires resolving
the historical credential exposure and checking the deployed artifacts and provider state within a
separately authorized operational scope.
