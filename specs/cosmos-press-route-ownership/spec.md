# Cosmos Press Route Ownership

Status: accepted (2026-11-08). Implementation is deferred.

The content subdomains `edit`, `info`, `news`, `help` and `docs` belong to
`umaxica-apps-cosmos-press`. This repository will stop drawing them and remove their controllers,
views and tests once nothing else uses that code.

Also decided on 2026-11-09 for all four repositories:

- `guid` is retired; this repository stops drawing it as well.
- This repository keeps and owns its own `.dev` operator tools (`mission`, `flipper`, `blazer`,
  `pghero`, `swagger`, `performance`, `coverband`), served on `<tool>-<repository>.umaxica.dev`
  (Sphere: `<tool>-sphere-jp.umaxica.dev`) as listed in
  `plans/2026-11-08-cloudflare-tunnel-split.md`. Access's settings are the reference for the other
  three repositories.

The full decision, observations, risks, acceptance and order are owned by the Press repository:
`specs/cosmos-press-route-ownership/spec.md` in `seahal/umaxica-apps-cosmos-press`.

Out of scope here: OIDC client registrations and redirect URIs, authentication and authorization
logic, database schemas, existing data and `config/database.yml` connections. Removing the
`publishing` connection is a separate later decision.

## Acceptance

- AC-1: This repository does not draw `edit`, `info`, `news`, `help`, `docs` or `guid`.
- AC-2: The application boots and its remaining test suite passes after the removal.
