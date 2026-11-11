# MCP for Press and Sphere, Authorized by Access (draft, 2026-11-12)

Status: draft. Owner decisions recorded below; everything else is open. No implementation is
authorized yet. Source: an owner-supplied handoff (drafted outside this repository) rewritten for
the four-repository split; its premises that predate the split (a single `umaxica-apps-jit-global`
repository, a "Global" service) are replaced here.

## Purpose

Give AI clients (for example ChatGPT, Claude) and a human-operated UMAXICA CLI one shared operation
interface through the Model Context Protocol (MCP). The aim is not AI-only features: CLI and AI use
the same tools, so business logic and authorization are not duplicated. Existing REST APIs stay; the
CLI may call OAuth endpoints directly for login.

## Owner decisions

1. **MCP servers live in Press and Sphere** (owner, 2026-11-12), because their resources are the
   ones to be operated. Each repository exposes its own tools over its own data and authorization.
2. **Authentication goes through Access.** Access (Visa) is the OAuth authorization server; Auth
   runs the ceremonies (passkey, one-time codes). MCP servers are OAuth resource servers. No
   MCP-specific user authentication is created.
3. **Access hosts no MCP server.** Access is an OpenID Provider only
   (`adr/access-is-a-pure-openid-provider.md`); it gains only the authorization-server features MCP
   needs, each added to its route allow-list by amending that ADR.
4. Carried over from the handoff and consistent with current decisions: the MCP protocol is not
   implemented in-house (official Ruby SDK `mcp` is the first candidate); MCP authenticates with
   OAuth bearer access tokens, never browser session cookies; tools are thin adapters over existing
   Rails services and Action Policy; read-only tools first; OpenID Federation is not adopted now;
   DCR is not introduced unless compatibility requires it; immediate revocation of issued access
   tokens is not guaranteed (short-lived JWTs; revocation stops refresh and new tokens), but Action
   Policy is always evaluated per call.

Not in scope now: MCP on Governance and on COM surfaces.

## Shape

```text
UMAXICA CLI ─┐                     ┌─ Press MCP  (Press tools, Press Rails services)
             ├─ bearer token ──────┤
AI client  ──┘                     └─ Sphere MCP (Sphere tools, Sphere Rails services)
                    ▲
                    │ OAuth 2.1 (authorization code + PKCE; device grant: open)
              Access (Visa: authorization server; Auth: ceremonies)
```

- Each MCP server publishes Protected Resource Metadata (RFC 9728) naming Access as its
  authorization server.
- Access issues JWT access tokens (`adr/rfc9068-access-token-profile.md`) with an audience per MCP
  resource, requested with Resource Indicators (RFC 8707). A token for Press MCP is never accepted
  by Sphere MCP and the reverse.
- App (`.app`, people) and Org (`.org`, staff) stay separate authorization boundaries inside each
  repository: separate resources and audiences, never one token for both.
- MCP servers validate tokens locally (signature via Access JWKS, issuer, audience, expiry, scope)
  and keep no authentication state in memory, for horizontal scaling.

## Points that need Access-side changes (each needs an ADR amendment)

| Item                                          | Why                                                                                                                                                                                                        |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RFC 8707 `resource` and per-resource audience | audience separation between MCP servers                                                                                                                                                                    |
| A token profile for third-party MCP clients   | first-party relying parties target FAPI 2.0 (PAR, sender-constrained tokens); MCP clients start with OAuth 2.1 + PKCE + short-lived bearer tokens, DPoP later; the two profiles must be defined separately |
| Client registration of MCP clients            | clients are registered in code (split record, decision 11); check whether ChatGPT and Claude support pre-registration; if they require Client ID Metadata Documents, decide whether to amend decision 11   |
| Consent screen for third-party clients        | Access has first-party relying parties only today                                                                                                                                                          |
| Device Authorization Grant (RFC 8628)         | value confirmed for the CLI; scope and priority open; needs anti-phishing design                                                                                                                           |
| Listing and revoking MCP grants               | the list screen belongs to Governance (Access shows no lists); revocation reaches Access as a command (`adr/access-is-a-pure-openid-provider.md`, decisions 11 to 13)                                      |

## Open

- MCP specification version and SDK version (verify current official documents; do not trust
  remembered versions).
- MCP endpoint hosts and paths in Press and Sphere, and their audiences.
- Initial read-only tools per repository and their mapping to CLI commands.
- Access token lifetime (5 to 15 minutes proposed), refresh token issuance, rotation and reuse
  detection for public clients.
- Where the CLI lives (a new repository) and how it stores credentials (OS credential store first).
- Audit records and rate limits for tool calls; prompt-injection and abuse limits.
- Testing: HTTP-level tests (curl or Hurl) for missing, invalid, expired, wrong-issuer,
  wrong-audience and insufficient-scope tokens, `tools/list`, `tools/call`, schema violations, IDOR,
  App/Org separation.

## Next step

Phase 1 and 2 only (research, no code): inventory in Access the OAuth pieces MCP needs
(authorization code + PKCE, token endpoint, JWT access tokens, JWKS, refresh tokens, `resource`,
consent, client registration); inventory in Press and Sphere the Rails services and Action Policy
rules the first read-only tools would call; check the current MCP authorization specification and
Ruby SDK. Record findings in `evidence/` of each repository and update this spec.
