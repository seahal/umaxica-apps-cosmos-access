# AWS Emulator Replaces FakeCloud for Development and Staging

Accepted: 2026-11-12

Supersedes `adr/fakecloud-podman-staging-environment.md`.

## Context

`adr/fakecloud-podman-staging-environment.md` made FakeCloud (`ghcr.io/faiscadev/fakecloud`) the
AWS emulator for local development and for a Podman-hosted staging environment provisioned with
Terraform. Two things have changed since.

First, Access no longer uses object storage. The Shrine integration and
`lib/object_storage_shrine_configuration.rb` are gone, so the `DEPLOYMENT_TIER` storage switch and
the `OBJECT_STORAGE_*` namespace that the earlier ADR's decisions 5 and 6 protected have no
consumer in this repository. FakeCloud's remaining job is to be a target that the Terraform AWS
provider can apply against (`terraform/environments/{development,staging-development}`).

Second, AWS made AWS Emulator generally available on 2026-11-11: an open-source local emulator
published by AWS, generated from the AWS API models. FakeCloud is a third-party project that
publishes only `latest`, `main` and `sha-<commit>` image tags, so each digest bump may carry an
unannounced breaking change.

AWS Emulator differs from FakeCloud in ways that change how it is wired. These properties are taken
from the AWS Emulator User Guide (`docs.aws.amazon.com/emulator/latest/userguide/`), read on
2026-11-12, and have not yet been observed in this repository:

- No prebuilt container image is published. The documented container path builds an image from
  Amazon Linux 2023 and the emulator RPM.
- It serves HTTPS on port 9297 with a certificate it generates at each start.
- It requires SigV4 signatures by default. At each start it generates a new access key pair and
  writes it, an AWS `config` file and `ca.pem` to `~/.aws/emulator/<port>/`. It rejects requests
  signed with any other key, including real AWS keys. `--auth off` disables this check.
- All state is held in memory. There is no persistence option and no reset route; a restart
  empties it.
- It sends usage telemetry to AWS by default. `EMULATOR_TELEMETRY=off` or `--telemetry off`
  disables it.
- It does not evaluate IAM or resource policies, emulates a single account (`000000000000`) and a
  single Region per process, and returns HTTP 501 for operations it does not implement.
- S3 is path-style only. S3 Control requests cannot reach it.
- AWS positions it for development and testing, not production.

## Decision

1. **AWS Emulator replaces FakeCloud in development and staging.** The `fakecloud` Compose
   service, its `fakecloud-data` volume and every FakeCloud-specific endpoint, credential and
   health probe are removed, not kept beside the new service. Staging runs the same emulator image
   as local development, on Podman. No AWS account, real AWS credential or real AWS endpoint takes
   part in staging's emulated services. The exceptions in decisions 9 and 10 still apply.

2. **The image is built in this repository and pinned.** A Containerfile installs the emulator RPM
   on an Amazon Linux 2023 base image that is pinned by digest. The RPM is fetched by explicit
   version, not through the `LTS/latest` path, and is verified against a recorded SHA-256 before
   installation. Upgrading the emulator is a reviewed change to that version and checksum. The
   container runs as a non-root user.

3. **Authentication stays on.** The emulator runs with its default SigV4 checking; `--auth off` is
   not used. The per-run keys and `ca.pem` are shared with callers through a mounted
   `~/.aws/emulator` directory. Callers must use the emulator's keys explicitly, so that real
   credentials in the ambient environment never take precedence. The emulator rejecting any other
   key is the backstop, not the primary safeguard.

   This replaces the earlier decision that emulator credentials are visibly fake literals
   (`test` / `test`). Literals no longer work, because the emulator accepts only the keys it
   generated. The safeguard moves from "a real key is visible on sight" to "a real key cannot
   authenticate against the emulator, and no real-AWS endpoint is configured".

4. **Emulator state is disposable.** The loss of persistence is accepted. Development and staging
   Terraform state for emulated resources is treated as ephemeral: after an emulator restart the
   state is discarded and the environment is re-applied from scratch. Nothing that must survive a
   restart may live only in the emulator. FakeCloud's persistent mode and the
   `down` / `down -v` distinction it provided are not reproduced.

5. **Telemetry is off.** Every emulator process this repository starts sets
   `EMULATOR_TELEMETRY=off`. This keeps the outbound behaviour of development and staging hosts
   within `adr/cosmos-outbound-network-access-policy.md` without an AWS telemetry exception.

6. **Publication stays loopback-only.** Inside the container the emulator binds `0.0.0.0` so that
   the port can be forwarded. The host publication is `127.0.0.1:9297` only, in line with
   `docs/operations/development-host-port-exposure.md`. The emulator is not a datastore for
   port-exposure purposes. No Compose service mounts a Docker or Podman socket.

7. **Terraform remains the provisioning tool, and the module / environment split is unchanged.**
   `terraform/modules/` names no endpoint, credential or bucket literal. Every emulator-specific
   value (HTTPS endpoint, CA bundle, credential source and path-style S3) lives in
   `terraform/environments/<env>/`. Staging keeps a bucket namespace distinct from local
   development.

8. **The unit of staging deployment is the OCI container run by Podman, with no host-OS
   assumption.** Kubernetes is not adopted and not foreclosed. This carries forward decision 9 of
   the superseded ADR unchanged.

9. **The relational database, Valkey and observability stay outside the emulator.** Staging's
   PostgreSQL backend remains deferred, as recorded in `adr/staging-aurora-postgresql-topology.md`.
   An emulated RDS API without a real engine behind it does not exercise what that ADR needs.
   Valkey stays a plain container. Observability stays on Alloy per
   `adr/traces-and-metrics-routing-via-alloy.md`.

10. **Outbound email and SMS keep using real AWS.** SES is reached over SMTP, so no emulator can
    intercept it. `app/services/outbound_sms_providers_aws_sns.rb` builds its SNS client without an
    `endpoint:` option. Whether staging sends SMS at all is still not decided here.

11. **MSK is migrated on a best-effort basis.** `terraform/modules/streaming` is applied against the
    emulator and the result is recorded. If the emulator does not implement the operations the
    module needs, the streaming module is excluded from the emulator environments, and the result
    is recorded rather than worked around. The repository has no Kafka client, so no application
    behaviour depends on it.

## Status of implementation

The decision is ahead of the code.

- Not built: the emulator Containerfile, the Compose service, the Terraform provider changes and
  the updated port-exposure and credential guards. `compose.yaml` and `terraform/` still target
  FakeCloud.
- Not verified: none of the emulator properties listed under Context has been observed in this
  repository. MSK coverage (decision 11) is unknown.
- `docs/operations/local-aws-fakecloud.md` and `docs/operations/fakecloud-migration-verification.md`
  describe the FakeCloud setup and remain accurate for the current code until the migration lands.
  They are replaced when it does.

## Consequences

- The emulator comes from the same vendor as the API models it serves, and is versioned and
  checksum-pinned in this repository. Upgrades become deliberate, reviewed changes instead of
  digest bumps from a project without a release channel.
- A restart empties the emulator. Re-applying Terraform is part of starting an environment, and any
  workflow that assumed buckets survive `podman compose down` no longer holds.
- Callers need the generated key pair and CA bundle instead of literals. This adds a mounted
  directory and explicit credential wiring to every caller, in exchange for an emulator that real
  AWS keys cannot authenticate against.
- HTTPS with a per-run certificate means every caller must trust `ca.pem`. Settings that point to
  the file path keep working across restarts; copies of the certificate do not.
- Staging fidelity is bounded by the emulator. IAM evaluation, quotas, throttling and
  cross-account or cross-Region behaviour are not exercised. Staging proves wiring, not AWS
  behaviour.
- The first `terraform apply` against the emulator is expected to surface provider and attribute
  errors. A second `terraform plan` that reports no changes is the acceptance signal.

## References

- `adr/fakecloud-podman-staging-environment.md`: the superseded decision.
- `adr/staging-aurora-postgresql-topology.md`: the deferred staging database.
- `adr/cosmos-outbound-network-access-policy.md`: outbound network rules that telemetry would
  otherwise touch.
- `docs/operations/development-host-port-exposure.md`: the loopback publication rule.
- AWS Emulator User Guide, `https://docs.aws.amazon.com/emulator/latest/userguide/`: getting
  started (Docker), pointing an SDK at the emulator, command reference, and telemetry.
