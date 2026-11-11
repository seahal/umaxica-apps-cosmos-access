# Authorization Implementation Guide

This is the current entry point for authorization in the owned Auth APP/ORG and Visa APP/ORG
surfaces. The canonical Action Policy rules, policy patterns, scoping guidance, and failure behavior
are maintained in
[`docs/security/action-policy-conventions.md`](security/action-policy-conventions.md).

## Ownership

- Surface controllers establish their authorization context in the request lifecycle. Authorization
  remains local to the host and surface that owns the request.
- Policies default to deny. Controllers and other callers use the existing policy boundary rather
  than reproducing permission checks in presentation code.
- Visa's external OIDC client registrations do not create local relying-party callbacks, sessions,
  or policies in Access. Each external client owner controls those responsibilities in its own
  repository.
- Mission, Flipper, Blazer, PgHero, Coverband, and Swagger retain their dedicated tool controls in
  their route and engine middleware configuration; they do not inherit Auth/Visa sessions.

Use the current controller and security documentation for code-level behavior. This entry point does
not define routes or add a new authorization abstraction.
