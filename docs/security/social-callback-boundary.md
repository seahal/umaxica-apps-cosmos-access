# Social Callback Boundary

Auth APP/ORG routes own social-provider callback verification as part of credential ceremonies. Visa
owns the OIDC transaction and local session/token authority. External relying parties receive Visa's
registered OIDC response and own their callback and local session in their own repositories.

## Callback and ceremony binding

An APP provider-start request records the admitted Auth ceremony identifier only as a callback
correlation value in the Rails session. Before consuming OAuth state, the callback resolves the
current host-only Auth ceremony cookie and requires the same active ceremony row. A mismatch is
refused without consuming state or writing authentication evidence; the correlation value does not
grant admission or select an actor.

For APP registration, a provider POST stores callback state, provider, and the Apple nonce when
applicable. It does not create a sign-up flow or record Auth evidence. A verified callback locks the
Admission Binding and Auth Ceremony, rechecks admission, cancellation, prior flow, and evidence,
then records only the evidence allowed by the current Auth flow. Callback state, provider
assertions, and nonce remain bound to that flow.

For credential linking, the Auth APP route binds the verified provider candidate to the signed-in
current actor and requires the route's CSRF, session, device, and step-up checks. It cannot select
another actor or issue a Visa token. A failed persistence commit cannot be presented as a successful
link.

## Authority

- Auth validates provider callback state, nonce, issuer/subject claims, and ceremony ownership.
- Auth owns only credential evidence and linking operations exposed by retained Auth routes.
- Visa owns OIDC authorization, local sessions, account/token authority, and step-up freshness.
- Each external RP validates Visa's OIDC response and establishes its own browser session.

## Object-level authorization

Provider callback endpoints with no authenticated actor use their explicit authentication mode,
callback-state checks, and admitted flow binding. A credential-link operation is a different
authenticated boundary and authorizes the current actor and candidate before mutation. Do not
combine callback verification and account-link authorization into a route that can act on an
arbitrary actor.

See [Social Login Provider Scope](social-login-provider-scope.md),
[Credential Gateway](credential-gateway.md), and the accepted
[`visa-op-host` decision](../../adr/visa-op-host.md).
