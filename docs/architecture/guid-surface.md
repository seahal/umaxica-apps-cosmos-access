# GUID Surface Retirement

The GUID service is not a current Access surface after the 2026-11-10 reset. This repository no
longer owns GUID-host routes or controllers. The prior endpoint, host, and deployment description
below has been retired; it must not be used as an Access deployment contract.

GUID remains a domain-level identifier concept described by the
[GUID ADR](../../adr/guid-identifier-surface.md). This notice preserves the documentation target for
older architecture records and evidence without asserting that a resolver is currently served.

No model or migration is removed by this route/controller cleanup. Any retained GUID-related models,
migrations, and database configuration await the separate model/database inventory and follow-up
decision.
