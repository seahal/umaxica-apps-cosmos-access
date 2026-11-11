# Step-Up Ceremony Delegation

## Current Access boundary

Auth APP and ORG own credential-ceremony continuity. A successful Auth ceremony is evidence only;
Auth does not create a general login session or decide freshness for an external relying party. Visa
APP and ORG own the local OpenID Provider session and protocol authority. Any Visa-owned operation
that accepts ceremony evidence must validate the bound request and current authority before
committing its result.

Access has no local Base or other Browser RP surface to issue session-bound admissions, receive RP
results, update RP session freshness, or protect RP settings mutations. External RP owners decide
whether a step-up is required for their session and operation, and they must consume evidence
through their own policy and persistence boundary. Visa's registered clients remain available; their
local step-up behavior is outside this repository.

Persisted step-up-related models and migrations remain in place for the separate model/database
inventory. Their presence does not establish an active local Base/RP writer. The former Base-led
delegation flow and its detailed registration rules are historical and are preserved in the
[Base/Auth boundary decision](../../adr/base-auth-ceremony-and-seven-rp-boundary.md).

## Security requirements

- Credential registration is not step-up freshness. A newly registered credential must not silently
  satisfy a later sensitive operation.
- Ceremony evidence must remain bound to the intended actor, browser, surface, purpose, and
  destination wherever a current Auth/Visa flow uses it.
- A redirect or return target is not proof that step-up succeeded.
- The authority that owns the affected session rechecks the credential and current policy before
  committing freshness or allowing the protected operation.
