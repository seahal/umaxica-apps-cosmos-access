# Cloudflare Tunnel Split Across Cosmos Repositories (2026-11-08)

Status: accepted work order for an agent (for example Codex). Do not commit; the owner reviews and
commits.

## Target

The four Cosmos repositories started as copies of one application (formerly Global) and still carry
the same tunnel configuration and token copies. Each repository gets its own tunnel:

| Repository | Tunnel                                                       | Hostnames                                                                       |
| ---------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| Access     | existing tunnel, kept as is                                  | `visa`, `auth` (app and org)                                                    |
| Governance | `governance-dev` (new)                                       | `base` (`www`, app, org and com), `tech` (org)                                  |
| Sphere     | `sphere-jp-dev` (new; one tunnel per region and environment) | `core` (app, org), `palm` (app), `warp` (app, org, com)                         |
| Press      | `press-dev` (new) plus the existing Workers VPC tunnel       | `edit` (org) on `press-dev`; `info`, `news`, `help`, `docs` stay on Workers VPC |

`guid` is not attached to any tunnel; it is to be retired. Whether each repository's `.dev` operator
tools get hostnames on its tunnel is an owner decision taken during step 2 of the repository section
below.

Tunnel names follow `<repository>-<environment>`; Sphere adds the region:
`sphere-<region>-<environment>`. Only `jp` is planned for Sphere for now.

Workers VPC (`umaxica-dev-workers-vpc`) is used only by Press. Access, Governance and Sphere remove
their own Workers VPC connector definition, token reference and documentation. Nobody deletes the
Workers VPC tunnel, its token, its DNS records or the Workers configuration in Cloudflare.

Related records: `adr/cosmos-base-surface-decomposition.md`,
`adr/cosmos-sphere-surfaces-and-rp-independence.md`, `specs/cosmos-press-route-ownership/spec.md`.

## Cross-Repository Order

1. Governance, Sphere and Press each create their new tunnel and Access applications, without
   hostnames that the existing tunnel still serves.
2. For each hostname that leaves the existing tunnel: Access removes it from the existing tunnel,
   then the receiving repository attaches it to its new tunnel. Do both for one hostname before
   moving to the next, so no hostname points at two tunnels.
3. Access, Governance and Sphere remove their Workers VPC configuration from their repositories.
4. Each repository starts `cloudflared` in its Dev Container and confirms its own hostnames open.

Until a repository has its own token, leave `CLOUDFLARED_TOKEN` empty in that repository's `.env`
when more than one Dev Container runs; four connectors on one token join the same tunnel as replicas
and traffic reaches a random repository.

## Rules for Every Repository

- Survey first and wait for owner approval before changing anything in Cloudflare.
- Cloudflare is an external service: change one item at a time and confirm the result.
- Never delete or rotate the existing tunnel or its token; Access keeps using them.
- Ask the owner before deleting any DNS record.
- Never print secret values in logs, documents or the conversation. Ask the owner where a new token
  is stored before writing it to a file.
- Do not commit. Report what was created, removed and kept, which files changed, and what was
  verified.

## This Repository: Access

Keep the existing tunnel and token (`CLOUDFLARED_TOKEN`); narrow it to Access.

1. Survey: list the ingress hostnames and Cloudflare Access applications of the existing tunnel, and
   the Workers VPC connector in `compose.yaml` and its documentation
   (`docs/operations/cloudflare-private-origin.md` and others). Read only.
2. Plan and wait for approval:
   - keep `visa` and `auth` (app and org);
   - remove `base` (`www`), `tech`, `core`, `palm`, `warp`, `edit`, `info`, `news`, `help`, `docs`
     and `guid`, listing for each hostname both the ingress rule and the Access application;
   - remove the Workers VPC configuration from this repository.
3. Execute after approval, removing each hostname in step with the receiving repository (see
   Cross-Repository Order). Remove the `cloudflare-tunnel-workers-vpc` connector, its token
   reference and its documentation from this repository.
4. Start `cloudflared` in the Dev Container and confirm `visa` and `auth` open.
5. Update `compose.yaml` comments and `docs/operations/` to the new layout.

## Operator Hostnames and Cross-Repository Follow-Up (2026-11-09)

The owner selected six operator hosts for Access's existing tunnel, in addition to Auth and Visa on
app and org (ten public hosts in total):

- `mission-access.umaxica.dev`
- `flipper-access.umaxica.dev`
- `blazer-access.umaxica.dev`
- `pghero-access.umaxica.dev`
- `swagger-access.umaxica.dev`
- `coverband-access.umaxica.dev`

The Access configuration change updates the six `PUBLIC_*_URL` entries in
`.env.container.devcontainer` and their public-host network aliases in `.devcontainer/compose.yaml`.
The existing `PRIVATE_*_URL` values and internal aliases for the six retained tools are kept;
Performance is no longer an Access application surface. Existing operator authentication remains
required. Container recreation is needed to apply these environment and network changes;
configuration edits do not establish live reachability.

Follow up in Governance, Sphere and Press before exposing their operator tools:

- Use the repository-specific hostnames the owner decided on 2026-11-09 (table below); do not copy
  Access's hostnames or reuse the original unsuffixed names.
- Apply the corresponding public environment settings and Compose aliases in each repository.
- Reconcile route comments and current operator documentation with the selected names.
- Plan each tunnel's ingress, DNS and Cloudflare Access applications for those names, retaining
  origin authentication. Obtain approval before external changes.
- Recreate the affected containers after active tests finish, then verify host admission,
  unauthenticated refusal and authenticated access for every retained tool.

This note records follow-up work; it does not claim changes in the other repositories, container
recreation, or Cloudflare configuration have been completed.

### Operator hostnames for every repository (decided 2026-11-09)

| Repository | Operator hostname pattern       | Example                          |
| ---------- | ------------------------------- | -------------------------------- |
| Access     | `<tool>-access.umaxica.dev`     | `mission-access.umaxica.dev`     |
| Governance | `<tool>-governance.umaxica.dev` | `mission-governance.umaxica.dev` |
| Press      | `<tool>-press.umaxica.dev`      | `mission-press.umaxica.dev`      |
| Sphere     | `<tool>-sphere-jp.umaxica.dev`  | `mission-sphere-jp.umaxica.dev`  |

`<tool>` is one of `mission`, `flipper`, `blazer`, `pghero`, `swagger`, `performance` and
`coverband`. This is a cross-repository naming set; each repository uses only the operator tools it
owns. Access retired its Performance surface on 2026-11-10. Each name is one label under
`umaxica.dev`, so Cloudflare's Universal SSL certificate for `*.umaxica.dev` covers it without an
extra certificate. Sphere includes its region, matching its tunnel name (`sphere-jp-dev`), so later
regions such as `us` do not collide.

## Cloudflare State After the Split (2026-11-09)

The owner had Claude apply the Cloudflare side through the Cloudflare API MCP server, one step at a
time with approval, reading each change back. Access protection was configured before DNS for every
new hostname. Tunnel tokens were never printed or recorded; the owner copied each into the
repository's `.env`.

| Repository | Tunnel (ID)                                               | Hostnames → origin                                                                                                   | Access application                     |
| ---------- | --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| Access     | `Auth` (`1d501e9a-62f7-4c0d-ba5e-a26e3f10088f`), existing | `visa`/`auth` `.umaxica.app`/`.org` → `visa`/`auth` `.{app,org}.localhost`; `<tool>-access.umaxica.dev`              | `access-dev`; tools in `dashboard`     |
| Governance | `governance-dev` (`fed9d611-67fb-42c4-afb8-cadc6c251878`) | `www.umaxica.{app,org,com,dev}` → `base.*.localhost`; `tech.umaxica.org` → `tech.org.localhost`; `<tool>-governance` | `governance-dev`; tools in `dashboard` |
| Press      | `press-dev` (`142819c4-75c1-4cb0-8cdd-9d7f81fbafe7`)      | `edit.umaxica.org` → `edit.org.localhost`; `<tool>-press.umaxica.dev`                                                | `press-dev`; tools in `dashboard`      |
| Sphere     | `sphere-jp-dev` (`e5acbb34-4efe-4f31-9fbb-82e91e0a26bd`)  | `www-jp.umaxica.{app,com,org}` → `warp.*.localhost`; `<tool>-sphere-jp.umaxica.dev`                                  | `sphere-jp-dev`; tools in `dashboard`  |

- Every tool hostname routes to `http://<tool>.core.dev.localhost:3000`. Every tunnel ends with an
  `http_status:404` catch-all (Auth's was `http_status:300` before).
- All DNS records are proxied CNAMEs to `<tunnel id>.cfargotunnel.com`. `www`, `www-jp` and `edit`
  were repointed from `Auth`; the others were created.
- Every Access application uses the reusable `dev` policy, which now allows only the owner's two
  email addresses. It previously included anyone authenticated by password or one-time PIN, which
  denied the owner in practice. After this change no tunnel hostname is outside an Access
  application.
- `www-jp` is Warp, not Core. Core and Palm had no published hostname on any tunnel; the
  `jp.umaxica.app` path route is recorded in Sphere's
  `docs/backlog/2026-11-09-core-jp-app-path-route.md`.
- Workers VPC (`umaxica-dev-workers-vpc`) was not changed.

### Open After This Step

- Connectors: until Governance, Press and Sphere recreate `cloudflare-tunnel`, their running
  connectors still carry the old `Auth` token (four connectors on `Auth`), and Governance and Sphere
  still run Workers VPC connectors removed from their Compose files. Verify one connector per tunnel
  after recreation.
- Repository configuration for the tool hostnames (Compose aliases and `PUBLIC_*_URL`) is done in
  Access and Press (Press's `.devcontainer` patch is still unapplied) and pending in Governance and
  Sphere.
- Cleaned up with owner approval (2026-11-09): the seven unsuffixed tool DNS records and their
  `dashboard` destinations; `us.umaxica.{app,com,org}` and the stopped `Edge` tunnel;
  `wide-jp.umaxica.org` (a former Warp name). Kept: the stopped `DEV-MP4-EDGE` tunnel and its
  records (`info`, `docs-jp`, `help-jp`, `news-jp`, `umaxica.dev`, `umaxica.net`), which the owner
  reports are served by Press's Workers VPC path.
- Visa is behind Access. Server-to-server OIDC calls through the public hostname will be refused; a
  bypass for the protocol endpoints or a service token is needed before testing RP and OP through
  the tunnel.
- The MCP connection holds DNS, Access and Tunnel write scopes; revoke or reduce it when this work
  ends.

### Access Policies: `surface-gate` and `dev` (2026-11-09, later the same day)

The owner reversed the blanket protection above for the public surfaces:

- `surface-gate` (reusable policy `a9d526d4-3cdd-4794-ac7c-322298a7890f`) is attached to every
  `app`, `com` and `org` Access application: `access-dev`, `governance-dev`, `sphere-jp-dev`,
  `press-dev`, `info`, `help-jp`, `news-jp` and `docs-jp`. Normally it is **Bypass / Everyone**, so
  these hosts are public again and server-to-server OIDC calls (Discovery, JWKS, token, userinfo,
  revocation, and RP JWKS) pass without Access. `info`, `help-jp`, `news-jp` and `docs-jp` were in
  practice locked before this change and became public with it.
- `dev` (owner's two email addresses) stays only on `dashboard`, the `.dev` operator tools.
- The name carries no environment so the same policy can exist in staging and production accounts.

**To lock every public surface at once:** edit `surface-gate` to Action **Allow**, Include
**Emails** (the owner's addresses). This also stops RP and OP server-to-server calls, so RP sign-in
fails while locked. To unlock, set it back to **Bypass / Everyone**.

### Sphere hostnames renamed (2026-11-10)

Per `adr/cosmos-sphere-surfaces-and-rp-independence.md` (amendment 2026-11-10), the `sphere-jp-dev`
tunnel now serves: `www-jp.umaxica.{app,com,org}` -> Core (`core.*.localhost`, with the Core path
rule `^/((api/v0|oidc|sign)(/.*)?|\.well-known/jwks\.json|csp-violation-report)$`);
`warp-jp.umaxica.{app,com,org}` -> Warp (`warp.*.localhost`); `palm-jp.umaxica.app` -> Palm
(`palm.app.localhost`). DNS records for `warp-jp` and `palm-jp` were created; interim
`warp.umaxica.{app,com,org}` and `palm.umaxica.app` records made in the dashboard earlier that day
were deleted. The `sphere-jp-dev` Access application and the `sphere-development-*` Turnstile
widgets list exactly the seven new hostnames. Sphere and Access configuration must follow (Codex
work orders in the conversation).

Sphere `.com` removed (2026-11-10): `www-jp.umaxica.com` and `warp-jp.umaxica.com` were taken off
the `sphere-jp-dev` tunnel, DNS, Access and Turnstile (owner decision; Sphere backlog
`docs/backlog/2026-11-10-sphere-has-no-com.md`).

## Mock OIDC probe tunnel (2026-11-11)

Created through the Cloudflare API for `umaxica-apps-mock-oidc`
(`specs/cosmos-cross-repository-connection/spec.md`, Development Approach, phase 2). Temporary:
remove the tunnel, DNS record and Access application once the probe's goal is reached.

- Tunnel `mock-oidc-dev` (`4a4d4972-b881-4de0-a3e3-75f241c44139`), remotely managed; ingress
  `mock.umaxica.app` -> `http://localhost:4100`, otherwise 404. The connector runs next to the probe
  on the development host. Its token was not read or recorded.
- DNS: `mock.umaxica.app` CNAME to the tunnel, proxied (record `98ce7dda5a9811f3c1939525fdb3fbd3`).
- Access application `mock-oidc-dev` (`ce8ee23a-ab98-4aa0-8e5c-c606f6bcf8c2`) with the reusable
  `surface-gate` policy (Bypass today). If `surface-gate` is locked to an allow list, Access's
  back-channel logout POST to the probe will be refused; add a service-token or bypass rule for that
  path before locking it.
