# Health Check Endpoints

The supported product health endpoints are host-constrained on the retained Auth APP/ORG and Visa
APP/ORG surfaces. They are internal checkpoints for orchestrators and monitoring, not a user-facing
availability contract. The operator tools have their own access controls and are not covered by this
surface health contract.

Text probes (`text/plain; charset=utf-8`, `Cache-Control: no-store`):

- `GET /health` — aggregate status for the current Auth or Visa host
- `GET /health/liveness`
- `GET /health/readiness`
- `GET /health/startup`

Machine JSON (`application/json`, `Cache-Control: no-store`, `406` for a non-JSON `Accept`):

- `GET /api/v0/health.json` — status, checks, namespace, and UTC timestamp
- `GET /api/v0/revision.json` — nullable revision and UTC timestamp

Do not point probes at Rails' default `/up` route or at removed Base, COM, Core, Warp, Palm, Edit,
Tech, GUID, content, Performance, or Xper hosts. The old `/health/live` and `/health/ready` paths
remain retired without compatibility routes.

Public edge blocking for operational endpoints is owned by the external edge configuration. It is
not implemented by this document and must be verified against the accepted
[`internal health isolation` decision](../../adr/internal-health-endpoint-edge-isolation.md).

See [Health Endpoints](../reference/health-endpoints.md) for response formats and status semantics.
