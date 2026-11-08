# Cosmos Identity Owns Authentication; Cosmos Global Owns Authorization (2026-11-08)

## Status

Accepted (2026-11-08), architecture only. Implementation, migration order and the open questions
below are not decided by this record.

This record changes the repository topology described in
`adr/split-into-regional-and-global-repos.md` (one global repository combining identity provider and
relying parties). Neither that record nor any other existing ADR has been amended yet; reconciling
them is follow-up work.

## Context

The GitHub repositories were renamed from `umaxica-apps-jit-*` to `umaxica-apps-cosmos-*` and a new
repository, `umaxica-apps-cosmos-identity`, was created as a copy of `umaxica-apps-cosmos-global`.
At this decision both repositories contain the same code.

That code combines, in one Rails application, the OpenID Provider (Visa), the credential ceremonies
(Auth), the browser RP and identity/session surface (Base), and the authorization model (policies,
organizations, roles and memberships). Credentials, signing keys and sessions live next to
permission data and policy rules. Changes in one area have repeatedly risked silently breaking a
boundary in another, and the combined surface has become too large to change safely.

`umaxica-apps-cosmos-press` and `umaxica-apps-cosmos-regional` are new, empty repositories for
ordinary end-user services. They need authentication and authorization without carrying either.

Splitting OpenID Connect and OAuth across two servers was considered and rejected: OpenID Connect
sign-in is an OAuth authorization code flow, so the OpenID Provider is necessarily an OAuth
authorization server. A second authorization server would double keys, client registrations, token
endpoints and revocation, and add token-exchange steps in which services can use the wrong token.

## Decision

1. **Identity is the only authorization server.** `umaxica-apps-cosmos-identity` hosts the OpenID
   Provider and all OAuth token issuance: sign-in, MFA, step-up, sessions, credentials, signing
   keys, ID tokens and access tokens. Global does not become an OAuth authorization server.
2. **Identity is the only entry point for services.** Press, Regional and other services are OpenID
   Connect relying parties of Identity and send authorization queries and authorization changes to
   Identity only. They do not call Global.
3. **Identity relays authorization; it does not own it.** For authorization queries and changes,
   Identity authenticates the calling service and user and forwards the request to Global with the
   authentication context: user subject (`sub`), authentication context class (`acr`) and calling
   client (`client_id`). Identity does not interpret permission content, store permission data,
   validate permission changes, or branch on roles. Identity returns Global's answer unchanged.
4. **Global owns authorization.** `umaxica-apps-cosmos-global` owns organizations, memberships,
   roles, permissions, policy rules, authorization decisions, validation of permission changes, and
   the audit records of those changes. Whether a user may change permissions is itself a Global
   decision. The authorization model in the current code moves to Global. Global is an authorization
   decision service (policy decision point), not an OAuth authorization server.
5. **Global's administration screens are an Identity relying party.** Administrators change
   permissions directly in Global's own screens after OpenID Connect sign-in at Identity. These
   changes do not pass through Identity's relay.
6. **Global sets required authentication strength; Identity enforces it alone.** The authentication
   strength each operation requires (for example, a passkey, or re-authentication within a time
   window) is an authorization requirement owned by Global. Global publishes it as a signed
   authentication-requirement policy that Identity loads. At runtime Identity evaluates the loaded
   policy by itself and performs any step-up; Global takes no part in authentication behavior and is
   not called to decide authentication strength. The policy is bounded as follows:
   - **Floors are Identity code.** Identity holds a minimum strength for every operation in code.
     The policy can only raise a requirement above that floor, never lower it.
   - **Scope is limited to strength.** The policy can express only required authentication strength
     per operation. It cannot change clients, redirect URIs, keys, claims, token shape or lifetimes.
   - **Unverified means floor-or-stronger.** Identity loads a policy only after verifying Global's
     signature. When no valid policy is available, Identity keeps the last verified policy or the
     code floors, whichever is stronger, and never runs weaker than the floors.

   A Global compromise can therefore make authentication stricter than necessary, but cannot make it
   weaker than Identity's floors.

7. **The Identity–Global channel is internal.** Global's decision and change interfaces are not
   exposed publicly and accept only authenticated calls from Identity. Identity depends on the
   contract of those interfaces, never on Global's database.
8. **Unavailable Global means deny.** When Global cannot answer an authorization query or change,
   Identity and services fail closed. Authentication does not depend on Global being available
   (decision 6).
9. **Identity serves ceremony screens only.** Identity renders only the screens that must run on its
   own origin: sign-in, MFA, passkey ceremonies, consent, step-up and sign-out. Credentials are
   entered only there, and passkeys are bound to Identity's origin. Identity has no administration
   console and no dashboard. User self-service lists live outside Identity; registering or removing
   a credential redirects to an Identity ceremony and back.
10. **Configuration ownership follows the security boundary.** Roles, permissions, policies, the
    meaning of scopes and the authentication-requirement policy (decision 6) are configured in
    Global's administration screens. OpenID Connect and OAuth configuration (client registrations,
    redirect URIs, client secrets, signing keys, token lifetimes and MFA requirements) is code in
    the Identity repository, reviewed and deployed, and is not writable from Global or from any
    screen. If Global could write redirect URIs, a Global compromise could register an attacker's
    redirect URI and obtain users' tokens.

11. **Identity and Global share no database.** Each owns its databases; neither reads nor writes the
    other's, directly or through a replica. Only four things cross the boundary: the Identity
    subject (`sub`) as the reference to a person, tokens, the internal interfaces of decisions 3, 6
    and 7, and events. Global stores `sub` and no copy of credentials or profile data; display data
    comes from token claims or a read-only Identity interface. Lifecycle changes such as account
    deletion reach Global as events from Identity, and Global cleans up its own records. Audit
    records on both sides carry `sub` and time so they can be correlated without a shared store.

## Open Questions

- Whether access tokens carry coarse permissions obtained from Global at issuance, with fine-grained
  decisions made through the relay (current proposal), and how revocation latency is bounded.
- The service-to-service authentication for the Identity–Global channel (mutual TLS or signed
  service tokens).
- Whether Global holds anything about a person beyond the Identity subject (`sub`).
- The shape of the decision and change interfaces; OpenID AuthZEN Authorization API is the reference
  candidate for decisions.
- Placement of Base, which currently combines authentication screens with post-sign-in dashboards,
  and which application hosts user self-service lists (credentials, sessions).
- How the authentication-requirement policy is distributed (Identity pulls or Global pushes), its
  format, the operation vocabulary shared by both sides, how Identity's floors are expressed, and
  how quickly a raised requirement must take effect.
- How code-managed client registration scales if the number of clients grows beyond a small, known
  set.
- Which current databases (`config/database.yml`) belong to Identity and which to Global, and how
  existing cross-database references and audit (Chronicle) records that span both sides are cut.

## Consequences

- A defect in Global cannot reach credentials, sessions or signing keys; a defect in Identity cannot
  alter permission data except through Global's validated interfaces.
- Services integrate with one endpoint and one token type.
- Every authorization query from a service costs an extra internal hop through Identity; caching and
  coarse token permissions are the mitigations to evaluate.
- Identity's relay must stay thin. Any authorization rule added to Identity reintroduces the
  coupling this record removes.
- The split proceeds by first establishing the boundary inside one application (authorization code
  reaches authentication code only through tokens and the decision interface), then deleting the
  unowned half from each repository, so each step keeps a working application.
