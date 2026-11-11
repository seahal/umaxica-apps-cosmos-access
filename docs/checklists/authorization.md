# Authorization

Applies to protected operations on each independently scoped surface.

- AUTHZ-1: Server-side authorization protects mutations regardless of hidden or disabled UI
  controls.
- AUTHZ-2: Resource lookup and authorization preserve the surface, actor and owning organization; an
  identifier from another organization does not gain access through a nested route.
- AUTHZ-3: Published private mutation stubs retain authorization before their response. Existing
  justified association-scoping exceptions remain explicit and bounded.
- AUTHZ-4: A step-up result authorizes only an operation whose explicit purpose, actor, resource,
  tenant, session, transaction, freshness and method requirements it satisfies; an AAL label alone
  does not authorize an operation. Sources:
  [Action Policy conventions](../security/action-policy-conventions.md),
  [authentication contract](../../.agents/harnesses/rules/generic/authentication-boundaries.mdc).
  Owner query mechanics are described in
  [owner record lookups](../security/owner-record-lookups.md). These are required behaviors; their
  presence is not evidence of execution.

- AUTHZ-7: Org legacy organization invitations never infer a Bureau, Unit, Membership or Ownership
  from a legacy organization reference. Until an accepted target and authority migration exists,
  issuance and acceptance refuse without creating principals, memberships or consuming invitations.
  Existing-user participation requires its own authenticated contract. See
  [legacy org invitation admission hold](../architecture/persona-organization-authority.md#legacy-org-invitation-admission-hold).
