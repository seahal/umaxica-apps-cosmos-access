# HTTP Cache Policy for Rails Controllers

This is the current implementation reference for `Cache-Control` on Auth and Visa controller
responses. Static assets and the separately mounted Mission, Flipper, Blazer, PgHero, Coverband, and
Swagger tools are outside the product controller policy.

## Policy

Auth and Visa controller roots default to `no-store`. An action may opt in only when its response is
public, stable for the declared lifetime, and independent of the signed-in subject. Auth and Visa
are separate cache and credential boundaries.

- `no-store`: no cache may store the representation.
- `no-cache`: a stored representation must be revalidated before reuse.
- `private`: only a browser cache may store the representation.
- `public`: shared caches may store the representation when the rest of the response permits it.

## Rules

1. Each Auth or Visa product controller root declares the shared `DefaultNoStore` callback once;
   descendants inherit it.
2. The default no-store callback precedes the host-availability gate and all other controller
   callbacks.
3. An action opts in from inside the action with Rails cache helpers such as `fresh_when`, `stale?`,
   or `expires_in`. Do not set `Cache-Control` directly to opt in.
4. Skipping `apply_default_no_store` is forbidden.
5. A response varying by signed-in subject must never use `public`; if cached, it must be private
   and vary on the inputs that select its representation.
6. Health, revision, authentication, OAuth/OIDC, logout, DBSC, ceremony, and provider-callback
   responses remain no-store.

`test/security/invariants/default_no_store_policy_invariant_test.rb` enforces the root callback
ordering and prevents bypasses for retained controller roots.

## Retained controller roots

| Root                                 | Scope                                                     |
| ------------------------------------ | --------------------------------------------------------- |
| Auth APP/ORG `ApplicationController` | Credential ceremony and provider-callback pages           |
| Auth APP/ORG `BareController`        | Bare infrastructure endpoints such as health and revision |
| Visa APP/ORG `ApplicationController` | Authenticated Visa authority flows                        |
| Visa APP/ORG `BareController`        | Bare protocol and infrastructure endpoints                |
| Standalone Auth API controllers      | Explicitly declare their own no-store behavior            |

The operator tools are mounted engines or Rack applications with their own access and response
policies. They do not inherit the Auth/Visa product controller policy.

## Public cache exceptions

Visa JWKS documents are explicitly cacheable under the key-publication contract. No Publishing,
Dashboard, sitemap, or other retired product route is a current Access cache exception. Any new
exception requires a reviewed route owner, representation-stability contract, and tests.
