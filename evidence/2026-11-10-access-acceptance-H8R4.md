# Access separation acceptance

## Rejection gap: duplicates pass validation

**Duplicate authorization parameters pass request validation.** Each of the eight required fields
was duplicated separately with equal scalar values. Rack collapses the pair;
`OidcAuthorizeRequestResolver.call` then accepts every normalized request. Actual HTTP requests
reach transaction creation and fail with the same unrelated 422 as a valid request. They are not
refused as duplicates. No successful authorization or issued code was observed. Owner: Access
maintainer; acceptance fails.

Other failures: valid unauthenticated authorization fails with `ActiveRecord::RecordInvalid`
(`status: blank`); 14 inventoried GET responses omit no-store; authorization GET reaches a
persistence writer. Jump redirects carry a signed `rt` token in the query, and successful OIDC
response construction puts `code` in a query, conflicting with the ADR's broad URL prohibition.
Owner: Access maintainer. No fixes were authorized.

## Provenance and execution limits

- Filename date is the requested 2026-11-10; execution clock was 2026-11-09 UTC.
- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- Extensive existing uncommitted application, routing, configuration, documentation and test changes
  affected results and were preserved. This evidence is the only intended repository change from
  this task. No commit was made.
- Basis: `evidence/2026-11-09-access-final-check-Q7M2.md`, `adr/cosmos-identity-without-inertia.md`,
  AC-8 in `specs/cosmos-cross-repository-connection/spec.md`.
- **Container execution remains unverified:** docker is unavailable and this executor has no
  `/.dockerenv` marker. Rails ran directly in the available development runtime. These are local
  HTTP results, not claimed container results.
- Temporary Puma listened only on loopback port 3814. Net::HTTP supplied configured Host headers and
  never followed redirects. The server stopped in ensure; a subsequent `ss -ltn '( sport = :3814 )'`
  showed no listener.
- Governance Base App registration was read in memory through
  `RpDeploymentBindingValue.client_id('base-app')` and `OidcClientRegistry.find!`, preferring the
  canonical registered callback. Identifier and callback values were never emitted.
- HTTP request/SQL logging was discarded before requests. Bodies, cookie values and token values
  were not printed or retained by the harness. Subsequent runs used `OTEL_SDK_DISABLED=true`. Only
  statuses, parameter names, error identifiers and boolean comparisons were emitted. Jump decoding
  inspected locally generated payloads in memory; it does not establish signature verification or
  external Jump delivery.
- No external redirect destination, provider or RP was contacted. No development database/volume was
  deleted, reset or migrated. Authorization starts failed transaction validation; no authenticated
  flow completed. Existing test-suite fixture setup/cleanup used the test environment.

## Authorization HTTP results

The valid request contained response_type=code, registry client_id and exact redirect_uri,
scope=openid, independently generated state/nonce, a SHA-256 PKCE challenge and method S256. No
authenticated cookie was sent. This matrix used Visa App and the requested Base App registration.

| Case                               | HTTP | Outcome                                                                                        |
| ---------------------------------- | ---- | ---------------------------------------------------------------------------------------------- |
| Valid request                      | 422  | RecordInvalid, status blank; no Location, no no-store. Auth sign-in redirect unverified.       |
| Unregistered client                | 400  | Local invalid_request, no Location; no-store.                                                  |
| Unregistered redirect URI          | 400  | Local invalid_request, no Location; no-store. RFC 6749 4.1.2.1 unsafe-redirect rule satisfied. |
| response_type other than code      | 302  | Jump wraps registered RP destination with unsupported_response_type.                           |
| Missing challenge                  | 302  | Registered-target invalid_request through Jump.                                                |
| plain method                       | 302  | Registered-target invalid_request through Jump.                                                |
| Scope without openid               | 302  | Registered-target invalid_request through Jump.                                                |
| Missing state                      | 302  | Registered-target invalid_request; missing state stays absent.                                 |
| Missing nonce                      | 302  | Registered-target invalid_request through Jump.                                                |
| Duplicate each of the eight fields | 422  | Same unrelated persistence validation failure; normalized resolver accepts all eight.          |
| Unknown extra parameter            | 422  | Same downstream failure; static authorize_params allowlist excludes unknown fields.            |
| Changed ri                         | 422  | Same downstream failure; successful routing comparison blocked.                                |

Every listed 302 carried no-store. In-memory inspection of the locally generated Jump payload
confirmed the embedded destination host matched the registered RP, state matched when supplied, and
iss matched the configured client-realm issuer. Redirects were not followed. No raw URL or token is
retained.

## AC-8 Visa checklist

Conforms / Differs / Unverifiable correspond to the requested three classifications.

| Item                                             | Classification                         | Evidence / limit                                                                                                                                                                      |
| ------------------------------------------------ | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| code-only response_type                          | Conforms                               | Alternative rejected by HTTP and exact resolver check.                                                                                                                                |
| Registered client_id                             | Conforms                               | Unknown client locally rejected before redirect.                                                                                                                                      |
| Exact registered redirect_uri                    | Conforms                               | Registry policy checked before protocol errors; mismatched URI locally rejected.                                                                                                      |
| openid scope                                     | Conforms                               | Missing openid rejected.                                                                                                                                                              |
| state                                            | Conforms                               | Missing rejected; supplied state preserved in exercised errors.                                                                                                                       |
| nonce                                            | Conforms                               | Missing rejected.                                                                                                                                                                     |
| Challenge / S256 only                            | Conforms                               | Missing challenge/plain rejected; resolver requires 43 base64url characters.                                                                                                          |
| Optional prompt                                  | Differs: restricted subset             | App accepts login/none/create; Org login/none. Combined values rejected; unsupported prompts produce local 400 under explicit policy. General OIDC prompt support is not established. |
| Optional max_age                                 | Conforms, static                       | Non-negative integer validation. Authenticated HTTP behavior unverified.                                                                                                              |
| Optional claims/acr_values                       | Differs: restricted subset             | Only canonical essential step-up claims; acr_values alone rejected. General OIDC claims support absent.                                                                               |
| Unknown parameters ignored                       | Conforms, static                       | Narrow authorize_params allowlist; unknown input reaches same downstream failure.                                                                                                     |
| Duplicates refused                               | Differs                                | Eight duplicate scalar cases accepted after Rack normalization.                                                                                                                       |
| FAPI 2.0 PAR                                     | Differs                                | No PAR contract/endpoint found; ordinary front-channel request fields remain. Existing AC-8 gap.                                                                                      |
| Success code/state/iss                           | Unverifiable by HTTP                   | OidcAuthorizeCoordinator statically constructs these fields; success blocked.                                                                                                         |
| RFC 6749 errors                                  | Conforms for exercised ordinary errors | Unsafe redirect errors stay local; ordinary errors wrap registered target with state/iss. External Jump delivery unverified.                                                          |
| No access/ID/refresh token in OIDC front channel | Conforms, static                       | Success builder emits code/state/iss only. Separate Jump rt violates the broader ADR URL rule.                                                                                        |
| RP verifies state/iss                            | Unverifiable                           | Governance RP outside this executor/task; not contacted.                                                                                                                              |
| Non-standard fields / decisions                  | Partial static confirmation            | Audit below; ui_locales and PAR decisions are not implemented here.                                                                                                                   |

App/Org share the resolver and error concern. Both have route coverage below; the full malformed
authorization matrix was run only on App with the Base App registration. Gap owner: Access
maintainer; RP-side confirmation owner: Governance maintainer.

## Site-specific parameter audit

Both Visa authorization bases exclude ri/lx/tz/ct from authorize_params. ri is forwarded to Auth
sentry, verification, switch and limitation URL queries. In the inspected authorization paths, the
Auth host comes from oidc_sign_host/configured Auth host; the RP destination comes from validated
registration. OidcIssuer selects issuer from resource type and boot-configured Visa host.
PreferenceGlobal normalizes presentation context and redirects within the current path; this
inspected path does not select a region host.

No issuer, return-target or serving-region-host selection from ri was found in those inspected
paths. Successful dynamic routing is unverified because changed-ri requests hit the same validation
failure. External Jump/proxy/RP region behavior was not inspected. lx/tz are presentation context;
ct is also sanitized by PreferenceGlobal. AC-8 already requires keeping these fields out of security
decisions, moving language to ui_locales and deriving region from registration until authenticated
PAR exists. No implementation decision was changed here.

## Back/forward acceptance

- **no-store fails:** 259 Auth/Visa route entries inventoried; 131 GET entries requested; 117
  responses include no-store, 14 omit it. The remaining 128 verb entries were inventoried without
  execution. Counts exclude the separate authorization matrix. Invalid placeholders replaced dynamic
  segments; these are unauthenticated/prerequisite-failure observations, not all-state coverage.
- Missing no-store: all four JWKS responses, both Auth sitemaps, three social callbacks and five
  Auth App settings responses. AuthenticationJwksRendering explicitly sets public expiry.
  Authorization's framework-level 422 also omits no-store. Callback-order invariant tests alone do
  not establish final header compliance.
- **URL rule fails:** observed error redirects carry signed rt in the query.
  OidcAuthorizeCoordinator statically constructs successful code in a query. OIDC code flow and the
  ADR need a consistent owner decision. Continuations use opaque transaction/result/cancellation
  references, which the ADR permits. No email/telephone value was observed in emitted authorization
  URLs; other ceremonies are not exhaustively certified.
- **POST/Redirect/GET is not universal:** Visa authorization show calls
  start_authorization_ceremony!, which calls
  OidcAuthorizationTransactionCoordinator.issue_with_handoff! from GET. It reaches validation in
  this runtime. POST also calls that routine and uses 303 on success. Some continuation GETs
  intentionally render a 200 POST form. All state-changing routes were not exercised without
  authenticated prerequisites.
- **Replay partial pass:** executed model tests cover expired/consumed rejection, cancellation
  versus authentication serialization, finalization versus cancellation and microsecond deadline
  boundaries. Continuation tests cover malformed/missing browser bindings and invalid POST purposes.
  This does not certify every completed/cancelled/expired URL or form for every ceremony.
- **Owner confirmation required:** real browser Back/Forward/Reload after completion, cancellation,
  expiry, sign-out and session change; password/OTP restoration/autocomplete; Clear-Site-Data;
  authenticated URL/form replay for each retained ceremony. Owner: Access maintainer. Browser
  acceptance was not claimed.

## Verification

Executed:

```sh
OTEL_SDK_DISABLED=true PARALLEL_WORKERS=1 bin/rails test test/integration/visa_authorization_continuations_test.rb test/integration/default_no_store_auth_test.rb test/security/invariants/default_no_store_policy_invariant_test.rb test/services/oidc/authorization_cancel_state_test.rb test/models/concerns/oidc_authorization_transactionable_test.rb
```

**41 runs, 417 assertions, 0 failures, 0 errors, 0 skips.** Output was filtered to counts/error
class names, without retaining raw output. Preliminary custom test launchers did not yield a summary
(initial test_helper LoadError, then nonzero exit); they are not counted as passing runs. The
documented command supplied the successful result.

Temporary development Ruby HTTP harnesses loaded Rails, disabled request/SQL logging, ran loopback
Puma with Net::HTTP, and emitted sanitized metadata. Duplicate checks additionally passed actual
Rack-normalized inputs to the existing resolver. No application code, tests or configuration were
edited. No code fix or full acceptance pass is claimed.

## Complete route inventory

true/false refers only to the specific unauthenticated GET response. unverified means inventoried
without executing that verb. All-state headers and successful authenticated actions remain
unverified.

| Verb   | Route template                                           | Controller#action                                         | HTTP        | no-store   |
| ------ | -------------------------------------------------------- | --------------------------------------------------------- | ----------- | ---------- |
| GET    | `/.well-known/jwks.json`                                 | `auth/app/well_known/jwks#show`                           | 200         | false      |
| GET    | `/revision`                                              | `auth/app/revisions#show`                                 | 200         | true       |
| GET    | `/health`                                                | `auth/app/healths#show`                                   | 200         | true       |
| GET    | `/health/liveness`                                       | `auth/app/health/livenesses#show`                         | 200         | true       |
| GET    | `/health/readiness`                                      | `auth/app/health/readinesses#show`                        | 200         | true       |
| GET    | `/health/startup`                                        | `auth/app/health/startups#show`                           | 200         | true       |
| GET    | `/api/v0/health.json`                                    | `auth/app/api/v0/healths#show`                            | 200         | true       |
| GET    | `/api/v0/revision.json`                                  | `auth/app/api/v0/revisions#show`                          | 200         | true       |
| GET    | `/robots.txt(.:format)`                                  | `auth/app/robots#index`                                   | 200         | true       |
| GET    | `/sitemap.xml(.:format)`                                 | `auth/app/sitemaps#show`                                  | 200         | false      |
| POST   | `/csp-violation-report(.:format)`                        | `auth/app/csp_violation_reports#create`                   | static-only | unverified |
| GET    | `/ceremony_bindings(.:format)`                           | `auth/app/ceremony_bindings#show`                         | 400         | true       |
| GET    | `/service-worker(.:format)`                              | `auth/app/service_worker_retirements#show`                | 200         | true       |
| POST   | `/apple/notifications(.:format)`                         | `auth/app/apple/notifications#create`                     | static-only | unverified |
| GET    | `/sign/up(.:format)`                                     | `auth/app/sign/ups#show`                                  | 400         | true       |
| GET    | `/sign/in(.:format)`                                     | `auth/app/sign/ins#show`                                  | 400         | true       |
| GET    | `/sign/oidc/handoff(.:format)`                           | `auth/app/sign/oidc_handoffs#show`                        | 400         | true       |
| POST   | `/sign/cancellation(.:format)`                           | `auth/app/sign/cancellations#create`                      | static-only | unverified |
| POST   | `/sign/switch(.:format)`                                 | `auth/app/sign/switches#create`                           | static-only | unverified |
| GET    | `/sign/in/sentry(.:format)`                              | `auth/app/sign/in/sentries#show`                          | 303         | true       |
| GET    | `/sign/up/sentry(.:format)`                              | `auth/app/sign/up/sentries#show`                          | 303         | true       |
| POST   | `/web/v0/in/email/otp(.:format)`                         | `auth/app/web/v0/in/email/otps#create`                    | static-only | unverified |
| GET    | `/api/v0/preferences/cookie(.:format)`                   | `auth/app/api/v0/preferences/cookies#show`                | 200         | true       |
| PATCH  | `/api/v0/preferences/cookie(.:format)`                   | `auth/app/api/v0/preferences/cookies#update`              | static-only | unverified |
| GET    | `/api/v0/preferences/theme(.:format)`                    | `auth/app/api/v0/preferences/themes#show`                 | 200         | true       |
| PATCH  | `/api/v0/preferences/theme(.:format)`                    | `auth/app/api/v0/preferences/themes#update`               | static-only | unverified |
| GET    | `/sign/up/email/new(.:format)`                           | `auth/app/sign/up/emails#new`                             | 400         | true       |
| POST   | `/sign/up/email(.:format)`                               | `auth/app/sign/up/emails#create`                          | static-only | unverified |
| GET    | `/sign/up/telephone/new(.:format)`                       | `auth/app/sign/up/telephones#new`                         | 400         | true       |
| POST   | `/sign/up/telephone(.:format)`                           | `auth/app/sign/up/telephones#create`                      | static-only | unverified |
| GET    | `/sign/up/guard/apple(.:format)`                         | `auth/app/sign/up/guard/apples#show`                      | 400         | true       |
| GET    | `/sign/up/guard/google(.:format)`                        | `auth/app/sign/up/guard/googles#show`                     | 400         | true       |
| GET    | `/sign/up/guard/email(.:format)`                         | `auth/app/sign/up/guard/emails#show`                      | 400         | true       |
| GET    | `/sign/up/guard/telephone(.:format)`                     | `auth/app/sign/up/guard/telephones#show`                  | 400         | true       |
| GET    | `/sign/up/check/apple/confirmation(.:format)`            | `auth/app/sign/up/check/apple/confirmations#show`         | 400         | true       |
| PATCH  | `/sign/up/check/apple/confirmation(.:format)`            | `auth/app/sign/up/check/apple/confirmations#update`       | static-only | unverified |
| PUT    | `/sign/up/check/apple/confirmation(.:format)`            | `auth/app/sign/up/check/apple/confirmations#update`       | static-only | unverified |
| DELETE | `/sign/up/check/apple/confirmation(.:format)`            | `auth/app/sign/up/check/apple/confirmations#destroy`      | static-only | unverified |
| GET    | `/sign/up/check/apple/birthdate(.:format)`               | `auth/app/sign/up/check/apple/birthdates#show`            | 400         | true       |
| PATCH  | `/sign/up/check/apple/birthdate(.:format)`               | `auth/app/sign/up/check/apple/birthdates#update`          | static-only | unverified |
| PUT    | `/sign/up/check/apple/birthdate(.:format)`               | `auth/app/sign/up/check/apple/birthdates#update`          | static-only | unverified |
| DELETE | `/sign/up/check/apple/birthdate(.:format)`               | `auth/app/sign/up/check/apple/birthdates#destroy`         | static-only | unverified |
| GET    | `/sign/up/check/google/confirmation(.:format)`           | `auth/app/sign/up/check/google/confirmations#show`        | 400         | true       |
| PATCH  | `/sign/up/check/google/confirmation(.:format)`           | `auth/app/sign/up/check/google/confirmations#update`      | static-only | unverified |
| PUT    | `/sign/up/check/google/confirmation(.:format)`           | `auth/app/sign/up/check/google/confirmations#update`      | static-only | unverified |
| DELETE | `/sign/up/check/google/confirmation(.:format)`           | `auth/app/sign/up/check/google/confirmations#destroy`     | static-only | unverified |
| GET    | `/sign/up/check/google/birthdate(.:format)`              | `auth/app/sign/up/check/google/birthdates#show`           | 400         | true       |
| PATCH  | `/sign/up/check/google/birthdate(.:format)`              | `auth/app/sign/up/check/google/birthdates#update`         | static-only | unverified |
| PUT    | `/sign/up/check/google/birthdate(.:format)`              | `auth/app/sign/up/check/google/birthdates#update`         | static-only | unverified |
| DELETE | `/sign/up/check/google/birthdate(.:format)`              | `auth/app/sign/up/check/google/birthdates#destroy`        | static-only | unverified |
| GET    | `/sign/up/check/email/otp(.:format)`                     | `auth/app/sign/up/check/email/otps#show`                  | 400         | true       |
| PATCH  | `/sign/up/check/email/otp(.:format)`                     | `auth/app/sign/up/check/email/otps#update`                | static-only | unverified |
| PUT    | `/sign/up/check/email/otp(.:format)`                     | `auth/app/sign/up/check/email/otps#update`                | static-only | unverified |
| DELETE | `/sign/up/check/email/otp(.:format)`                     | `auth/app/sign/up/check/email/otps#destroy`               | static-only | unverified |
| POST   | `/sign/up/check/email/otp(.:format)`                     | `auth/app/sign/up/check/email/otps#create`                | static-only | unverified |
| GET    | `/sign/up/check/email/birthdate(.:format)`               | `auth/app/sign/up/check/email/birthdates#show`            | 400         | true       |
| PATCH  | `/sign/up/check/email/birthdate(.:format)`               | `auth/app/sign/up/check/email/birthdates#update`          | static-only | unverified |
| PUT    | `/sign/up/check/email/birthdate(.:format)`               | `auth/app/sign/up/check/email/birthdates#update`          | static-only | unverified |
| DELETE | `/sign/up/check/email/birthdate(.:format)`               | `auth/app/sign/up/check/email/birthdates#destroy`         | static-only | unverified |
| GET    | `/sign/up/check/telephone/otp(.:format)`                 | `auth/app/sign/up/check/telephone/otps#show`              | 400         | true       |
| PATCH  | `/sign/up/check/telephone/otp(.:format)`                 | `auth/app/sign/up/check/telephone/otps#update`            | static-only | unverified |
| PUT    | `/sign/up/check/telephone/otp(.:format)`                 | `auth/app/sign/up/check/telephone/otps#update`            | static-only | unverified |
| DELETE | `/sign/up/check/telephone/otp(.:format)`                 | `auth/app/sign/up/check/telephone/otps#destroy`           | static-only | unverified |
| POST   | `/sign/up/check/telephone/otp(.:format)`                 | `auth/app/sign/up/check/telephone/otps#create`            | static-only | unverified |
| GET    | `/sign/up/check/telephone/passkey(.:format)`             | `auth/app/sign/up/check/telephone/passkeys#show`          | 400         | true       |
| PATCH  | `/sign/up/check/telephone/passkey(.:format)`             | `auth/app/sign/up/check/telephone/passkeys#update`        | static-only | unverified |
| PUT    | `/sign/up/check/telephone/passkey(.:format)`             | `auth/app/sign/up/check/telephone/passkeys#update`        | static-only | unverified |
| DELETE | `/sign/up/check/telephone/passkey(.:format)`             | `auth/app/sign/up/check/telephone/passkeys#destroy`       | static-only | unverified |
| POST   | `/sign/up/check/telephone/passkey(.:format)`             | `auth/app/sign/up/check/telephone/passkeys#create`        | static-only | unverified |
| POST   | `/sign/up/check/telephone/secret/reattempt(.:format)`    | `auth/app/sign/up/check/telephone/secrets#reattempt`      | static-only | unverified |
| GET    | `/sign/up/check/telephone/secret(.:format)`              | `auth/app/sign/up/check/telephone/secrets#show`           | 400         | true       |
| PATCH  | `/sign/up/check/telephone/secret(.:format)`              | `auth/app/sign/up/check/telephone/secrets#update`         | static-only | unverified |
| PUT    | `/sign/up/check/telephone/secret(.:format)`              | `auth/app/sign/up/check/telephone/secrets#update`         | static-only | unverified |
| DELETE | `/sign/up/check/telephone/secret(.:format)`              | `auth/app/sign/up/check/telephone/secrets#destroy`        | static-only | unverified |
| POST   | `/sign/up/check/telephone/secret(.:format)`              | `auth/app/sign/up/check/telephone/secrets#create`         | static-only | unverified |
| GET    | `/sign/up/check/telephone/birthdate(.:format)`           | `auth/app/sign/up/check/telephone/birthdates#show`        | 400         | true       |
| PATCH  | `/sign/up/check/telephone/birthdate(.:format)`           | `auth/app/sign/up/check/telephone/birthdates#update`      | static-only | unverified |
| PUT    | `/sign/up/check/telephone/birthdate(.:format)`           | `auth/app/sign/up/check/telephone/birthdates#update`      | static-only | unverified |
| DELETE | `/sign/up/check/telephone/birthdate(.:format)`           | `auth/app/sign/up/check/telephone/birthdates#destroy`     | static-only | unverified |
| GET    | `/sign/in/email/new(.:format)`                           | `auth/app/sign/in/emails#new`                             | 400         | true       |
| GET    | `/sign/in/email/edit(.:format)`                          | `auth/app/sign/in/emails#edit`                            | 400         | true       |
| PATCH  | `/sign/in/email(.:format)`                               | `auth/app/sign/in/emails#update`                          | static-only | unverified |
| PUT    | `/sign/in/email(.:format)`                               | `auth/app/sign/in/emails#update`                          | static-only | unverified |
| DELETE | `/sign/in/email(.:format)`                               | `auth/app/sign/in/emails#destroy`                         | static-only | unverified |
| POST   | `/sign/in/email(.:format)`                               | `auth/app/sign/in/emails#create`                          | static-only | unverified |
| GET    | `/sign/in/passkey/new(.:format)`                         | `auth/app/sign/in/passkeys#new`                           | 400         | true       |
| GET    | `/sign/in/secret/new(.:format)`                          | `auth/app/sign/in/secrets#new`                            | 400         | true       |
| POST   | `/sign/in/secret(.:format)`                              | `auth/app/sign/in/secrets#create`                         | static-only | unverified |
| POST   | `/sign/in/passkey/options(.:format)`                     | `auth/app/sign/in/passkey/options#create`                 | static-only | unverified |
| POST   | `/sign/in/passkey/verification(.:format)`                | `auth/app/sign/in/passkey/verifications#create`           | static-only | unverified |
| GET    | `/sign/in/check(.:format)`                               | `auth/app/sign/in/checks#show`                            | 400         | true       |
| GET    | `/sign/in/challenge(.:format)`                           | `auth/app/sign/in/challenges#show`                        | 303         | true       |
| DELETE | `/sign/in/challenge(.:format)`                           | `auth/app/sign/in/challenges#destroy`                     | static-only | unverified |
| GET    | `/sign/in/challenge/passkey/new(.:format)`               | `auth/app/sign/in/challenge/passkeys#new`                 | 400         | true       |
| POST   | `/sign/in/challenge/passkey(.:format)`                   | `auth/app/sign/in/challenge/passkeys#create`              | static-only | unverified |
| POST   | `/social/link_completion(.:format)`                      | `auth/app/social/link_completions#create`                 | static-only | unverified |
| GET    | `/social/google/callback(.:format)`                      | `auth/app/omniauth/omniauth_callbacks#omniauth`           | 302         | false      |
| GET    | `/social/apple/callback(.:format)`                       | `auth/app/omniauth/omniauth_callbacks#omniauth`           | 302         | false      |
| GET    | `/social/failure(.:format)`                              | `auth/app/omniauth/omniauth_callbacks#failure`            | 400         | true       |
| POST   | `/social/google/session(.:format)`                       | `auth/app/social/sessions#create`                         | static-only | unverified |
| POST   | `/social/google/registration(.:format)`                  | `auth/app/social/registrations#create`                    | static-only | unverified |
| POST   | `/social/apple/session(.:format)`                        | `auth/app/social/sessions#create`                         | static-only | unverified |
| POST   | `/social/apple/registration(.:format)`                   | `auth/app/social/registrations#create`                    | static-only | unverified |
| GET    | `/verification(.:format)`                                | `auth/app/verifications#show`                             | 400         | true       |
| POST   | `/verification/cancellation(.:format)`                   | `auth/app/verification/cancellations#create`              | static-only | unverified |
| GET    | `/verification/setup/new(.:format)`                      | `auth/app/verification/setups#new`                        | 400         | true       |
| GET    | `/verification/handoff(.:format)`                        | `auth/app/verification/handoffs#show`                     | 400         | true       |
| POST   | `/verification/handoff(.:format)`                        | `auth/app/verification/handoffs#create`                   | static-only | unverified |
| POST   | `/verification/passkey/options(.:format)`                | `auth/app/verification/passkeys#options`                  | static-only | unverified |
| GET    | `/verification/passkey/new(.:format)`                    | `auth/app/verification/passkeys#new`                      | 400         | true       |
| POST   | `/verification/passkey(.:format)`                        | `auth/app/verification/passkeys#create`                   | static-only | unverified |
| GET    | `/verification/totp/new(.:format)`                       | `auth/app/verification/totps#new`                         | 400         | true       |
| POST   | `/verification/totp(.:format)`                           | `auth/app/verification/totps#create`                      | static-only | unverified |
| POST   | `/verification/registration/passkey/options(.:format)`   | `auth/app/verification/registration/passkeys#options`     | static-only | unverified |
| GET    | `/verification/registration/passkey/new(.:format)`       | `auth/app/verification/registration/passkeys#new`         | 400         | true       |
| POST   | `/verification/registration/passkey(.:format)`           | `auth/app/verification/registration/passkeys#create`      | static-only | unverified |
| GET    | `/verification/registration/handoff(.:format)`           | `auth/app/verification/registration/handoffs#show`        | 400         | true       |
| POST   | `/verification/registration/handoff(.:format)`           | `auth/app/verification/registration/handoffs#create`      | static-only | unverified |
| POST   | `/verification/emails/:email_id/redelivery(.:format)`    | `auth/app/verification/redeliveries#create`               | static-only | unverified |
| POST   | `/verification/emails(.:format)`                         | `auth/app/verification/emails#create`                     | static-only | unverified |
| GET    | `/verification/emails/new(.:format)`                     | `auth/app/verification/emails#new`                        | 400         | true       |
| GET    | `/verification/emails/:id/edit(.:format)`                | `auth/app/verification/emails#edit`                       | 400         | true       |
| PATCH  | `/verification/emails/:id(.:format)`                     | `auth/app/verification/emails#update`                     | static-only | unverified |
| PUT    | `/verification/emails/:id(.:format)`                     | `auth/app/verification/emails#update`                     | static-only | unverified |
| GET    | `/settings(.:format)`                                    | `auth/app/settings#show`                                  | 400         | false      |
| DELETE | `/settings/totps/enrollment(.:format)`                   | `auth/app/settings/totps/enrollments#destroy`             | static-only | unverified |
| POST   | `/settings/totps/enrollment(.:format)`                   | `auth/app/settings/totps/enrollments#create`              | static-only | unverified |
| GET    | `/settings/totps/handoff(.:format)`                      | `auth/app/settings/totps/handoffs#show`                   | 400         | true       |
| POST   | `/settings/totps/handoff(.:format)`                      | `auth/app/settings/totps/handoffs#create`                 | static-only | unverified |
| POST   | `/settings/totps(.:format)`                              | `auth/app/settings/totps#create`                          | static-only | unverified |
| GET    | `/settings/totps/new(.:format)`                          | `auth/app/settings/totps#new`                             | 400         | true       |
| GET    | `/settings/apple/edit(.:format)`                         | `auth/app/settings/apples#edit`                           | 400         | false      |
| GET    | `/settings/apple(.:format)`                              | `auth/app/settings/apples#show`                           | 400         | false      |
| DELETE | `/settings/apple(.:format)`                              | `auth/app/settings/apples#destroy`                        | static-only | unverified |
| POST   | `/settings/apple(.:format)`                              | `auth/app/settings/apples#create`                         | static-only | unverified |
| GET    | `/settings/google/edit(.:format)`                        | `auth/app/settings/googles#edit`                          | 400         | false      |
| GET    | `/settings/google(.:format)`                             | `auth/app/settings/googles#show`                          | 400         | false      |
| DELETE | `/settings/google(.:format)`                             | `auth/app/settings/googles#destroy`                       | static-only | unverified |
| POST   | `/settings/google(.:format)`                             | `auth/app/settings/googles#create`                        | static-only | unverified |
| GET    | `/.well-known/jwks.json`                                 | `auth/org/well_known/jwks#show`                           | 200         | false      |
| GET    | `/revision`                                              | `auth/org/revisions#show`                                 | 200         | true       |
| GET    | `/health`                                                | `auth/org/healths#show`                                   | 200         | true       |
| GET    | `/health/liveness`                                       | `auth/org/health/livenesses#show`                         | 200         | true       |
| GET    | `/health/readiness`                                      | `auth/org/health/readinesses#show`                        | 200         | true       |
| GET    | `/health/startup`                                        | `auth/org/health/startups#show`                           | 200         | true       |
| GET    | `/api/v0/health.json`                                    | `auth/org/api/v0/healths#show`                            | 200         | true       |
| GET    | `/api/v0/revision.json`                                  | `auth/org/api/v0/revisions#show`                          | 200         | true       |
| GET    | `/robots.txt(.:format)`                                  | `auth/org/robots#index`                                   | 200         | true       |
| GET    | `/sitemap.xml(.:format)`                                 | `auth/org/sitemaps#show`                                  | 200         | false      |
| POST   | `/csp-violation-report(.:format)`                        | `auth/org/csp_violation_reports#create`                   | static-only | unverified |
| GET    | `/ceremony_bindings(.:format)`                           | `auth/org/ceremony_bindings#show`                         | 400         | true       |
| GET    | `/service-worker(.:format)`                              | `auth/org/service_worker_retirements#show`                | 200         | true       |
| GET    | `/sign/up(.:format)`                                     | `auth/org/sign/ups#show`                                  | 400         | true       |
| GET    | `/sign/in(.:format)`                                     | `auth/org/sign/ins#show`                                  | 400         | true       |
| GET    | `/sign/oidc/handoff(.:format)`                           | `auth/org/sign/oidc_handoffs#show`                        | 400         | true       |
| POST   | `/sign/cancellation(.:format)`                           | `auth/org/sign/cancellations#create`                      | static-only | unverified |
| GET    | `/sign/in/sentry(.:format)`                              | `auth/org/sign/in/sentries#show`                          | 303         | true       |
| GET    | `/sign/up/sentry(.:format)`                              | `auth/org/sign/up/sentries#show`                          | 303         | true       |
| GET    | `/api/v0/preferences/cookie(.:format)`                   | `auth/org/api/v0/preferences/cookies#show`                | 200         | true       |
| PATCH  | `/api/v0/preferences/cookie(.:format)`                   | `auth/org/api/v0/preferences/cookies#update`              | static-only | unverified |
| GET    | `/api/v0/preferences/theme(.:format)`                    | `auth/org/api/v0/preferences/themes#show`                 | 200         | true       |
| PATCH  | `/api/v0/preferences/theme(.:format)`                    | `auth/org/api/v0/preferences/themes#update`               | static-only | unverified |
| GET    | `/sign/in/passkey/new(.:format)`                         | `auth/org/sign/in/passkeys#new`                           | 400         | true       |
| POST   | `/sign/in/passkey/options(.:format)`                     | `auth/org/sign/in/passkey/options#create`                 | static-only | unverified |
| POST   | `/sign/in/passkey/verification(.:format)`                | `auth/org/sign/in/passkey/verifications#create`           | static-only | unverified |
| GET    | `/sign/in/emergency/passkey/new(.:format)`               | `auth/org/sign/in/emergency/passkeys#new`                 | 400         | true       |
| POST   | `/sign/in/emergency/passkey/options(.:format)`           | `auth/org/sign/in/emergency/passkey/options#create`       | static-only | unverified |
| POST   | `/sign/in/emergency/passkey/verification(.:format)`      | `auth/org/sign/in/emergency/passkey/verifications#create` | static-only | unverified |
| GET    | `/sign/in/check(.:format)`                               | `auth/org/sign/in/checks#show`                            | 400         | true       |
| GET    | `/social/entra/session/new(.:format)`                    | `auth/org/social/sessions#new`                            | 200         | true       |
| POST   | `/social/entra/session(.:format)`                        | `auth/org/social/sessions#create`                         | static-only | unverified |
| GET    | `/social/entra/callback(.:format)`                       | `auth/org/omniauth/omniauth_callbacks#omniauth`           | 302         | false      |
| GET    | `/social/entra/failure(.:format)`                        | `auth/org/omniauth/omniauth_callbacks#failure`            | 422         | true       |
| GET    | `/verification(.:format)`                                | `auth/org/verifications#show`                             | 400         | true       |
| POST   | `/verification/cancellation(.:format)`                   | `auth/org/verification/cancellations#create`              | static-only | unverified |
| GET    | `/verification/setup/new(.:format)`                      | `auth/org/verification/setups#new`                        | 400         | true       |
| GET    | `/verification/handoff(.:format)`                        | `auth/org/verification/handoffs#show`                     | 400         | true       |
| POST   | `/verification/handoff(.:format)`                        | `auth/org/verification/handoffs#create`                   | static-only | unverified |
| POST   | `/verification/passkey/options(.:format)`                | `auth/org/verification/passkeys#options`                  | static-only | unverified |
| GET    | `/verification/passkey/new(.:format)`                    | `auth/org/verification/passkeys#new`                      | 400         | true       |
| POST   | `/verification/passkey(.:format)`                        | `auth/org/verification/passkeys#create`                   | static-only | unverified |
| POST   | `/verification/registration/passkey/options(.:format)`   | `auth/org/verification/registration/passkeys#options`     | static-only | unverified |
| GET    | `/verification/registration/passkey/new(.:format)`       | `auth/org/verification/registration/passkeys#new`         | 400         | true       |
| POST   | `/verification/registration/passkey(.:format)`           | `auth/org/verification/registration/passkeys#create`      | static-only | unverified |
| GET    | `/verification/registration/handoff(.:format)`           | `auth/org/verification/registration/handoffs#show`        | 400         | true       |
| POST   | `/verification/registration/handoff(.:format)`           | `auth/org/verification/registration/handoffs#create`      | static-only | unverified |
| GET    | `/ceremony_bindings/:binding_ref/confirmation(.:format)` | `visa/app/ceremony_binding_confirmations#show`            | 400         | true       |
| GET    | `/.well-known/openid-configuration`                      | `visa/app/well_known/discoveries#show`                    | 200         | true       |
| GET    | `/.well-known/jwks.json`                                 | `visa/app/well_known/jwks#show`                           | 200         | false      |
| GET    | `/health`                                                | `visa/app/healths#show`                                   | 200         | true       |
| GET    | `/health/liveness`                                       | `visa/app/health/livenesses#show`                         | 200         | true       |
| GET    | `/health/readiness`                                      | `visa/app/health/readinesses#show`                        | 200         | true       |
| GET    | `/health/startup`                                        | `visa/app/health/startups#show`                           | 200         | true       |
| GET    | `/api/v0/health.json`                                    | `visa/app/api/v0/healths#show`                            | 200         | true       |
| GET    | `/api/v0/revision.json`                                  | `visa/app/api/v0/revisions#show`                          | 200         | true       |
| POST   | `/api/v0/sensitive_admissions(.:format)`                 | `visa/app/api/v0/sensitive_admissions#create`             | static-only | unverified |
| PATCH  | `/api/v0/sensitive_admission_session(.:format)`          | `visa/app/api/v0/sensitive_admission_sessions#update`     | static-only | unverified |
| PUT    | `/api/v0/sensitive_admission_session(.:format)`          | `visa/app/api/v0/sensitive_admission_sessions#update`     | static-only | unverified |
| POST   | `/api/v0/sensitive_admission_confirmation(.:format)`     | `visa/app/api/v0/sensitive_admission_sessions#create`     | static-only | unverified |
| GET    | `/revision`                                              | `visa/app/revisions#show`                                 | 200         | true       |
| GET    | `/robots.txt(.:format)`                                  | `visa/app/robots#index`                                   | 200         | true       |
| POST   | `/csp-violation-report(.:format)`                        | `visa/app/csp_violation_reports#create`                   | static-only | unverified |
| GET    | `/oauth/authorize(.:format)`                             | `visa/app/oauth/authorizations#show`                      | 400         | true       |
| POST   | `/oauth/authorize(.:format)`                             | `visa/app/oauth/authorizations#create`                    | static-only | unverified |
| POST   | `/oauth/token(.:format)`                                 | `visa/app/oauth/tokens#create`                            | static-only | unverified |
| GET    | `/oauth/userinfo(.:format)`                              | `visa/app/oauth/userinfos#show`                           | 401         | true       |
| POST   | `/oauth/userinfo(.:format)`                              | `visa/app/oauth/userinfos#create`                         | static-only | unverified |
| POST   | `/oauth/revoke(.:format)`                                | `visa/app/oauth/revocations#create`                       | static-only | unverified |
| GET    | `/oidc/logout(.:format)`                                 | `visa/app/oidc/logouts#show`                              | 200         | true       |
| POST   | `/oidc/logout(.:format)`                                 | `visa/app/oidc/logouts#create`                            | static-only | unverified |
| POST   | `/oidc/logout/confirmation(.:format)`                    | `visa/app/oidc/logouts/confirmations#create`              | static-only | unverified |
| GET    | `/oidc/logout/completion(.:format)`                      | `visa/app/oidc/logouts/completions#show`                  | 404         | true       |
| GET    | `/oidc/result(.:format)`                                 | `visa/app/oidc/results#show`                              | 400         | true       |
| GET    | `/oidc/cancellation(.:format)`                           | `visa/app/oidc/cancellations#show`                        | 400         | true       |
| GET    | `/oidc/switch(.:format)`                                 | `visa/app/oidc/switches#show`                             | 400         | true       |
| GET    | `/sign/in/limitation(.:format)`                          | `visa/app/sign/in/limitations#show`                       | 410         | true       |
| PATCH  | `/sign/in/limitation(.:format)`                          | `visa/app/sign/in/limitations#update`                     | static-only | unverified |
| PUT    | `/sign/in/limitation(.:format)`                          | `visa/app/sign/in/limitations#update`                     | static-only | unverified |
| DELETE | `/sign/in/limitation(.:format)`                          | `visa/app/sign/in/limitations#destroy`                    | static-only | unverified |
| POST   | `/sign/in/limitation(.:format)`                          | `visa/app/sign/in/limitations#update`                     | static-only | unverified |
| GET    | `/edge/v0/token/check(.:format)`                         | `visa/app/edge/v0/token/checks#show`                      | 401         | true       |
| POST   | `/edge/v0/token/dbsc(.:format)`                          | `visa/app/edge/v0/token/dbsc#create`                      | static-only | unverified |
| POST   | `/edge/v0/token/refresh(.:format)`                       | `visa/app/edge/v0/token/refreshes#create`                 | static-only | unverified |
| GET    | `/ceremony_bindings/:binding_ref/confirmation(.:format)` | `visa/org/ceremony_binding_confirmations#show`            | 400         | true       |
| GET    | `/.well-known/openid-configuration`                      | `visa/org/well_known/discoveries#show`                    | 200         | true       |
| GET    | `/.well-known/jwks.json`                                 | `visa/org/well_known/jwks#show`                           | 200         | false      |
| GET    | `/health`                                                | `visa/org/healths#show`                                   | 200         | true       |
| GET    | `/health/liveness`                                       | `visa/org/health/livenesses#show`                         | 200         | true       |
| GET    | `/health/readiness`                                      | `visa/org/health/readinesses#show`                        | 200         | true       |
| GET    | `/health/startup`                                        | `visa/org/health/startups#show`                           | 200         | true       |
| GET    | `/api/v0/health.json`                                    | `visa/org/api/v0/healths#show`                            | 200         | true       |
| GET    | `/api/v0/revision.json`                                  | `visa/org/api/v0/revisions#show`                          | 200         | true       |
| POST   | `/api/v0/sensitive_admissions(.:format)`                 | `visa/org/api/v0/sensitive_admissions#create`             | static-only | unverified |
| PATCH  | `/api/v0/sensitive_admission_session(.:format)`          | `visa/org/api/v0/sensitive_admission_sessions#update`     | static-only | unverified |
| PUT    | `/api/v0/sensitive_admission_session(.:format)`          | `visa/org/api/v0/sensitive_admission_sessions#update`     | static-only | unverified |
| POST   | `/api/v0/sensitive_admission_confirmation(.:format)`     | `visa/org/api/v0/sensitive_admission_sessions#create`     | static-only | unverified |
| GET    | `/revision`                                              | `visa/org/revisions#show`                                 | 200         | true       |
| GET    | `/robots.txt(.:format)`                                  | `visa/org/robots#index`                                   | 200         | true       |
| POST   | `/csp-violation-report(.:format)`                        | `visa/org/csp_violation_reports#create`                   | static-only | unverified |
| GET    | `/oauth/authorize(.:format)`                             | `visa/org/oauth/authorizations#show`                      | 400         | true       |
| POST   | `/oauth/authorize(.:format)`                             | `visa/org/oauth/authorizations#create`                    | static-only | unverified |
| POST   | `/oauth/token(.:format)`                                 | `visa/org/oauth/tokens#create`                            | static-only | unverified |
| GET    | `/oauth/userinfo(.:format)`                              | `visa/org/oauth/userinfos#show`                           | 401         | true       |
| POST   | `/oauth/userinfo(.:format)`                              | `visa/org/oauth/userinfos#create`                         | static-only | unverified |
| POST   | `/oauth/revoke(.:format)`                                | `visa/org/oauth/revocations#create`                       | static-only | unverified |
| GET    | `/oidc/logout(.:format)`                                 | `visa/org/oidc/logouts#show`                              | 200         | true       |
| POST   | `/oidc/logout(.:format)`                                 | `visa/org/oidc/logouts#create`                            | static-only | unverified |
| POST   | `/oidc/logout/confirmation(.:format)`                    | `visa/org/oidc/logouts/confirmations#create`              | static-only | unverified |
| GET    | `/oidc/logout/completion(.:format)`                      | `visa/org/oidc/logouts/completions#show`                  | 404         | true       |
| GET    | `/oidc/result(.:format)`                                 | `visa/org/oidc/results#show`                              | 400         | true       |
| GET    | `/oidc/cancellation(.:format)`                           | `visa/org/oidc/cancellations#show`                        | 400         | true       |
| GET    | `/sign/in/limitation(.:format)`                          | `visa/org/sign/in/limitations#show`                       | 410         | true       |
| PATCH  | `/sign/in/limitation(.:format)`                          | `visa/org/sign/in/limitations#update`                     | static-only | unverified |
| PUT    | `/sign/in/limitation(.:format)`                          | `visa/org/sign/in/limitations#update`                     | static-only | unverified |
| DELETE | `/sign/in/limitation(.:format)`                          | `visa/org/sign/in/limitations#destroy`                    | static-only | unverified |
| POST   | `/sign/in/limitation(.:format)`                          | `visa/org/sign/in/limitations#update`                     | static-only | unverified |
| GET    | `/edge/v0/token/check(.:format)`                         | `visa/org/edge/v0/token/checks#show`                      | 401         | true       |
| POST   | `/edge/v0/token/dbsc(.:format)`                          | `visa/org/edge/v0/token/dbsc#create`                      | static-only | unverified |
| POST   | `/edge/v0/token/refresh(.:format)`                       | `visa/org/edge/v0/token/refreshes#create`                 | static-only | unverified |
