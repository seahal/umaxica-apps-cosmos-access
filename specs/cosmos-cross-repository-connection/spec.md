# Cosmos Cross-Repository Connection

Status: accepted (2026-11-10). Target: working by 2026-11-30 (owner). Owner: Access (OP side);
Governance, Press and Sphere implement the RP side in their own repositories.

## Purpose

The four Cosmos repositories now draw only their own routes. This change makes them work together
again across repository boundaries: an RP in one repository signs users in through Access (Visa and
Auth) with OpenID Connect, using only public HTTPS endpoints and each repository's own keys and
databases. Governance Base App is first; the other RPs follow the same pattern.

## Decisions This Spec Implements

- `adr/cosmos-base-surface-decomposition.md` — First Step: Hard Reset, step 2 (RPs authenticate
  without Access databases, starting with Base App, on the local-cell path).
- `adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md` and its 2026-11-10 amendments — one signing
  key set and one JWKS per repository; tokens state `typ`, `iss`, `aud` and purpose, and verifiers
  check them.
- `adr/cosmos-development-on-vms-with-local-tls.md` — `OutboundHttp::LocalBackChannel` is removed;
  server-to-server calls use public HTTPS everywhere; keys come from credentials, never generated at
  boot.
- `adr/cosmos-outbound-network-access-policy.md` — trusted library, frozen destination allowlist,
  address check, no redirects, no credentials to unintended destinations.
- Access backlog `docs/backlog/2026-11-08-jwt-key-handling-after-cosmos-split.md`, problems 1–3.

## Standards

OIDC and OAuth behavior follows the standards, as decided in
`adr/cosmos-base-surface-decomposition.md` (decision on protocol endpoints). Where this spec and
current code differ from them, move toward the standard; any deliberate departure is recorded in an
ADR (the only one so far is PS256-only signing).

- JWKS documents: RFC 7517; OP metadata: OpenID Connect Discovery 1.0 (`jwks_uri`).
- RP key publication: client metadata `jwks_uri` (OpenID Connect Dynamic Client Registration 1.0,
  RFC 7591), even though clients are registered statically. Several clients of one repository may
  share one `jwks_uri`.
- Client authentication: `private_key_jwt` (OpenID Connect Core 1.0 section 9, RFC 7523): `iss` and
  `sub` equal the `client_id`; `aud` identifies the OP; `jti` is unique and replay is refused; `exp`
  is short.
- Authorization, token, revocation and logout: RFC 6749, OpenID Connect Core 1.0, RFC 7009, OpenID
  Connect RP-Initiated Logout 1.0 and Back-Channel Logout 1.0.
- Security guidance: OAuth 2.0 Security Best Current Practice (RFC 9700).
- Target (2026-11-10): conform to OAuth 2.1, OpenID Connect and the FAPI 2.0 Security Profile
  (`adr/cosmos-base-surface-decomposition.md`, Protocol Target). Choices in this spec should not
  move away from them.

## RP Implementation: A Fork of `openid_connect`, Extended and Proposed Upstream (owner, 2026-11-11)

Available Ruby OIDC client gems cannot meet the target profile as released. `openid_connect` is the
most used Ruby OIDC client library (about 79 million downloads; maintained, 2.5.0 on 2026-06-03,
MIT), so the RP repositories (Governance, Sphere, Press) build on a fork of it and add what is
missing.

Checked on 2026-11-10 against the installed gem sources (`omniauth_openid_connect` 0.8.0,
`openid_connect` 2.5.0, `rack-oauth2` 2.3.0):

| Feature                   | omniauth_openid_connect          | openid_connect                            | rack-oauth2        |
| ------------------------- | -------------------------------- | ----------------------------------------- | ------------------ |
| PKCE (S256)               | yes                              | no                                        | no                 |
| Discovery                 | yes                              | yes                                       | no                 |
| `form_post` response mode | yes                              | no                                        | no                 |
| `private_key_jwt`         | not documented (`basic`, `jwks`) | through rack-oauth2                       | yes (`jwt_bearer`) |
| mTLS                      | no                               | yes                                       | yes                |
| PAR (RFC 9126)            | no                               | no (only the older fetched `request_uri`) | no                 |
| DPoP (RFC 9449)           | no                               | no                                        | no                 |
| Back-Channel Logout       | no                               | no                                        | no                 |
| RP-Initiated Logout       | partial (`end_session_endpoint`) | no                                        | no                 |

No Ruby gem implementing PAR or DPoP was found. The RPs already talk to Visa through their own
adapters (`app/adapters/oidc_op_*`: `private_key_jwt`, PKCE, token, JWKS, ID token, revocation,
back-channel logout) and do not call `OpenIDConnect::` or `Rack::OAuth2` at all; the adapter sets
differ between repositories (Sphere lacks the ID token verifier, Press the userinfo client).

Decisions:

- Order (owner, 2026-11-11): first build a probe RP with `openid-client` (JavaScript, certified FAPI
  2.0 RP) and confirm sign-in against Access step by step; then connect the Rails RPs.
- Direction for the Rails RPs (owner, 2026-11-11; confirmed after the probe works): base the RP
  component on a fork of `openid_connect` (and of `rack-oauth2` where the change belongs there, for
  example DPoP and PAR on the token and authorization requests), replacing the in-house adapters
  where the gem covers the same function. Add PAR, DPoP and Back-Channel Logout in the fork and
  propose each upstream at the same time. Rules:
  - Keep the original MIT `LICENSE` and copyright notices in the fork.
  - Reference the fork from the Gemfile by an exact commit (`git:` with `ref:`), never a moving
    branch.
  - One feature branch and one upstream pull request per feature; keep the fork's difference from
    upstream minimal and rebase it on upstream releases, including security fixes.
  - When upstream releases a feature, switch back to the released gem for it and drop that part of
    the fork.
  - No monkey patches of the gem from application code.
- Until then, one RP component per repository, the same in all three: the existing adapters
  consolidated and the missing ones added.
- Remove from the RPs: `omniauth_openid_connect`, `omniauth`, `omniauth-apple`,
  `omniauth-google-oauth2`, `omniauth-rails_csrf_protection` and the social sign-in code (Apple,
  Google, Entra). Social sign-in runs only in Access ceremonies
  (`adr/access-is-a-pure-openid-provider.md`); Access keeps the gems it needs for that.
- References: RFC 9126 (PAR) https://www.rfc-editor.org/rfc/rfc9126.html, RFC 9449 (DPoP)
  https://www.rfc-editor.org/rfc/rfc9449.html, RFC 7523 (`private_key_jwt`)
  https://www.rfc-editor.org/rfc/rfc7523.html, FAPI 2.0 Security Profile
  https://openid.net/specs/fapi-security-profile-2_0-final.html.

## Scope

In scope:

1. **Every repository:** remove `OutboundHttp::LocalBackChannel` and its callers' URL rewriting;
   load signing keys from development and test credentials (a missing key stops boot; no boot-time
   generation); serve the repository's public keys at `/.well-known/jwks.json` on its hosts; put
   signing behind one signer component so KMS can replace it later.
2. **Access (OP):** client registrations carry each RP repository's `jwks_uri`; verify
   `private_key_jwt` client assertions against keys fetched from that URL (cached, size-limited,
   allowlisted, through `OutboundHttp::Connection`); stop requiring or holding RP private keys.
3. **Governance (first RP):** Base App completes sign-in through Visa and Auth on the local-cell
   path: authorization request, callback, token request with `private_key_jwt`, ID token
   verification against Visa's JWKS, RP session, logout.
4. **Then Press (Edit) and Sphere (Warp, Core, Palm)** with the same pattern.

Target browser model, recorded 2026-11-10 (owner), not implemented by this spec: the browser takes
part only in sign-in, sign-up and sign-out; each RP keeps access and refresh tokens in server-side
storage and gives the browser only an opaque session cookie (a backend-for-frontend design), so DPoP
is not needed for browsers and the browser session is protected by cookie attributes and DBSC. The
current local-cell path stores the Access JWT in a browser cookie (`ACCESS_COOKIE`). That difference
is accepted for now: the repositories first converge on one shared design and branch later.

Out of scope: KMS and PS256 migration (algorithm stays ES384 for now), moving ceremonies from Base
to Auth, account screens, VM migration, preference placement, and Pushed Authorization Requests
(PAR, RFC 9126), which follow as the next stage (see AC-8).

## Prerequisites (operational)

- Each repository's Dev Container recreated so one connector serves each Cloudflare Tunnel.
- Cloudflare Access `surface-gate` unlocked (`plans/2026-11-08-cloudflare-tunnel-split.md`).
- Credential values rotated per repository in one coordinated step across all four repositories
  (`docs/backlog/2026-11-08-github-actions-master-key-rotation.md`, schedule 2026-11-10).
- Other repositories' hostnames removed from each `.devcontainer/compose.yaml` network aliases
  (prepared as a patch by the agent where the directory is read-only; applied by the owner).

## Acceptance

- AC-1: No `LocalBackChannel` remains; outbound calls to another repository use its public HTTPS
  URL.
- AC-2: Restarting any repository does not change its signing keys; a missing key stops boot.
- AC-3: Each repository's `/.well-known/jwks.json` returns only its own public keys, no private
  material.
- AC-4: Access accepts a Governance client assertion signed with Governance's key and refuses one
  signed with any other key, with an unknown `kid`, an expired or replayed assertion, or a wrong
  `aud`, `iss` or `typ`.
- AC-5: Access holds no RP private key.
- AC-6: A browser signs in to Base App (`https://www.umaxica.app/`) through Visa and Auth and signs
  out, with Access and Governance running in separate Dev Containers. Recorded in `evidence/`.
- AC-7: `test/security` passes in each changed repository; static checks pass.
- AC-8: Authorization request and response parameters are audited against OAuth 2.1, OpenID Connect
  Core and FAPI 2.0, on both sides (the RP building the `302` to Visa's `/oauth/authorize`, and Visa
  validating it and redirecting back), and every gap is either fixed or recorded with an owner.
  Checklist (owner, 2026-11-10; must be done even while the flow is broken):
  - request: `response_type=code` only; `client_id`; `redirect_uri` exact match against the
    registration; `scope` contains `openid`; `state`; `nonce`; `code_challenge` with
    `code_challenge_method=S256` only (no `plain`); optional `prompt`, `max_age`, `acr_values`,
    `claims` per OpenID Connect Core; unknown parameters ignored, duplicated parameters refused;
  - FAPI 2.0: Pushed Authorization Requests (PAR, RFC 9126), so the front-channel request carries
    only `client_id` and `request_uri`; not implemented today. Decided 2026-11-10 (owner): add PAR
    after this spec's cross-repository connection works, because it reuses the same pieces (RP
    `private_key_jwt`, server-to-server HTTPS, per-repository JWKS). Estimated medium effort: a Visa
    PAR endpoint reusing `OidcAuthorizeRequestResolver`, short-lived single-use storage,
    `request_uri` handling at `/oauth/authorize`, `pushed_authorization_request_endpoint` in
    Discovery, and one pushed request per RP before redirecting. Roll out in two stages: first PAR
    is accepted alongside the current front-channel request; once every RP uses it, require it
    (`require_pushed_authorization_requests`). Refusal tests: reused, expired or foreign
    `request_uri`, and conflicting front-channel parameters;
  - response: `code`, `state` and `iss` (RFC 9207), errors per RFC 6749 section 4.1.2.1, no tokens
    in the front channel; the RP checks `state` and `iss`;
  - non-standard parameters on these endpoints (for example `ri`) listed with their purpose and a
    decision to keep, rename or remove.

  Observed 2026-11-10 (read-only, Access worktree): the RP side sends `response_type=code`, S256
  PKCE, `state` (a signed JWT), `nonce`, `scope=openid profile`, optional `prompt` and `max_age`;
  Visa permits
  `response_type client_id redirect_uri state code_challenge code_challenge_method scope nonce prompt max_age claims acr_values`;
  Discovery advertises `authorization_response_iss_parameter_supported`, and the RP callback
  compares `iss`. PAR is absent. `ri` is a non-standard parameter on Visa's authorization routes.

  Site-specific parameters (`ri` region identifier, `lx` language, `tz` time zone), decided
  2026-11-10:
  - OAuth 2.0 (RFC 6749 section 3.1) requires the authorization server to ignore unrecognized
    request parameters, so their presence alone does not break OAuth or OpenID Connect. Visa keeps
    them out of `authorize_params`.
  - They are presentation inputs only. They must never select the redirect target, the issuer, the
    serving region or any other security decision: front-channel values are attacker-controlled
    (open redirect, mix-up). The audit confirms this for every use of `ri`.
  - Language moves to the standard `ui_locales` parameter (OpenID Connect Core 1.0).
  - Region has no standard parameter. Until PAR exists, derive it from the client or the registered
    `redirect_uri` host. With PAR (FAPI 2.0), site-specific parameters travel inside the
    authenticated pushed request, not in the browser URL; any value still read from the front
    channel is treated as unauthenticated.

## Development Approach (owner consensus, 2026-11-11)

Goal: conform to OpenID Connect (and the Protocol Target above). The OP is built in-house; RP-side
components follow the OpenID standards and converge on standard libraries.

Current focus (owner, 2026-11-11): Access, Governance and `umaxica-apps-mock-oidc` only; Sphere and
Press wait until phase 4.

Phases:

1. **Access (OP) and Governance (RP) together.** Develop both sides at the same time; Governance is
   the first Rails RP.
2. **Probe RP as the continuous check.** A separate JavaScript project, `umaxica-apps-mock-oidc`
   (`~/Projects/ghq/github.com/seahal/umaxica-apps-mock-oidc`, Bun), reached in development at
   `https://mock.umaxica.app` through its own Cloudflare Tunnel; the hostname and tunnel are removed
   once the probe's goal is reached (owner, 2026-11-11). It uses `openid-client` (a certified FAPI
   2.0 RP) signs in against Access throughout development. Every OP change is checked with it,
   feature by feature (authorization code with PKCE, `private_key_jwt`, PAR, DPoP, RP-Initiated and
   Back-Channel Logout, step-up). A failure is classified as an OP defect or a probe configuration
   issue and recorded in `evidence/`.
3. **Freeze the OP interface.** When the required probe checks pass, fix Access's external interface
   (discovery metadata, endpoints, parameters, token and error shapes) and record it; later changes
   to it need an explicit decision.
4. **Move the RPs onto the forked gem.** Governance, Sphere and Press replace their in-house OIDC
   adapters with components built on the `openid_connect` fork (section above), one RP at a time,
   each checked against the frozen interface.
5. **Upstream.** Propose the fork's additions to the gem's author for merge, and return to released
   versions as they land.

## Order

Working first, then polish. Core components are costly to rebuild, so the hardest-to-integrate parts
go first, while their risk can still change the plan:

0. Impact map (Access, read-only): every caller of `JitSecurityJwtRegistry`,
   `JitSecurityJwtKeyring`, `JitSecurityJwtLocalKeysetInstaller`, `OidcClientRegistry` and
   `OutboundHttp::LocalBackChannel`, with an effort and risk estimate for each item below.
1. Key loading and signing core (all repositories, Access first): credentials-backed keys, no
   boot-time generation, one signer component.
2. Access: client assertion verification against remote `jwks_uri`; drop RP private keys.
3. Remove `LocalBackChannel`; outbound calls use public HTTPS.
4. `/.well-known/jwks.json` per repository.
5. Governance Base App sign-in end to end (AC-6), then Press and Sphere.
