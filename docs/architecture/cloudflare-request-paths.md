# Cloudflare Request Paths and Trust Boundaries

This document describes every request path that reaches Rails, the trust domain each hop belongs to,
and which component can forge which header. It exists because Cloudflare Tunnel, Cloudflare Access,
and Workers VPC are distinct trust domains that must not be conflated.

Access uses only `cloudflare-tunnel` with `CLOUDFLARED_TOKEN`. Workers VPC belongs to Press; Access
supplies no connector or origin alias for it. See the
[tunnel split plan](../../plans/2026-11-08-cloudflare-tunnel-split.md). Cloudflare resources and
Press configuration are outside Access local cleanup.

## Hostname Families, Routing Targets, and Host Authorization

`PUBLIC_*_URL` and `PRIVATE_*_URL` are the **only two hostname families** (see
`adr/public-private-url-boundaries.md`). `PUBLIC_*` names the site a browser or app sees;
`PRIVATE_*` names the network-side ingress that Cloudflare or AWS connects to. They are not a
development/production split.

A **routing target** is not a hostname family member's role but a separate concept. Tunnel ingress
keeps the two strictly apart:

- A Tunnel ingress rule's `service:` address is a routing target. `cloudflared` leaves the HTTP
  `Host` header unmodified unless `httpHostHeader` is set, so the origin receives the **browser's**
  hostname, not the `service:` address. `originServerName` affects TLS certificate validation only.

Therefore: **Rails Host Authorization evaluates the HTTP `Host` header Rails actually receives —
never the routing target that delivered the request.** A routing target must never be added to
`config.hosts` on the grounds that it "is how the request got here".

`ActionDispatch::HostAuthorization` evaluates **two** values, not one: the raw `HTTP_HOST`, and the
last comma-separated value of `X-Forwarded-Host` when that header is present. A request is rejected
if _either_ is disallowed. Any hop that sets `X-Forwarded-Host` therefore adds a second name that
`config.hosts` must admit. A hop that sets `X-Forwarded-Host` from one family while connecting under
a `Host` from the other makes a union of the retained `PUBLIC_*` and `PRIVATE_*` hosts mandatory
regardless of which family was chosen for `Host` — so a hop must either send both from the same
family or omit `X-Forwarded-Host` entirely.

Which family supplies that `Host` follows from the ingress the listener sits behind:

| Environment | Ingress                                                                  | `Host` Rails receives                                   | `config.hosts` derives from |
| ----------- | ------------------------------------------------------------------------ | ------------------------------------------------------- | --------------------------- |
| Production  | Cloudflare edge → Tunnel                                                 | browser's public hostname                               | `PUBLIC_*`                  |
| Development | Cloudflare edge → Access → Tunnel, **and** direct on the private network | browser's public hostname, or the private ingress alias | `PUBLIC_* ∪ PRIVATE_*`      |

Development is the environment with two live ingresses, so its `config.hosts` is a union of the
configured retained public and private hosts. The local aliases are Auth APP/ORG, Visa APP/ORG and
the Mission, Flipper, Blazer, PgHero, Coverband and Swagger tool hosts listed in
[`docs/reference/subdomains.md`](../reference/subdomains.md). Each ingress delivers a `Host` from
its own family, and Rails admits the `Host` it actually receives.

`/health` and the three singular text probe paths (`/health/{liveness,readiness,startup}`) are the
deliberate exception: orchestrator and container probes reach the origin directly and carry no
meaningful `Host`, so production excludes those exact paths from Host Authorization
(`lib/health_probe_paths.rb`) rather than allowlisting a probe hostname. The machine JSON endpoints
`/api/v0/health.json` and `/api/v0/revision.json` are reached through the tunnel with a real `Host`
and are deliberately not exempt.

**A third hostname family is not justified.** Current local routes use the two configured host
families. Workers VPC is outside Access's request paths.

## Development Is Tunnel-Exposed Behind Access

Development Rails **is** published through Cloudflare Tunnel under the retained browser-facing host
names, with Cloudflare Access as the perimeter in front of them. Reaching development requires
passing an Access policy at the Cloudflare edge before the connector will proxy anything; Rails
authentication and authorization still apply behind it.

Development is therefore reachable two ways, and both must work:

- through the tunnel, where the request carries the browser's public site name, because cloudflared
  leaves `Host` unmodified unless `httpHostHeader` is set;
- directly on the compose `frontend` network through the private `*.localhost` aliases, which is how
  the transport probe in `docs/operations/cloudflare-private-origin.md` reaches Rails.

### How the two families reach Host Authorization

`config/environments/development.rb` builds `config.hosts` from the environment plus explicit local
aliases. `.devcontainer/compose.yaml` declares those private aliases, while configured public and
private URLs supply the tunnel and ingress host values:

1. `.devcontainer/compose.yaml` aliases the retained private `*.localhost` origins to the `core`
   container on the `frontend` network.
2. `development.rb` admits the configured `PRIVATE_*_URL` and `PUBLIC_*_URL` host values plus those
   retained local aliases.
3. `boot_config` defines Auth and Visa host families. The operator tools have their own configured
   host entries; neither Base nor other retired product families are part of current host
   authorization.

The remotely managed Tunnel routes the retained Auth, Visa and operator hosts to the Rails origin.
Its external configuration is not evidence that a retired Access host remains a local route.

The historical Host Authorization observation in
[`evidence/2026-10-13-environment-test-retirement-A6V9.md`](../../evidence/2026-10-13-environment-test-retirement-A6V9.md)
predates the surface reset and used former host families. It does not verify the current host set.
Inspect the active configuration when host ownership changes.

### Scheme and cookie behaviour on the tunnel path

- **Scheme trust is not a blocker.** `TRUSTED_PROXIES` is not configured and development sets
  neither `assume_ssl` nor `force_ssl`, but Rack 3.1's `Rack::Request#scheme` honours the
  `X-Forwarded-Proto: https` that the Cloudflare edge sets and cloudflared passes through without
  gating it on the peer being a trusted proxy. The recorded scheme probe used a retired host and
  must not be treated as current Auth/Visa verification. Recheck origin and CSRF behavior on the
  retained hosts after a proxy or host configuration change.
- Session and preference cookie behavior is configured separately. Verify current cookie settings in
  the owning Auth/Visa contract before relying on observations recorded against the former host set.

## Trust Domains

| Domain            | Purpose                                      | Never used for                                                                                                    |
| ----------------- | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Cloudflare Tunnel | Selected externally reachable Rails ingress  | Service-to-service (Workers / Edge) traffic                                                                       |
| Workers VPC       | Press-owned service-to-service path          | Access ingress                                                                                                    |
| Cloudflare Access | Perimeter for explicitly protected hostnames | Rails' primary identity system — Rails authentication and authorization remain authoritative regardless of Access |

## Request Paths

### 1. Public browser request through Cloudflare

```text
Browser --(HTTPS)--> Cloudflare edge --(QUIC tunnel)--> cloudflared (compose: cloudflare-tunnel)
  --(private `frontend` network)--> core (Rails)
```

- `cloudflared` is the unprofiled `cloudflare-tunnel` service in `compose.yaml` (image
  `cloudflare/cloudflared:2026.8.2`,
  `tunnel --no-autoupdate --protocol auto --metrics 0.0.0.0:2000 run`, and `TUNNEL_TOKEN` resolved
  from the gitignored repository `.env`). A plain Compose `up` and the Dev Container lifecycle both
  start it. Previous Edge connector instructions are deferred for separate reconciliation; they do
  not describe the current Compose service inventory.
- The connector is attached only to Access's private `frontend` network. Access and Edge do not
  share a Podman network. Workers VPC connectivity belongs to Press, not Access.
- `core` never publishes a host port in the base `compose.yaml`. No test asserts this any longer:
  `test/unit/security/tunnel_origin_isolation_test.rb` was removed, and Compose configuration is
  verified by running it (`adr/no-test-suite-for-environment-construction.md`). This is the actual
  security boundary: nothing outside the compose project's private networks can reach Rails
  directly.
- Headers Cloudflare's edge sets and the client cannot override: `CF-Connecting-IP`, `CF-Ray`,
  `CF-IPCountry`. Headers the client _can_ set and Cloudflare may append to (not replace) if already
  present: `X-Forwarded-For`.
- Rails currently derives `request.remote_ip` from `X-Forwarded-For` via `ActionDispatch::RemoteIp`,
  using the framework default `trusted_proxies` (RFC1918 private ranges) — `config/application.rb`'s
  `TrustedProxiesConfig` machinery is a no-op today because `ENV["TRUSTED_PROXIES"]` is never set
  anywhere in the repo.
- **Verified property, not a desired one**: `ActionDispatch::RemoteIp` does not gate trust on
  whether the immediate peer (`REMOTE_ADDR`) is itself a trusted proxy — it only strips proxy-hop
  IPs found _within_ the `X-Forwarded-For` chain. A request that reached Rails directly, bypassing
  `cloudflared`, could set an arbitrary `X-Forwarded-For` and have it trusted regardless of
  `trusted_proxies` value. The removed `test/unit/security/tunnel_origin_isolation_test.rb` held the
  reproducible proof; it is no longer in the suite. **The real control is network isolation**
  (previous paragraph), not the `trusted_proxies` value itself.
- **Decision**: do not widen `trusted_proxies` to Cloudflare's public IP ranges — there is no
  evidence Rails ever receives a connection directly from those addresses (it only ever sees
  `cloudflared`'s private network address). Do not implement a custom `CF-Connecting-IP` reader
  either: Rails' `ActionDispatch::RemoteIp` has no configurable header name (verified —
  `forwarded_for`/`client_ip` are hardcoded to `X-Forwarded-For`/`Client-Ip` in Rack, not
  configurable), so honoring `CF-Connecting-IP` would require new custom middleware. Given the
  network isolation configuration boundary, that additional middleware is not currently justified.
  Revisit only if a feature specifically needs Cloudflare's more precise client-IP header; the
  removed regression test no longer guards this boundary.

### 2. Operator/browser request through Cloudflare Access

```text
Browser --(HTTPS, Access cookie/JWT)--> Cloudflare edge --(Access policy check)-->
  cloudflared --(originRequest.access JWT validation, if configured)--> core (Rails)
```

- Cloudflare Access is a perimeter, not Rails' identity system. Rails authentication and
  authorization (session/credential ceremonies, MFA, passkeys) remain authoritative for every
  request, Access-protected or not.
- `cloudflared` supports validating the Access JWT itself before proxying, via
  `originRequest.access` (`required`, `audTag`, `teamName`) per hostname. This is the preferred
  validation point — it runs before the request reaches Rails at all.
- **The development tunnel hostnames are Access-protected, and that protection lives in the
  Cloudflare account, not in this repository.** This remotely managed connector authenticates with
  the tunnel-scoped token described in `docs/operations/cloudflare-private-origin.md`, so its
  ingress rules and `originRequest.access` blocks are configured in the Cloudflare dashboard; no
  file here can assert they are present. Treat "the Access application exists and the published
  development route enables Access validation" as an external check, in the sense of the "External
  Checks" section of `docs/operations/cloudflare-private-origin.md` — the repository-side controls
  (network isolation, Host Authorization, Rails authentication) do not depend on it, but the
  confidentiality of the development surface does. Record the hostname, `audTag`, and `teamName`
  here once they are settled.
- Rails does not validate `Cf-Access-Jwt-Assertion` itself and should not, unless a specific feature
  needs to consume Access identity/claims directly — none does today. Adding Rails-side validation
  merely for "defense in depth" duplicates the connector-side check without a concrete requirement
  driving it.

#### Retained Access host families

Current local hosts are Auth APP/ORG, Visa APP/ORG and the six operator tools in
[`docs/reference/subdomains.md`](../reference/subdomains.md). The Cloudflare account owns tunnel
ingress and Access policy for published development hosts. The former `jp.*`, Base, Core, Warp,
Palm, Edit and Tech paths in earlier tunnel inventories are retired and are not current route
contracts. For an individual request, a Rails response carries an `x-request-id`; absence of that
header does not by itself identify which external hop rejected the request.

### 3. Workers VPC ownership

Workers VPC is used only by Press. Access has no `cloudflare-tunnel-workers-vpc` service or
`core-workers-vpc.internal` origin alias. The Press tunnel and Worker configuration remain unchanged
by local Access cleanup. Historical Host decisions remain in `adr/core-canonical-public-host.md`;
they do not establish a current Access VPC path.

## Header Trust Summary

| Header                    | Set by                                                    | Forgeable by a direct-access attacker (network isolation intact)? | Forgeable if network isolation is ever broken?                                                 |
| ------------------------- | --------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `CF-Connecting-IP`        | Cloudflare edge only                                      | No (Rails doesn't read it)                                        | Yes, trivially — Rails has no way to distinguish a real edge from a direct attacker            |
| `X-Forwarded-For`         | Cloudflare edge (appends), `cloudflared` (passes through) | No — attacker cannot reach `core` at all                          | Yes — `ActionDispatch::RemoteIp` trusts it regardless of peer, per the verified property above |
| `Cf-Access-Jwt-Assertion` | Cloudflare Access, after policy evaluation                | No (Rails doesn't validate it; connector should)                  | Cryptographically signed — not forgeable even with direct access, unlike the IP headers above  |

## Non-Goals of This Document

- Does not configure the Worker binding or the VPC Service resource; those are owned outside this
  Access repository. Access provides neither a VPC target nor a VPC connector.
- Does not add Rails-side `CF-Connecting-IP` support — no feature currently needs it, and adding
  custom middleware for it now would be unjustified scope.
