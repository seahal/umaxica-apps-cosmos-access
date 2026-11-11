# Local AWS Emulation with fakecloud

> Access has removed its application-level object-storage integration. S3 setup below describes the
> former runtime and remains only as FakeCloud infrastructure context; it does not verify current
> Access behavior.

> The former S3 SDK path was verified on 2026-09-14 against FakeCloud. That result is historical and
> does not verify the current Access application; see the retained verification record. Terraform
> commands and the MSK data plane remain unverified.

The decisions this document implements — Terraform over OpenTofu, Podman-hosted FakeCloud staging
instead of an AWS account, the module/environment split, and the `DEPLOYMENT_TIER` contract — are
recorded in `adr/fakecloud-podman-staging-environment.md`.

`fakecloud` is this repository's single AWS compatibility layer for development. It replaces the
former RustFS service (S3) and the former standalone Kafka broker (MSK), so there is one local AWS
endpoint rather than one emulator per service.

It is **not** behind a Compose profile. A plain `podman compose up` starts it alongside `core`,
`primary`, `replica`, `valkey-cache`, and `valkey-rate-limit`, because S3 and MSK are meant to be
standing development infrastructure rather than a special mode.

## What Is Available

> **This table is what has been investigated here, not what FakeCloud can do.** Version 0.44.10
> advertises roughly 105 services on `GET /_fakecloud/health`, including `rds`, `elasticache`,
> `ses`, `sns`, `sqs`, `kms`, `secretsmanager`, `monitoring`, and the CodeBuild/CodePipeline family
> — see `evidence/2026-09-14-fakecloud-service-inventory.md` for the full list. Do not read an
> absence below as a capability limit. Equally, do not read presence in that list as "it works":
> `kafka` is listed, and the MSK data plane still does not function here, for the reason given
> below.

| Surface                              | State                                                                                                                         |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| S3                                   | Emulator service available; Access no longer has an application object-storage integration.                                   |
| MSK control plane                    | Usable. `CreateCluster`, `DescribeCluster`, `GetBootstrapBrokers`, `DeleteCluster` all respond with real AWS response shapes. |
| MSK data plane (a real Kafka broker) | **Not available here.** See below.                                                                                            |

### Why There Is No Kafka Broker

fakecloud can back each provisioned MSK cluster with a real single-node Apache Kafka container, but
only when it is handed a Docker or Podman socket, because it spawns that broker as a sibling
container. Mounting a container runtime socket into `fakecloud` grants it the invoking user's
complete container-management rights — the ability to start any image and bind-mount any host path
the user can reach.

> **Amended 2026-09-14.** `compose.yaml` still mounts no container socket, and the statement above
> is why. A socket mount was added to `compose.override.yaml` as a deliberate, risk-accepted
> exception so the MSK data plane can be exercised — see
> `evidence/2026-09-14-fakecloud-podman-socket.md`. That file was untracked and gitignored the same
> day, so the mount stays on one machine and reaches no other clone. It is also
> `${XDG_RUNTIME_DIR}`-dependent and therefore not portable, and `devcontainer.json` passes explicit
> `-f` flags that exclude `compose.override.yaml`, so the Dev Container path still gets a
> socket-free fakecloud. The text below describes the unmodified `compose.yaml` behaviour.

Without a socket fakecloud serves the MSK control plane with the _same response shapes_, which is
what the Terraform resources in `terraform/` exercise. `GetBootstrapBrokers` therefore returns
well-formed addresses with nothing listening on them. Producing and consuming against a local broker
is deferred; it is also not currently needed, because the repository contains no Kafka client at all
(no `rdkafka`, `karafka`, `racecar`, or `ruby-kafka`, and no producer, consumer, or job).

`test/tooling/compose_host_port_exposure_test.rb` guards this: no Compose service may mount a
`docker.sock` or `podman.sock`.

## Endpoints

There are two, and they are not interchangeable.

| Caller                                              | Endpoint                                                              |
| --------------------------------------------------- | --------------------------------------------------------------------- |
| The Access Rails application                        | No S3 client or object-storage endpoint is configured.                |
| The developer's host (Terraform, `aws` CLI, `curl`) | `http://localhost:4566` — the loopback publication in `compose.yaml`. |

The host publication is loopback-only (`127.0.0.1:${FAKECLOUD_HOST_PORT:-4566}:4566`), matching the
standing rule in `development-host-port-exposure.md`. Override the host port with
`FAKECLOUD_HOST_PORT` in the repository `.env` if 4566 is already taken.

## Credentials

Development uses the literal, obviously fake values `test` / `test`.

fakecloud validates the _shape_ of a SigV4 signature but never the key material, so these are not
secrets. The RustFS-era Podman secrets (`dev_rustfs_access_key`, `dev_rustfs_secret_key`,
`dev_rustfs_rpc_secret`) existed only because the RustFS entrypoint rejected weak or `/`-bearing
keys; they bought nothing here and have been removed.

Using visibly fake literals is the safeguard, not an absence of one: a real AWS access key pasted
into `compose.yaml` or `terraform/environments/development` is obvious on sight, rather than hidden
behind a generated `/run/secrets` file. `development_container_contract_test.rb` asserts these
values stay literal and uninterpolated.

Access no longer selects S3 storage by deployment tier or reads object-storage configuration. Shared
FakeCloud service setup remains separate from the Access Rails runtime.

### Migrating from RustFS

Nothing generates or validates `.secrets/` any more, so a stale checkout carries the three RustFS
files inertly rather than failing on them. Nothing reads them either -- the Podman Secrets they
backed are gone from `compose.yaml` -- but they are credential-shaped files with no owner. Clean up
once:

```bash
rm -f .secrets/rustfs-access-key .secrets/rustfs-secret-key .secrets/rustfs-rpc-secret
podman secret rm dev_rustfs_access_key dev_rustfs_secret_key dev_rustfs_rpc_secret
podman volume rm umaxicaappscosmosaccessdc_rustfs-data0 \
                 umaxicaappscosmosaccessdc_rustfs-data1 \
                 umaxicaappscosmosaccessdc_rustfs-data2 \
                 umaxicaappscosmosaccessdc_rustfs-data3
```

## Persistence

`FAKECLOUD_STORAGE_MODE: persistent` with `FAKECLOUD_DATA_PATH: /var/lib/fakecloud` writes state to
the `fakecloud-data` named volume. Without it fakecloud keeps everything in memory and a restart
silently discards every bucket and object.

This gives the two teardown verbs their natural meaning:

```bash
podman compose down       # buckets, objects, and MSK metadata survive
podman compose down -v    # fakecloud-data is removed with every other volume
```

Because no sibling containers are spawned (see above), `fakecloud-data` is the whole of fakecloud's
lifecycle. There is no second volume owned by a broker container to reason about.

## Health

The container image is Debian bookworm carrying only `ca-certificates`, `nftables`, `kmod`, and
`procps`. It has **no `curl` and no `wget`**, so the health probe published in fakecloud's own
documentation cannot run inside it. The Compose healthcheck instead uses bash's `/dev/tcp` — bash is
`Priority: required` in Debian — to request the documented introspection endpoint:

```bash
# From the host:
curl -s http://localhost:4566/_fakecloud/health
# => {"status":"ok","version":"...","services":[...]}
```

## Image Pinning

The upstream registry publishes only `latest`, `main`, and `sha-<commit>` tags — there is no semver
tag to track. The image is therefore pinned by digest:

```
ghcr.io/faiscadev/fakecloud:latest@sha256:48b0a8b3f0ee14d0d71f704954e1d2c6b48b88fab67468dd85beb633b33f7dc9
```

Dependabot's `docker` ecosystem updates the digest on this form. Because the upstream has no release
channel, a digest bump can carry a breaking change; review those PRs against the fakecloud changelog
rather than merging them as routine.

## Provisioning AWS Resources

Buckets and clusters are **not** created by a Compose `command:` or an init container. They are
declared in `terraform/` and applied with Terraform, so development exercises the same resource
definitions production will.

```bash
cd terraform/environments/development
terraform init
terraform validate
terraform plan
terraform apply
terraform plan      # must report no changes
```

`terraform/modules/` is environment-agnostic — it names no endpoint and no credential. Everything
fakecloud-specific lives in `terraform/environments/development/providers.tf`. A production
environment reuses the same modules with real AWS endpoints; it is deliberately not created yet.

State is a local backend and is gitignored: it describes a disposable emulator on one machine.

### Verifying S3

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
aws --endpoint-url http://localhost:4566 s3 ls
aws --endpoint-url http://localhost:4566 s3 cp ./some-file s3://umaxica-avatar-development/probe
aws --endpoint-url http://localhost:4566 s3 cp s3://umaxica-avatar-development/probe -
aws --endpoint-url http://localhost:4566 s3 rm s3://umaxica-avatar-development/probe
```

The FakeCloud S3 endpoint can be inspected as infrastructure, but Access has no Rails task or
application client that exercises it.

### Verifying MSK

```bash
aws --endpoint-url http://localhost:4566 kafka list-clusters
aws --endpoint-url http://localhost:4566 kafka get-bootstrap-brokers --cluster-arn "$(
  cd terraform/environments/development && terraform output -raw msk_cluster_arn)"
```

The returned addresses are well-formed and unreachable. That is expected, not a fault.

## Differences from Real AWS

Do not read "it works against fakecloud" as "it works against AWS". Recheck each of these when
production infrastructure is built:

- **No Kafka data plane.** Broker behaviour, partitioning, consumer groups, and rebalancing are
  entirely unexercised.
- **IAM and STS are not enforced.** The provider runs with `skip_credentials_validation`,
  `skip_requesting_account_id`, and `skip_metadata_api_check`, so no permission boundary, bucket
  policy, or account-scoped ARN is validated.
- **S3 is exercised in path style only.** Real AWS uses virtual-hosted-style URLs, and the DNS and
  TLS behaviour of that path is untested here.
- **MSK runs PLAINTEXT in transit** so that a bootstrap address is returned at all. Production must
  use TLS.
- **No CloudTrail, no KMS enforcement, no cross-region behaviour, and no eventual-consistency or
  throttling semantics.**

## Out of Scope

OpenSearch, SQS, SNS, SES, KMS, and Secrets Manager are not configured, although fakecloud supports
them. Adding one means adding it to `terraform/`, not adding another Compose service.
