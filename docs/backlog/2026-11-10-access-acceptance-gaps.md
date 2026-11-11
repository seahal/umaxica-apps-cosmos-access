# Access Acceptance Gaps (2026-11-10)

Owner: Access. Source: `evidence/2026-11-10-access-acceptance-H8R4.md` (acceptance failed). The Dev
Containers are busy, so these wait; hand them to Codex in this order.

1. **Valid authorization requests fail (high, blocks everything).** A correct request to Visa
   `/oauth/authorize` (registered Base App client, exact `redirect_uri`, `openid`, `state`, `nonce`,
   S256 PKCE) returns 422 with `ActiveRecord::RecordInvalid` (`status` blank) when the authorization
   transaction is created. Find the cause (missing status reference data after the split, or a
   writer that no longer sets the status) and fix it without weakening validation. Then confirm the
   unauthenticated request redirects to the Auth sign-in entry.
2. **Duplicate authorization parameters are accepted (medium).** RFC 6749 section 3.1 forbids
   sending a request parameter more than once. Rack collapses duplicates, so the resolver cannot see
   them. Refuse duplicates of every recognized authorization parameter from the raw query (and form
   body for POST), with the standard error handling: local error when `client_id` or `redirect_uri`
   cannot be trusted, otherwise `invalid_request` to the registered redirect.
3. **Missing `no-store` on personal responses (medium).** Auth App settings (`/settings`,
   `/settings/apple`, `/settings/apple/edit`, `/settings/google`, `/settings/google/edit`), the
   social callbacks (`/social/google/callback`, `/social/apple/callback`, `/social/entra/callback`)
   and the framework 422 of the authorization endpoint. Public resources stay cacheable per the
   amended `adr/cosmos-identity-without-inertia.md` (JWKS, Discovery, sitemap, robots).
4. **Authorization GET writes a transaction (low).** Allowed by the amended ADR for the protocol
   endpoint; confirm the record expires quickly, is browser-bound and grants nothing by itself, and
   add a test for that.
5. **Re-run acceptance** after 1 to 3, inside the Access Dev Container, then the owner's browser
   checks: sign-in round trip returning `code`, and Back/Forward/Reload after completion,
   cancellation, expiry, sign-out and session change.

Known, tracked elsewhere: PAR (FAPI 2.0) and restricted `prompt`/`claims` support
(`specs/cosmos-cross-repository-connection/spec.md`, AC-8); remaining Base references in executable
code and stale documents (`evidence/2026-11-09-access-final-check-Q7M2.md`).
