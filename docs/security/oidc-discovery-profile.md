# OIDC Discovery Profile

> **Current scope (2026-11-10):** Visa APP and ORG are the local OpenID Provider and Authorization
> Server surfaces. Auth APP and ORG provide credential ceremonies. External relying-party client
> registrations remain in Visa, but their callbacks, sessions, and browser routes belong to their
> own repositories. Do not infer local RP routes from a registered OIDC client.

Visa (`https://visa.umaxica.app` and `https://visa.umaxica.org`) is the only local IdP /
Authorization Server. External registered clients hold no IdP authority. This document records the
intentional, non-default choices in Visa's published OIDC metadata so reviewers do not mistake them
for gaps. Older Acme vocabulary in cited decisions is retained as protocol history.

Source of truth: `app/values/oidc_discovery_document.rb`, `app/values/oidc_issuer.rb`, and
`app/values/oidc_client_registry.rb`.

Discovery continues to advertise `response_types_supported: ["code"]` and
`code_challenge_methods_supported: ["S256"]`. The two explicitly registered first-party Base clients
(`base-app-ww` and `base-org-ww`) have a separate `response_type=id_token` sign-in/sign-up profile
under the
[accepted amendment](../../adr/oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md).
That registration-scoped exception is intentionally not advertised as a generally supported response
type. Other clients remain on Code with PKCE S256.

## PS256-only ID tokens and client assertions

`id_token_signing_alg_values_supported` and `token_endpoint_auth_signing_alg_values_supported` are
managed separately: ID tokens and token endpoint client assertions each advertise `["PS256"]`. The
OpenID Connect Core conformance profiles expect `RS256` support; Visa **intentionally does not**
offer `RS256`.

Auth access JWTs follow RFC 9068 in token structure, claims, semantics, and validation requirements.
PS256 is the sole supported first-party signing algorithm, using RSA keys of at least 3072 bits.
UMAXICA intentionally does not implement the RFC 9068 §2.1 requirement that conforming authorization
servers and resource servers include RS256 among their supported signature algorithms. PS256 itself
is permitted by RFC 9068; the deviation is the absence of RS256 support. Preference JWTs use a
separate realm shape and keyring; see `adr/preference-realm-jwt-and-host-bound-browser-binding.md`
and `adr/rfc9068-access-token-profile.md`.

This is a deliberate private profile:

- Access signs ID Tokens and outbound client assertions with PS256.
- Access publishes only public RSA PS256 JWKs (`kty=RSA`, `alg=PS256`, `use=sig`).
- Access accepts only PS256 client assertions and requires RSA keys with moduli of at least 3072
  bits. Governance, Sphere and Press now sign PS256 assertions; their signing implementations and
  key material remain with the respective RP owners.

The logout completion URI is not part of discovery. Discovery publishes `end_session_endpoint` on
the matching Visa APP or ORG host. Any registered RP completion URI is validated against that
client's Visa registration and served by the external RP owner.

Access refuses ES384 for first-party ID, access, logout, ceremony and Jump token verification. The
Edge Jump receiver's published contract still specifies ES384; Jump must migrate before live return
tokens interoperate with this Access cut-over. Live verification is currently unavailable while the
deployed Jump JWKS returns 503.

If `RS256` is ever required, it must be implemented end to end (key rotation, JWKS publication, ID
token signing selection, client-assertion verification, and tests) rather than advertised in
metadata alone.

## `ri` is not part of the OIDC contract

`ri` (region identifier, `jp` / `us`; see `app/services/request_context_contract.rb`) is a
localization/preference hint, not an OIDC protocol parameter.

- The discovery endpoint is served by a `BareController` and ignores `ri`.
- `issuer` is always the corresponding APP or ORG Visa origin with no query or fragment, regardless
  of `ri`.
- Advertised endpoints (`authorization_endpoint`, `token_endpoint`, `userinfo_endpoint`, `jwks_uri`,
  `revocation_endpoint`, `end_session_endpoint`) never contain `ri`.
- Key selection is by surface (host), orthogonal to `ri`.

A client may pass `?ri=jp` on requests for UI localization, but the OIDC contract (issuer, endpoint
URLs, key selection) does not depend on it and must never be broken by it.

## UserInfo is a bearer resource

`/oauth/userinfo` authenticates with an OAuth **access token** only:

- No cookie/session fallback.
- ID tokens are not accepted as bearer credentials.
- `openid` scope is required; missing scope yields `403` with
  `WWW-Authenticate: Bearer error="insufficient_scope", scope="openid"`.
- Missing/invalid tokens yield `401` with `WWW-Authenticate: Bearer ...` (RFC 6750 §3).
- Profile claims are scope-gated: `email` / `email_verified` require the `email` scope, `name`
  requires the `profile` scope.

## Signing-key hygiene on public deployments

`JitSecurityJwtRegistry` refuses to publish dev/test/fixture-marked `kid`s outside local Rails
environments (`enforce_public_key_hygiene?`). Development and test may mint local keys; production,
staging, review, and other non-local environments must provide deployable key identifiers. See
`docs/runbooks/jwt-key-rotation.md` for rotation guidance.

## Delivered reconciliation (2026-10-24)

Visa is the active APP/ORG OIDC discovery, authorization, token, UserInfo and logout authority. The
discovery document is generated from the retained client registry and advertises only supported
grant types and endpoints. UserInfo accepts Bearer credentials on GET or POST and applies
scope-filtered claims. External RP return destinations remain registered protocol data, not local
Access routes.
