# Health Endpoints

The Health service layer is exposed on the retained Auth APP/ORG and Visa APP/ORG hosts. Route
constraints keep each response in its own host and namespace. Operator tools are outside this
product health contract.

## Text probes

Responses use `text/plain; charset=utf-8`, `Cache-Control: no-store`, and no redirect,
authentication challenge, `.txt` suffix, JSON, or HTML fallback.

- `GET /health` — aggregate with seven fixed lines: title, namespace, status, startup, liveness,
  readiness, and UTC timestamp.
- `GET /health/startup`, `/health/liveness`, `/health/readiness` — `ok\n` with HTTP 200 when
  healthy; `unavailable\n` with HTTP 503 otherwise.

## Machine JSON

When the request accepts JSON, `GET /api/v0/health.json` returns the aggregate status, three check
results, host-local namespace, and an RFC 3339 UTC timestamp. `pass` and `warn` return HTTP 200;
`fail` returns HTTP 503. Liveness remains dependency-free and independent of readiness.

`GET /api/v0/revision.json` returns the nullable deployment revision and render timestamp. A
non-JSON `Accept` receives HTTP 406; the response remains `no-store`.

Example namespace value:

```json
{
  "status": "pass",
  "checks": {
    "startup": { "status": "pass" },
    "liveness": { "status": "pass" },
    "readiness": { "status": "pass" }
  },
  "namespace": "auth/app",
  "timestamp": "2026-11-10T12:00:00Z"
}
```

The `Health::CheckResult` owns serialization and the 200/503 decision. No dependency name,
exception, request path, or environment value crosses the public JSON boundary.

## Revision and caching

`GET /revision` renders title, revision, and timestamp lines. Both revision formats derive the
nullable revision from `Rails.application.revision`; neither endpoint fabricates a value. Health and
revision responses use `Cache-Control: no-store` because each is a verdict about one instance at one
instant.

Public traffic blocking for health endpoints belongs to the separately configured edge boundary. See
[Health Check Endpoints](../operations/health-check.md) and the accepted
[`internal health isolation` decision](../../adr/internal-health-endpoint-edge-isolation.md).
