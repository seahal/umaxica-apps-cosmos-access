# Security Headers

## Current Standard

Browser security headers must be configured to keep the public application surfaces eligible for an
A+ grade on both:

- Mozilla / MDN HTTP Observatory: `https://developer.mozilla.org/en-US/observatory`
- SecurityHeaders.com: `https://securityheaders.com/`

This target applies to the retained Auth APP/ORG and Visa APP/ORG browser hosts, and to future
changes that affect CSP, Permissions-Policy, cookie transport, SRI-sensitive external scripts, CORP,
COEP, COOP, HSTS, Referrer-Policy, X-Content-Type-Options, frame protections, or related browser
security headers. Operator tools have their own access and host configuration.

## Implementation Notes

- CSP is configured in `config/initializers/content_security_policy.rb`.
- Development CSP allows `ws:` / `wss:` in `connect-src` so Vite dev-server HMR can open its
  websocket.
- `form-action` stays same-origin except for the Google and Apple OAuth endpoints used by Auth APP
  social sign-in/sign-up and the configured Auth/Visa origins used by the browser-bound OIDC
  continuation. Browsers enforce `form-action` across those provider and ceremony-post navigations.
- Permissions-Policy, Cross-Origin-Embedder-Policy, Cross-Origin-Opener-Policy, and
  Cross-Origin-Resource-Policy are configured in `config/initializers/permissions_policy.rb`.
- Session cookie transport is configured through `config/initializers/session_store.rb` and
  `lib/jit_session_cookie_config.rb`.
- Turnstile scripts should only be loaded on pages that render a Turnstile form, and inline
  Turnstile setup scripts must use CSP nonces.
- Do not re-enable Rails' legacy `Feature-Policy` header; use the explicit `Permissions-Policy`
  header instead.
- `Expect-CT`, `Report-To`, `NEL`, `Server`, and CDN-managed compatibility headers may be added or
  rewritten by the edge provider. If scanners flag those, verify whether the fix belongs in Rails or
  the CDN configuration before changing application code.

## CSP Violation Report Endpoints

CSP violation report endpoints intentionally skip Rails CSRF verification for the `create` action
only.

- Browser-generated CSP reports do not include Rails authenticity tokens and may arrive with
  `Origin: null`.
- These endpoints are unauthenticated telemetry ingestion points.
- Submitted reports are untrusted and must not be treated as authoritative evidence.
- The endpoint must not authenticate actors, mutate user/account/session/cookie state, refresh
  credentials, or redirect.
- Existing body-size limits, field sanitization, and rate limiting at 120 requests per minute remain
  in effect.
- Static-analysis tools may flag `skip_forgery_protection` on these endpoints. This is an
  intentional, reviewed security exception under the documented create-only and telemetry-only
  constraints. No Brakeman suppression is applied.

When changing these areas, update focused regression tests and re-scan the affected public host
after deployment.
