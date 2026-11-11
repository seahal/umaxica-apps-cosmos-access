# Access Workers VPC Local Cleanup

- Revision: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- Uncommitted changes affect these observations. Existing Compose, environment, routing, ADR and
  host-port documentation changes were present before this work and retained.
- Scope: owner-approved local Workers VPC cleanup following
  `plans/2026-11-08-cloudflare-tunnel-split.md`. The owner deferred Edge cleanup; Edge containers,
  variables and legacy setup instructions were not removed. No commit was made.
- Removed the single `CLOUDFLARED_WORKERS_VPC_TOKEN` assignment from the repository-root `.env`. An
  in-memory byte comparison confirmed that all other content was retained. No secret values were
  printed or recorded. `.env.container.devcontainer` needed no change for this cleanup.
- Updated `docs/operations/cloudflare-private-origin.md`,
  `docs/architecture/cloudflare-request-paths.md`,
  `docs/operations/development-host-port-exposure.md`,
  `docs/operations/devcontainer-cli-podman-startup.md`,
  `docs/operations/container-engine-podman-notes.md` and `docs/runbooks/tech-browser-rp.md`. Access
  uses the existing connector; Workers VPC belongs to Press. The Tech procedure now identifies
  Governance ownership. Edge setup and credential documentation remain deferred, not current Compose
  inventory; the private-origin document explicitly marks the retained Edge section.
- Verification passed: Python/PyYAML parsed both Compose files; the only defined tunnel connector is
  `cloudflare-tunnel`, retaining its `CLOUDFLARED_TOKEN` reference. Both environment files have no
  Workers VPC token assignment. `git diff --check` passed for the six documentation files.
- Blocked: `podman ps -a --filter label=com.docker.compose.project=umaxicaappscosmosaccessdc` failed
  with `Failed to obtain podman configuration` and a read-only-filesystem error while attempting to
  set the sticky bit on `/run/user/1000/libpod`. Podman also reported stale pause state. No runtime
  repair was attempted. The engine attempted runtime bookkeeping during this inventory command;
  successful completion of that bookkeeping was not established.
- The owner reported `umaxicaappscosmosaccessdc_cloudflare-tunnel-workers-vpc_1` running. Its
  runtime labels and state could not be independently verified. No stop or remove command was
  issued. Container removal and the final project inventory remain pending host engine access.
- No restart/recreation or probe was performed. Continued operation of `cloudflare-tunnel` is
  unverified. Auth/Visa reachability is unverified: the owner has not specified a probe method.
- Recovery boundary: no Cloudflare API, dashboard or resource operation was performed. The Press
  Workers VPC tunnel, tokens, DNS, Access applications and Worker configuration were not changed. No
  other repository containers, services, databases, networks or volumes were operated on.
- No Rails or JavaScript tests were run: these edits remove an unused local setting and reconcile
  documentation; they do not change application behavior. Environment construction was checked
  directly, not through the application test suites.
