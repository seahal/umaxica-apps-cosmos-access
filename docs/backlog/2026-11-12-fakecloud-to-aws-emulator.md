# Replace FakeCloud with AWS Emulator (2026-11-12)

Owner: Cosmos access. Status: queued. Start after the current in-progress work is finished.

The decision is recorded in `adr/aws-emulator-podman-staging-environment.md` (decisions 1–11). That
ADR is authoritative; this item only tracks the execution. The emulator properties it lists come from
the AWS Emulator User Guide and have not yet been observed in this repository.

## Owner decisions (2026-11-12)

- Development and staging Terraform state for emulated resources is disposable; re-apply after each
  emulator restart.
- Migrate even though the emulator holds state in memory only.
- Build the image locally: base pinned by digest, RPM pinned by version and SHA-256.
- MSK is best-effort; an unsupported streaming module is excluded and recorded.
- Apply the same direction to the other Cosmos repositories (governance, press, sphere): yes.

## Other Cosmos repositories (observed 2026-11-12, read-only)

Governance, press and sphere still reference FakeCloud in `compose.yaml`, `.env.container.devcontainer`,
`README.md`, `terraform/` and ADRs. Unlike Access, each still has a live Shrine/S3 integration
(`lib/object_storage_shrine_configuration.rb`, `app/uploaders/application_uploader.rb`,
`app/models/publishing/media_file.rb`). That changes three things there:

- In-memory state means uploaded objects disappear whenever the emulator container stops (host
  reboot, `podman compose down` or `restart`, image update, OOM restart), while database rows
  referencing them survive. Owner decision (2026-11-12): accepted for development; broken media links
  after such a stop are expected, and no re-seed is required.
- The emulator regenerates its keys and certificate at each start, so a Rails container that reads
  them only at boot must be restarted after the emulator restarts. Make that failure explicit rather
  than silent.
- The Rails container needs the per-run emulator keys and must trust `ca.pem` (HTTPS). Whether the
  Ruby SDK picks up `AWS_CA_BUNDLE` or needs `ssl_ca_bundle` set explicitly is unverified. Keep the
  `OBJECT_STORAGE_*` namespace (no implicit `AWS_ENDPOINT_URL`).
- Each repository's copy of `adr/fakecloud-podman-staging-environment.md` needs its own superseding
  ADR, which keeps the object-storage decisions that Access dropped.

Do this in each repository as its own change after that repository's current work settles; each had
a large uncommitted worktree on 2026-11-12. Access goes first and serves as the reference.

## Steps

1. Implementation (Codex):
   - Add a Containerfile for the emulator (Amazon Linux 2023 base by digest, RPM by explicit version
     plus SHA-256, non-root user).
   - Replace the `fakecloud` service and `fakecloud-data` volume in `compose.yaml`:
     `EMULATOR_TELEMETRY=off`, auth on, `-b 0.0.0.0 -p 9297`, publish `127.0.0.1:9297` only, shared
     `~/.aws/emulator` mount, HTTPS health check on `/__admin/health` with `--cacert`. No container
     socket mount.
   - `terraform/environments/{development,staging-development}`: HTTPS endpoint, `custom_ca_bundle`
     pointing at `ca.pem`, emulator keys passed explicitly so ambient `AWS_*` credentials cannot win,
     path-style S3; remove the `test` / `test` literals.
   - Update the guards in `test/tooling/` (port exposure, credential literals).
   - Remove `OBJECT_STORAGE_ENDPOINT` (`127.0.0.1:4566`) from `.github/workflows/ci.yml` after
     confirming nothing reads it.
2. Verification (Codex), recorded in `evidence/`:
   - `podman compose up` reaches healthy.
   - `aws sts get-caller-identity` returns account `000000000000`.
   - `terraform apply` succeeds for development; a second `terraform plan` shows no changes.
   - Streaming module result (success, or the failing operation and status code).
   - `bin/rails test test/tooling` passes.
3. Documentation (Claude), after the implementation lands:
   - Replace `docs/operations/local-aws-fakecloud.md` and
     `docs/operations/fakecloud-migration-verification.md`.
   - Update the "Status of implementation" section of the ADR.
   - Align remaining FakeCloud wording in `adr/staging-aurora-postgresql-topology.md`,
     `adr/cosmos-signing-key-management.md` and the Aurora entry of `adr/README.md`.

## Done when

All verification items above are recorded in `evidence/`, no tracked file references FakeCloud except
historical records (superseded ADR, research, evidence, archived plans), and the documentation in
step 3 describes the emulator setup.
