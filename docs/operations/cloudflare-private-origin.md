# Cloudflare Private Origin Contract

Access uses the existing `cloudflare-tunnel` connector and `CLOUDFLARED_TOKEN` to reach Rails
through this project's private Podman `frontend` network. Its assigned browser hosts are Auth and
Visa on app/org plus the six Access operator hosts recorded in
[the tunnel split plan](../../plans/2026-11-08-cloudflare-tunnel-split.md). Rails authentication,
authorization and surface ownership remain authoritative.

Workers VPC belongs to Press. Access defines no Workers VPC connector or origin alias and needs no
`CLOUDFLARED_WORKERS_VPC_TOKEN`. Local cleanup must leave the Cloudflare tunnel, token, DNS, Access
applications and Worker configuration unchanged; Press continues using them. Local container removal
and live verification are recorded separately in evidence.

## Invariants and Verification Gates

The private transport invariant is:

```text
same Podman frontend network
  -> same Podman DNS
  -> private origin alias
  -> Rails listener
  -> HTTP response
```

The gates are intentionally independent:

1. **Private transport**: an ephemeral curl container on the same compose `frontend` network as the
   running connector requests `GET /health/liveness` through every private surface alias and
   requires HTTP `200`. No committed script performs this — `bin/` carries generated binstubs only —
   so it is a manual procedure, written out under "Running the Transport Probe" below.
2. **Host Authorization**: boot Rails in development, construct `ActionDispatch::HostAuthorization`
   from the effective settings, and send `GET /` through `Rack::MockRequest` to a stub endpoint.
   Confirm HTTP 200 for the documented private origin aliases and published site hostnames; confirm
   HTTP 403 for an unconfigured Umaxica hostname and an unrelated hostname. The 2026-10-13
   observation is recorded in
   [evidence](../../evidence/2026-10-13-environment-test-retirement-A6V9.md). This is an operational
   check, not a test-suite guard; repeat it after changing host configuration.
3. **Surface routing**: `bin/rails routes` and the route host constraints identify only Auth
   APP/ORG, Visa APP/ORG, and the six retained operator tools. Private host values must resolve to
   their corresponding retained surface.
4. **Podman DNS aliases**: `podman compose config` must show the retained private aliases on
   `core`'s `frontend` network and no new host port publication. The connector never needs an
   inbound host port and must not be given one; the only publications in the stack are `core`'s
   loopback-bound host `3001` to container `3000`. See
   `docs/operations/development-host-port-exposure.md`.
5. **Repository regression checks**: run the focused tests first, then the full Rails suite,
   coverage, and lint checks when the test databases are available.

`/health` is excluded from Rails Host Authorization in production. A successful Gate 1 request
therefore proves transport reachability only. It does not prove that the Host is accepted by
`ActionDispatch::HostAuthorization`, and it does not substitute for Gate 3 routing evidence.

## Development Scope

Development Rails is published through this tunnel under the retained browser-facing hosts, behind
Cloudflare Access. The `core` container carries the retained private `*.localhost` aliases and the
published site names; development Host Authorization admits the configured values from those
families. See the "Development Is Tunnel-Exposed Behind Access" section of
`docs/architecture/cloudflare-request-paths.md` for the current host families and cookie behavior.

The current origin aliases belong to `.devcontainer/compose.yaml`. Foreign product hosts and Workers
VPC surfaces belong to their owning repositories; their publication is outside this Access
procedure.

Access is the control that keeps the development surface non-public, and it lives in the Cloudflare
account rather than in this repository — see "External Checks" below.

## Browser Traffic Through Access

Create the Cloudflare Access application before publishing its tunnel hostname. Enable Access
protection for the published route so cloudflared validates the Access assertion before proxying the
request. Rails application authorization remains responsible for every application permission;
Access does not replace it.

The accepted scope and the deferred Rails-side JWT validation decision remain in
`adr/org-cloudflare-access-authentication-layer.md`. Cloudflare documents the deployment ordering in
[Publish a self-hosted application](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)
and the tunnel Access options in
[Origin configuration](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/origin-configuration/).

## Authenticating the Connector

Access currently runs one `cloudflare-tunnel` connector using `CLOUDFLARED_TOKEN`. Follow the
Cloudflare dashboard and approved secret-inventory procedures to add or rotate its connector
credential; never paste the token into commands, logs, documents or this conversation. The tunnel
and token configuration are outside this surface-documentation cleanup.

The connector reaches Rails directly over `frontend`. It has no `host.docker.internal` alias, no
Edge project network, and no supported route back through a host-published application port. Access
does not provide a Workers VPC Service target.

## Running the Transport Probe

Run this from a host terminal: `podman` is not on `PATH` inside `core`. Start `core` and whichever
connector this session uses first.

Nothing is executed inside the cloudflared container — that image carries no shell, curl, or wget.
Every request comes from a throwaway curl container attached to the connector's own network, so a
`200` is evidence that the connector's network position reaches Rails, not merely that Rails is up.

Take the connector's network from its compose labels rather than assuming a project name:

```bash
cid=$(podman ps -q --filter label=com.docker.compose.project=umaxicaappscosmosaccessdc \
  --filter label=com.docker.compose.service=cloudflare-tunnel)
net=$(podman inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$cid")
```

Gate the connector before reading anything into an origin result. A container id alone proves
nothing: `ps -q` still reports one between restarts, so a crash-looping connector otherwise reads as
a Rails or DNS fault instead.

```bash
podman inspect -f '{{.State.Status}} restarts={{.RestartCount}}' "$cid"   # want: running restarts=0
podman run --rm --network "$net" docker.io/curlimages/curl:8.16.0 \
  -sS --max-time 5 http://cloudflare-tunnel:2000/ready                    # want: {"status":200,...}
```

Then request `/health/liveness` through each private alias. Under the 2026-09-03 text health
contract both `/health` and `/health/liveness` return `text/plain` `200` (they no longer negotiate
on `Accept`), so either works; `/health/liveness` is the narrower, dependency-free probe and stays
the recommended target. Leave `Host` to curl — it sends `<alias>:3000`, which is the form
`config.hosts` carries for the private origins.

The retained alias list is the `frontend` `aliases:` block of the `core` service in
`.devcontainer/compose.yaml`. The filter below limits the probe to Auth, Visa and the six operator
tools in the current surface map:

```bash
aliases=$(podman inspect -f '{{range .NetworkSettings.Networks}}{{range .Aliases}}{{println .}}{{end}}{{end}}' \
  "$(podman ps -q --filter label=com.docker.compose.project=umaxicaappscosmosaccessdc --filter label=com.docker.compose.service=core)" | grep -E '^(auth|visa|mission|flipper|blazer|pghero|coverband|swagger)\.')

for a in $aliases; do
  podman run --rm --network "$net" docker.io/curlimages/curl:8.16.0 \
    -sS -o /dev/null --max-time 5 -w "%{http_code} $a\n" "http://$a:3000/health/liveness"
done
```

Every line must read `200`. Pin the curl tag, or a digest, rather than tracking `latest`.

Historical observation (2026-09-05): a probe against a former `*.localhost` alias returned `000`,
and the container resolver mapped the former alias to `::1`. That reflects glibc's RFC 6761 handling
of names below `localhost.`, not a current route or alias inventory. Treat `000` from a probe
against any retained `*.localhost` alias as inconclusive for connector reachability and diagnose the
tunnel path separately.

A `403` is Host Authorization, not transport: the alias resolved and Rails answered, but no
`config.hosts` entry admits that name. Fix it in `config/environments/development.rb` or remove the
alias; do not read it as a connector fault.

The health endpoints are excluded from Host Authorization in production, so this gate proves
transport only — see the note under "Invariants and Verification Gates" and run Gates 2 and 3 for
the rest.

## External Checks

Repository checks cannot prove these Cloudflare-account and network controls:

- outbound UDP 7844 is allowed from the connector environment;
- the Access application exists before its published hostname, including the development hostnames;
- the published route enables Access validation;
- the tunnel has no replica in a network that cannot reach this Rails origin. Cloudflare may route
  traffic to any connector replica, so every replica for this tunnel must provide the same origin
  reachability.

Treat each as blocked until verified in the deployment environment. Do not infer them from a local
`/health` response.

Historical development observations remain in
`research/implementation/2026-08-10-development-tunnel-access-verification.md`. They predate the
Cosmos split and do not prove current Access reachability. Verify only the owner-approved Auth, Visa
and operator hosts using the method authorized for the current maintenance session.

## Server-to-Server Calls Through the Tunnel May Fail

After the Cosmos split, server-to-server calls between repositories (an RP fetching Visa's Discovery
and JWKS or calling its token, UserInfo and revocation endpoints; Access fetching an RP's
`/.well-known/jwks.json`) travel through the public hostnames and each repository's Cloudflare
Tunnel. Such calls can fail for reasons outside the application, so a failure on this path does not
by itself indicate an application defect:

- **Cloudflare Access.** A locked Access policy on a retained Auth or Visa development host can
  redirect server-to-server OIDC calls to the Access login and stop RP sign-in. Verify the
  owner-approved policy for the exact host in the Cloudflare account before treating a failed call
  as an application defect (`plans/2026-11-08-cloudflare-tunnel-split.md`).
- **Connector state.** A tunnel with no healthy connector answers Error 1033. A connector still
  running with another repository's token joins that tunnel as a replica, so requests reach a random
  repository.
- **Container lifecycle.** The receiving repository's Dev Container may be stopped or recreating.

Check these first when a cross-repository call fails in development. This path is not available for
offline or tunnel-less local work.
