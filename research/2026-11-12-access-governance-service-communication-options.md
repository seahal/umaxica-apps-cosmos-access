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

## Private network option (added 2026-11-12; transport is TBC)

The owner raised connecting Access and Governance over a private network (a shared VPC, VPC peering,
or a Cloudflare private route such as the existing Workers VPC tunnel) because the exchanges are a
lot of work. Status: **to be confirmed**; nothing is decided.

- What it reduces: the APIs are not reachable from the internet, so the outer defence comes from the
  network; lighter service authentication (mTLS, short-lived tokens) becomes adequate; an interim
  Cloudflare service token is unnecessary.
- What it does not reduce: caller authentication is still needed (a compromised neighbour on the same
  network could call); the four exchanges, the data ownership split and "success only after a
  confirmed acknowledgement" stay the same.
- Constraints: Access's ADR decisions 8 and 12 say the two share no private network; adopting this
  requires amending them. Feasible only if both run where a private network can join them (same
  cloud and region set); distant regions make it harder. Development needs the two environments
  joined on one network.

## External guidance: loosely coupled two-app integration (added 2026-11-13; reference only)

The owner supplied an implementation guideline from another assistant as a reference. Nothing below
is decided; it records how each point fits the decisions above and the repository.

Fits as written:

- No shared database, no shared domain gem, no direct enqueue into the other app's queue, no
  synchronous call cycles, no distributed transactions, one owner per datum (matches ADR decisions
  17 to 19).
- Transactional outbox on the sender; inbox table with a unique `event_id` on the receiver; fact-only
  minimal events, never ActiveRecord dumps; tolerant reader; additive-only changes and a new
  versioned event type for breaking changes. Access already runs outbox tables (`*_audit_outbox`,
  `chronicle_outbox_entry`) and Solid Queue, so the relay job needs no new infrastructure.
- Synchronous API hygiene: `/api/v1`, fixed serializers, RFC 9457 errors, paginated lists,
  `Idempotency-Key` on creating POSTs, one client class per peer with Faraday timeouts, retries only
  for idempotent requests, a circuit breaker, responses converted to POROs. Matches `OutboundHttp`
  and `docs/reference/api-design-standards.md`.
- Short-lived JWT access tokens verified locally against a cached JWKS (refetch on unknown `kid`),
  mandatory `aud`, 401 with `WWW-Authenticate: Bearer` / 403 for missing scope, audit `sub` and
  `jti` rather than the token, about 30 s leeway, one client per service and environment, and
  `X-Request-ID` propagation with OpenTelemetry. The test list (no token, wrong scope, wrong `aud`,
  expired; token reuse; single refetch after 401; duplicate delivery processed once; schema checks in
  both CIs) is usable as an acceptance draft; cross-repository checks belong in
  `umaxica-qa-test-integration`.

Needs adapting:

| Guideline point                                       | Repository position                                                                                                                                                                                               |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Broker: Kafka, SNS+SQS or RabbitMQ                    | none is present; no broker gem in either `Gemfile.lock`. Existing base is PostgreSQL + Solid Queue; outbox relay could push over HTTPS (SET push delivery, RFC 8935) without a broker. Broker choice stays open |
| Sidekiq                                               | not used; Solid Queue                                                                                                                                                                                             |
| Doorkeeper in one business app as the AS              | Access is already the OP, so the AS role belongs to Access; no Doorkeeper. Business apps never issue tokens to each other (agrees with the guideline's preferred option)                                           |
| `client_secret_basic`, `private_key_jwt` later        | the OIDC/FAPI target and the 2026-11-11 secret exposure favour `private_key_jwt` (RFC 7523) from the start; no shared secrets (option E above is already "not recommended")                                       |
| RS256                                                 | the FAPI 2.0 target uses PS256 or ES256                                                                                                                                                                           |
| Local projection and eventual consistency everywhere  | Access is fail-closed: a ceremony needs Governance's current answer, and Access holds OP data only. A local copy of Governance permission data in Access conflicts with that; revocation must be confirmed      |
| Access calling itself for tokens (option B above)     | when Access is the caller, it would obtain a token from itself; the guideline's model assumes a separate AS. Governance -> Access calls fit it directly                                                          |

Open questions the guideline also leaves to the owner: broker or HTTPS push; event list and owners
(the three exchanges above are the starting list); scope names and `aud` values; which exchanges
truly need a synchronous answer (credential lookup during a ceremony does; revocation could be an
event with a confirmed acknowledgement); and the transport question in the previous section.

## Decision recorded (2026-11-13)

The owner chose plain HTTPS request/response with no message broker: the work is mostly synchronous
and not streaming, and a broker adds infrastructure without benefit for one peer and a few exchanges.
Events are pushed over HTTPS from an outbox (Solid Queue relay) with a confirmed acknowledgement. The
broker rows in the guideline section above are therefore closed. Still open: network path (public or
private), service authentication, scopes and `aud` values. Recorded in Access ADR decision 18.

## Decision changed (2026-11-13, later)

The owner rejected server-to-server calls between Access and Governance altogether. Exchanges move
to the front channel: signed handoff JWS carried by the browser through the Jump gateway. This
supersedes the HTTPS decision above. See ADR decision 18 and
`plans/2026-11-13-jump-front-channel-handoff-work-order.md`. Open: revocation without a browser,
peer key distribution, query-string size.
