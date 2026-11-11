# Access <-> Governance Service Communication: Options Considered (2026-11-12)

Status: research note, non-normative. No option is chosen; the owner will decide later. Decided
context lives in `adr/access-is-a-pure-openid-provider.md` (decisions 8, 11 to 13 and 16): Access
and Governance exchange data only over public HTTPS, share no database or private network, share
only each other's JWKS, and Governance's silence means no new sign-in, sign-up or step-up.

## The exchanges

| Exchange                                                   | Direction            | Needs                                      |
| ---------------------------------------------------------- | -------------------- | ------------------------------------------ |
| Credential lookup and current permission during a ceremony | Access -> Governance | synchronous answer                         |
| Credential registration after a ceremony                   | Access -> Governance | confirmed storage                          |
| Revocation commands (forced sign-out, disable, delete)     | Governance -> Access | confirmed execution, visible in Governance |

What each request must prove: sender identity, integrity, freshness (no replay) and intended
recipient; responses likewise.

## Service authentication options

| Option                                   | Summary                                                                                                                                                                                                  | Notes                                                                                                                                                                       |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A. Signed request JWT                    | request body is a JWS signed with a dedicated Access key; Governance verifies with Access's JWKS; `iss`, `aud`, short `exp`, `jti` stored in PostgreSQL, method/URL bound; responses signed the same way | no shared secret; reuses `jwt`, JWKS and consumed-`jti` tables; same idea as `private_key_jwt` (RFC 7523)                                                                   |
| B. OAuth client credentials              | Access presents an access token to Governance                                                                                                                                                            | Access is the authorization server, so it would issue tokens to itself; integrity needs separate handling                                                                   |
| C. HTTP Message Signatures (RFC 9421)    | signatures over method, path and body digest                                                                                                                                                             | standard fit; few Ruby libraries                                                                                                                                            |
| D. mTLS (RFC 8705)                       | client certificates at the TLS layer                                                                                                                                                                     | certificate issuance and rotation cost                                                                                                                                      |
| E. Shared secret (HMAC, API key)         | both sides hold the same secret                                                                                                                                                                          | not recommended: one leak forces both sides to rotate (cf. the 2026-11-11 exposure)                                                                                         |
| Interim: Cloudflare Access service token | only requests carrying the token reach the internal paths; no application code in Governance                                                                                                             | gate only, no integrity or replay protection; needs a recorded exit condition and must not reach production                                                                 |
| No authentication at first               | add later                                                                                                                                                                                                | rejected for now: the development tunnels are public and `surface-gate` is Bypass, so anyone could enumerate accounts, add a passkey to another account, or force sign-outs |

## Transport and style options

| Option                                  | Notes                                                                                                                                                                                                                                                                                                                                                             |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| HTTPS + JSON (JWS), contract in OpenAPI | fits existing `OutboundHttp` (Faraday), JWT/JWKS, `openapi/`, rswag and `docs/reference/api-design-standards.md`                                                                                                                                                                                                                                                  |
| gRPC                                    | typed contracts and built-in deadlines; does not solve authentication or signed acknowledgements; Ruby `grpc` is heavy and usually needs a separate server process; end-to-end HTTP/2 through Cloudflare Tunnel needs checking; low call volume gives little speed benefit                                                                                        |
| Webhooks                                | natural for Governance -> Access events (revocation is effectively a webhook); not suited to the synchronous lookup unless Access keeps a copy of Governance data, which conflicts with "Access holds no data" and fail-closed. **Standard Webhooks** (`webhook-id`, `webhook-timestamp`, `webhook-signature`, HMAC or Ed25519) offers a ready signing convention |

## Standards-based shape (owner found the custom shapes inelegant)

| Exchange                                   | Standard                                                                                                                                     | Roles                                                                |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| "May this person proceed now?"             | OpenID AuthZEN Authorization API                                                                                                             | Access = PEP, Governance = PDP (matches the 2026-11-11 consultation) |
| Revocation and account events              | OpenID Shared Signals Framework with CAEP (`session-revoked`, `credential-change`, ...) and RISC (`account-disabled`, `account-purged`, ...) | Governance = transmitter, Access = receiver                          |
| Event envelope and delivery                | Security Event Token (RFC 8417), push delivery (RFC 8935, HTTP 202 on acceptance)                                                            | both directions                                                      |
| Credential records (public keys and links) | not covered by AuthZEN; candidates: AuthZEN response context, or SCIM (RFC 7643, 7644) reads                                                 | open                                                                 |

Appeal: signing, unique IDs, freshness, audience and delivery acknowledgement come from the
standards instead of custom rules; event names exist; everything rests on JWT and JWKS, aligned with
the OIDC/OAuth/FAPI target. Caveats: these standards are recent, Ruby libraries are scarce, and the
versions and event types above were written from memory and must be checked against the
specifications before adoption.

## Open

- Which service authentication (A to D, or a standards-defined profile) and whether an interim gate
  is used, with its exit condition.
- Whether to adopt AuthZEN and SSF/CAEP/RISC, and how credential records are retrieved.
- Contract details: endpoints, fields, errors, timeouts, retries, audit.
