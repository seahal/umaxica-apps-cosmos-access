# OIDC Authorization Code Only: Implicit and Hybrid Flow Non-Adoption

## Status

**Accepted (2026-10-24); amended by owner (2026-11-14).** This record extends the flow selection in
[OIDC Authorization Request Profile](oidc-authorization-request-profile.md), without superseding its
redirect, error, or registration contracts. The 2026-11-14 amendment authorizes a single first-party
exception for `base-app-ww` and `base-org-ww`; every other client remains on Code with PKCE S256.

**Amended 2026-11-14 (owner): first-party Base front-channel ID Token profile.** During sign-up and
sign-in, no server-side call between applications is allowed except reading the peer's published
JWKS. The Token Endpoint call at the end of the code flow is such a call, so the first-party Base
relying parties (`base-app-ww`, `base-org-ww`) stop using it for sign-up and sign-in:

- These two clients use `response_type=id_token`, without an Access Token or Refresh Token. The OP
  returns the ID Token to the registered `redirect_uri` through Jump as a GET query parameter, with
  `state` and `iss`. This is a UMAXICA first-party profile. The default response mode for `id_token`
  is the fragment encoding; `form_post` is a separately specified response mode, not a default. The
  query-mode implementation departs from OAuth 2.0 Multiple Response Type Encoding Practices §3,
  which says: “the query encoding MUST NOT be used.” This deviation is deliberate and must retain
  the mitigations below. See
  [Multiple Response Type Encoding Practices, §3](https://openid.net/specs/oauth-v2-multiple-response-types-1_0.html#id_token)
  and
  [OAuth 2.0 Form Post Response Mode](https://openid.net/specs/oauth-v2-form-post-response-mode-1_0.html).
- Mitigations: ID Token lifetime of at most 2 minutes; single-use `jti` consumed by the RP; `nonce`
  and the RP's signed, browser-bound `state` replace PKCE; claims limited to `iss`, `sub`, `aud`,
  `exp`, `iat`, `auth_time`, `nonce`, `jti`, `sid`, `acr`, `amr` (no personal data); the RP removes
  the token from the URL with 303 at once; `Cache-Control: no-store` and
  `Referrer-Policy: no-referrer` on every response that carries it; never logged. The size of the
  whole redirect must fit Jump's destination limit (2048 characters), measured, not estimated.
- The Base RP session is renewed by passing through the OP again (`prompt=none`), not by a Refresh
  Token.
- `sid` (owner, 2026-11-14) is the OP session identifier: opaque, random, no personal data. The RP
  binds its session to it (`rp_op_session_bindings`) so that OIDC Back-Channel Logout can revoke
  exactly the RP sessions of one OP session (one device), and so that per-device session limits can
  key on it later. It is required in the ID Token of this profile. Carrying it is not a server-side
  lookup and does not conflict with the JWKS-only rule for sign-up and sign-in.
- Authority for Base API calls after sign-in (owner, 2026-11-14): those APIs belong to Governance,
  not Access. Governance issues its own short-lived PS256 token from the RP session; Access issues
  nothing further. Recorded in Governance `adr/base-api-authority-governance-issued-token.md`.
- D1 to D3 and the Invariants below stay in force for every other client. Native, MCP and future
  external clients keep Authorization Code with PKCE S256 and the Token Endpoint. Discovery keeps
  advertising `code` only; the first-party profile is enforced by client registration and is not
  advertised.
- `id_token token`, every Hybrid response type, and a front-channel Access Token remain excluded for
  all clients.

## Context

UMAXICA's registered clients use Authorization Code Flow with PKCE S256 except for the two named
Base clients under the 2026-11-14 first-party amendment. Code with PKCE remains the default profile
and meets the requirements of every other client. The existing authorization request ADR owns
request-validation and error contracts; this record owns the flow rationale and the conditions for
reconsidering the non-adoption decisions.

The implementation anchors inspected for this profile include:

- `app/values/oidc_discovery_document.rb` advertises only `response_types_supported: ["code"]` and
  `code_challenge_methods_supported: ["S256"]`.
- `app/resolvers/oidc_authorize_request_resolver.rb` accepts `id_token` without PKCE only when the
  client registry selects the Base profile; all Code clients require S256 and a challenge. Both
  profiles validate the registered redirect URI, `state`, and `nonce`.
- `app/services/oidc_authorize_coordinator.rb` coordinates authorization-code issuance;
  `app/services/oidc_token_exchange_coordinator.rb` validates the code's client, redirect URI, and
  PKCE binding before issuing tokens.
- `app/values/oidc_client_registry.rb` owns registered clients and realm-specific redirect URIs. RP
  initiation in `app/controllers/concerns/oidc_sso_initiator.rb` selects Code with S256;
  `app/controllers/concerns/oidc_callback.rb` exchanges the code and validates the returned tokens,
  using the OP token verifiers and `app/values/oidc_pkce.rb` on the relevant boundaries.

Related authorize, token-exchange, and callback tests were inspected, not executed. These are static
observations of a worktree with existing uncommitted changes, not runtime or deployment acceptance.
The front-channel implementation and its tests are tracked separately from this protocol decision.

## Decision

### D1. Authorization Code Flow with PKCE S256

Every client other than the two registered first-party Base clients MUST use `response_type=code`
with PKCE `code_challenge_method=S256`, including confidential clients. For those clients, the
authorization response carries the code and applicable protocol metadata, including `state` and
`iss`; ID Tokens and Access Tokens are issued through the Token Endpoint after successful code
exchange.

`base-app-ww` and `base-org-ww` MUST use `response_type=id_token` without PKCE and MUST NOT use the
Token Endpoint for sign-in or sign-up. Their ID Token response uses the registered redirect URI
through Jump as a query-encoded GET response with `state` and `iss`, under the mitigations in the
2026-11-14 amendment. These clients MUST NOT fall back to Code during a dual period.

Existing `state`, `nonce`, issuer, audience, signature, client, exact registered redirect URI,
transaction binding, and token validation requirements remain in force. PKCE supplements those
controls; it does not replace them.

### D2. Implicit Flow non-adoption

`id_token` is excluded for every client except `base-app-ww` and `base-org-ww` when registered with
the first-party Base profile. `id_token token` is excluded for every client.

### D3. Hybrid Flow non-adoption

The supported response-type set excludes `code id_token`, `code token`, and `code id_token token`,
including equivalent orderings of those response-type combinations.

## Rationale

### Authorization Code Flow with PKCE

Code with PKCE satisfies the needs of non-Base clients while keeping token delivery at the Token
Endpoint. RFC 7636 §§4.2–4.6 defines challenge/verifier binding: S256-capable clients MUST use S256;
servers MUST implement S256, and verifier mismatch MUST yield `invalid_grant`.

RFC 9700 §2.1.1 requires public clients to use PKCE and authorization servers to support and enforce
it, including downgrade protection. PKCE is RECOMMENDED for confidential clients; with precautions,
they MAY instead use OIDC nonce. Non-verifier-exposing challenge methods are a SHOULD, currently met
by S256. Requiring PKCE S256 for every client is UMAXICA's stricter profile choice.

### Implicit Flow non-adoption

Code with PKCE already meets current requirements, so another authentication path has no present
benefit. Avoiding unused front-channel token delivery limits attack surface and verification work.

RFC 9700 §2.1.2 advises clients SHOULD NOT use authorization responses carrying Access Tokens unless
specified injection and leakage risks are mitigated, and SHOULD prefer token-endpoint delivery. Its
Access Token leakage/replay rationale applies to `id_token token`; `id_token` alone issues no Access
Token. Excluding the latter is UMAXICA's scope decision, not that Access Token warning. PKCE
protects code exchange; it neither directly protects Implicit Flow nor technically replaces it.

### Hybrid Flow non-adoption

The Base exception is limited to its accepted first-party sign-in/sign-up use. It does not enable a
front-channel Access Token or Hybrid response. OIDC Core §3.3 requires `c_hash` when an
authorization-endpoint ID Token accompanies a code, and `at_hash` when it also accompanies an Access
Token, with corresponding validation.

Hybrid remains a formally defined OIDC flow. RFC 9700 §2.1.2 explicitly allows `code id_token` as an
example of token-endpoint Access Token delivery. Neither that RFC nor PKCE invalidates Hybrid as a
whole. Its exclusion here is a deliberate UMAXICA use-case choice.

## Alternatives Considered

- Add Implicit Flow for browser clients: current Code/S256 support meets their requirements.
- Add Hybrid Flow for early identity information: no current requirement justifies the additional
  token paths and integrity checks.
- Advertise the Base profile as generally supported: the exception remains limited to the two
  explicitly registered Base clients.

## Consequences

The profile keeps Code with S256 for all clients except the two named Base registrations. Other
clients requiring Implicit or Hybrid cannot integrate; they must use Code with S256 or await a
separate accepted decision. Back-Channel Logout, Dynamic Client Registration, and Pairwise Subject
Identifiers are outside scope.

## Invariants

- Discovery MUST retain `response_types_supported: ["code"]` and
  `code_challenge_methods_supported: ["S256"]`.
- Authorization request handling MUST accept only `response_type=id_token` without PKCE for the
  registered Base clients, and only `response_type=code` with PKCE S256 for every other client.
- Base authorization responses MUST contain only the ID Token and required protocol metadata; Access
  Tokens and Hybrid responses remain excluded.
- Every non-Base authorization response MUST deliver neither ID Tokens nor Access Tokens directly.
- Non-Base token issuance MUST follow code exchange at the Token Endpoint with successful PKCE and
  existing client/redirect binding validation. Base sign-in and sign-up MUST NOT call the Token
  Endpoint.
- Existing Authorization Code, Token Endpoint, Refresh Token, UserInfo, and Logout behavior and
  security controls remain unchanged. Refresh Token use is not an additional authentication flow.
- Admission of an external RP MUST preserve this profile unless a new accepted ADR changes it.

## Reconsideration Criteria

A new accepted ADR is required before adding a flow. It must evaluate a concrete use case unmet by
Code/S256, security requirements and threats, interoperability, and the additional validation,
testing, and operational burden. External RP admission alone does not reopen this decision.

## Related ADRs

- [OIDC Authorization Request Profile](oidc-authorization-request-profile.md): extended, not
  superseded; remains the owner of request-validation and error contracts.
- [Base/Auth ceremony and first-party RP boundary](base-auth-ceremony-and-seven-rp-boundary.md):
  preserves trust and state boundaries, including its recorded amendments.
- [OP/Auth/RP responsibility separation](op-auth-rp-authentication-responsibility-separation.md):
  authority placement evolves independently of the supported OIDC flow.
- [OIDC Claims Decision](oidc-claims-decision.md): preserves claims and token validation decisions;
  this record concerns flow selection, not a claims reconciliation.
- [OIDC RP Scope](oidc-rp-scope-umaxica-tlds-only.md): preserves current RP admission restrictions;
  future admission and flow expansion are separate decisions.
- [RP OIDC State and Return Target](rp-oidc-state-and-return-target.md): preserves RP transaction
  and return-target binding.

## References

- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0-final.html): §3.1
  Authorization Code, §3.2 Implicit, §3.3 Hybrid; especially §§3.3.2.11–3.3.2.12 for hash checks.
- [RFC 7636 — Proof Key for Code Exchange](https://www.rfc-editor.org/rfc/rfc7636): §§4.2–4.6.
- [RFC 9700 — OAuth 2.0 Security Best Current Practice](https://www.rfc-editor.org/rfc/rfc9700):
  §§2.1.1–2.1.2.
