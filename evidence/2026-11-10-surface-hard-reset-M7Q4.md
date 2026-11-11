# Surface hard reset evidence — 2026-11-10

## Result and scope

Kept Auth app/org, Visa app/org, Visa OpenID Provider endpoints, JWKS, DBSC, and the explicitly
owned operator tools. Removed routes and code for foreign or retired surfaces and repeated dead-code
cleanup through the newly unreachable callers. No ActiveRecord model classes or migrations were
deleted. One model concern used only by retired surfaces was deleted. No database was dropped. No
commit was made.

Owner direction: preserve the cross-repository OIDC client registrations and their redirect URI host
readers.

- Full `git rev-parse HEAD`: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`
- Worktree state: extensively modified and uncommitted; these results describe the shared worktree,
  not a clean checkout. Existing changes were preserved.

## 1. Route inventory and controller namespaces

Host values are omitted. Route groups are identified by the host constraint owner and the
configuration variable names only. The task-start route listing below was saved before removal; the
final listing is from the final `bin/rails routes` invocation.

### Route counts by host constraint

| Host group                                                                               | Task-start entries | Final entries | Classification                                   |
| ---------------------------------------------------------------------------------------- | -----------------: | ------------: | ------------------------------------------------ |
| Auth app — auth-service host constraint (`auth_service.host`, `PUBLIC_AUTH_SERVICE_URL`) |                139 |           138 | OWN                                              |
| Auth org — auth-staff host constraint (`auth_staff.host`, `PUBLIC_AUTH_STAFF_URL`)       |                 47 |            46 | OWN                                              |
| Visa app — visa-service host constraint (`visa_service.host`, `PUBLIC_VISA_SERVICE_URL`) |                 37 |            37 | OWN                                              |
| Visa org — visa-staff host constraint (`visa_staff.host`, `PUBLIC_VISA_STAFF_URL`)       |                 36 |            36 | OWN                                              |
| Mission — dedicated host constraint (`PUBLIC_MISSION_URL`, `PRIVATE_MISSION_URL`)        |                 25 |            25 | OWN                                              |
| Flipper — dedicated host constraint (`PUBLIC_FLIPPER_URL`, `PRIVATE_FLIPPER_URL`)        |                  1 |             1 | OWN                                              |
| Blazer — dedicated host constraint (`PUBLIC_BLAZER_URL`, `PRIVATE_BLAZER_URL`)           |                 32 |            32 | OWN                                              |
| PgHero — dedicated host constraint (`PUBLIC_PGHERO_URL`, `PRIVATE_PGHERO_URL`)           |                 26 |            26 | OWN                                              |
| Coverband — dedicated host constraint (`PUBLIC_COVERBAND_URL`, `PRIVATE_COVERBAND_URL`)  |                  0 |             0 | OWN                                              |
| Swagger — dedicated host constraint (`PUBLIC_SWAGGER_URL`, `PRIVATE_SWAGGER_URL`)        |                  2 |             2 | OWN                                              |
| No host constraint — Rails framework routes (FOREIGN/RETIRED)                            |                 26 |             0 | FOREIGN/RETIRED                                  |
| No host constraint — unknown-host fallback (OWN)                                         |                  1 |             1 | OWN shared fail-closed fallback                  |
| **Total routes**                                                                         |            **372** |       **344** | **28 FOREIGN/RETIRED removed; 344 OWN retained** |

Six mounted-engine dispatcher rows are included in those totals. They have a blank `Verb` in the
`bin/rails routes` table and are recorded with their host groups below.

### Task-start route inventory from saved `bin/rails routes` output (372 entries)

#### Auth app — auth-service host constraint (`auth_service.host`, `PUBLIC_AUTH_SERVICE_URL`) (139 routes)

- **OWN** `auth_app_well_known_jwks` `GET` `/.well-known/jwks.json` →
  `auth/app/well_known/jwks#show`
- **OWN** `auth_app_revision` `GET` `/revision` → `auth/app/revisions#show`
- **OWN** `auth_app_health` `GET` `/health` → `auth/app/healths#show`
- **OWN** `auth_app_health_liveness` `GET` `/health/liveness` → `auth/app/health/livenesses#show`
- **OWN** `auth_app_health_readiness` `GET` `/health/readiness` → `auth/app/health/readinesses#show`
- **OWN** `auth_app_health_startup` `GET` `/health/startup` → `auth/app/health/startups#show`
- **OWN** `auth_app_api_v0_health` `GET` `/api/v0/health.json` → `auth/app/api/v0/healths#show`
- **OWN** `auth_app_api_v0_revision` `GET` `/api/v0/revision.json` →
  `auth/app/api/v0/revisions#show`
- **OWN** `auth_app_robots` `GET` `/robots.txt(.:format)` → `auth/app/robots#index`
- **OWN** `auth_app_sitemap` `GET` `/sitemap.xml(.:format)` → `auth/app/sitemaps#show`
- **OWN** `auth_app_csp_violation_report` `POST` `/csp-violation-report(.:format)` →
  `auth/app/csp_violation_reports#create`
- **OWN** `auth_app_ceremony_bindings` `GET` `/ceremony_bindings(.:format)` →
  `auth/app/ceremony_bindings#show`
- **RETIRED** `auth_app_pwa_service_worker` `GET` `/service-worker(.:format)` →
  `auth/app/service_worker_retirements#show`
- **OWN** `auth_app_apple_notifications` `POST` `/apple/notifications(.:format)` →
  `auth/app/apple/notifications#create`
- **OWN** `auth_app_sign_up` `GET` `/sign/up(.:format)` → `auth/app/sign/ups#show`
- **OWN** `auth_app_sign_in` `GET` `/sign/in(.:format)` → `auth/app/sign/ins#show`
- **OWN** `auth_app_sign_oidc_handoff` `GET` `/sign/oidc/handoff(.:format)` →
  `auth/app/sign/oidc_handoffs#show`
- **OWN** `auth_app_sign_cancellation` `POST` `/sign/cancellation(.:format)` →
  `auth/app/sign/cancellations#create`
- **OWN** `auth_app_sign_switch` `POST` `/sign/switch(.:format)` → `auth/app/sign/switches#create`
- **OWN** `auth_app_sign_in_sentry` `GET` `/sign/in/sentry(.:format)` →
  `auth/app/sign/in/sentries#show`
- **OWN** `auth_app_sign_up_sentry` `GET` `/sign/up/sentry(.:format)` →
  `auth/app/sign/up/sentries#show`
- **OWN** `auth_app_web_v0_in_email_otp` `POST` `/web/v0/in/email/otp(.:format)` →
  `auth/app/web/v0/in/email/otps#create`
- **OWN** `auth_app_api_v0_preferences_cookie` `GET` `/api/v0/preferences/cookie(.:format)` →
  `auth/app/api/v0/preferences/cookies#show`
- **OWN** `(unnamed)` `PATCH` `/api/v0/preferences/cookie(.:format)` →
  `auth/app/api/v0/preferences/cookies#update`
- **OWN** `auth_app_api_v0_preferences_theme` `GET` `/api/v0/preferences/theme(.:format)` →
  `auth/app/api/v0/preferences/themes#show`
- **OWN** `(unnamed)` `PATCH` `/api/v0/preferences/theme(.:format)` →
  `auth/app/api/v0/preferences/themes#update`
- **OWN** `new_auth_app_sign_up_email` `GET` `/sign/up/email/new(.:format)` →
  `auth/app/sign/up/emails#new`
- **OWN** `auth_app_sign_up_email` `POST` `/sign/up/email(.:format)` →
  `auth/app/sign/up/emails#create`
- **OWN** `new_auth_app_sign_up_telephone` `GET` `/sign/up/telephone/new(.:format)` →
  `auth/app/sign/up/telephones#new`
- **OWN** `auth_app_sign_up_telephone` `POST` `/sign/up/telephone(.:format)` →
  `auth/app/sign/up/telephones#create`
- **OWN** `auth_app_sign_up_guard_apple` `GET` `/sign/up/guard/apple(.:format)` →
  `auth/app/sign/up/guard/apples#show`
- **OWN** `auth_app_sign_up_guard_google` `GET` `/sign/up/guard/google(.:format)` →
  `auth/app/sign/up/guard/googles#show`
- **OWN** `auth_app_sign_up_guard_email` `GET` `/sign/up/guard/email(.:format)` →
  `auth/app/sign/up/guard/emails#show`
- **OWN** `auth_app_sign_up_guard_telephone` `GET` `/sign/up/guard/telephone(.:format)` →
  `auth/app/sign/up/guard/telephones#show`
- **OWN** `auth_app_sign_up_check_apple_confirmation` `GET`
  `/sign/up/check/apple/confirmation(.:format)` → `auth/app/sign/up/check/apple/confirmations#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/apple/confirmation(.:format)` →
  `auth/app/sign/up/check/apple/confirmations#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/apple/confirmation(.:format)` →
  `auth/app/sign/up/check/apple/confirmations#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/apple/confirmation(.:format)` →
  `auth/app/sign/up/check/apple/confirmations#destroy`
- **OWN** `auth_app_sign_up_check_apple_birthdate` `GET` `/sign/up/check/apple/birthdate(.:format)`
  → `auth/app/sign/up/check/apple/birthdates#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/apple/birthdate(.:format)` →
  `auth/app/sign/up/check/apple/birthdates#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/apple/birthdate(.:format)` →
  `auth/app/sign/up/check/apple/birthdates#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/apple/birthdate(.:format)` →
  `auth/app/sign/up/check/apple/birthdates#destroy`
- **OWN** `auth_app_sign_up_check_google_confirmation` `GET`
  `/sign/up/check/google/confirmation(.:format)` →
  `auth/app/sign/up/check/google/confirmations#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/google/confirmation(.:format)` →
  `auth/app/sign/up/check/google/confirmations#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/google/confirmation(.:format)` →
  `auth/app/sign/up/check/google/confirmations#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/google/confirmation(.:format)` →
  `auth/app/sign/up/check/google/confirmations#destroy`
- **OWN** `auth_app_sign_up_check_google_birthdate` `GET`
  `/sign/up/check/google/birthdate(.:format)` → `auth/app/sign/up/check/google/birthdates#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/google/birthdate(.:format)` →
  `auth/app/sign/up/check/google/birthdates#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/google/birthdate(.:format)` →
  `auth/app/sign/up/check/google/birthdates#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/google/birthdate(.:format)` →
  `auth/app/sign/up/check/google/birthdates#destroy`
- **OWN** `auth_app_sign_up_check_email_otp` `GET` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#destroy`
- **OWN** `(unnamed)` `POST` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#create`
- **OWN** `auth_app_sign_up_check_email_birthdate` `GET` `/sign/up/check/email/birthdate(.:format)`
  → `auth/app/sign/up/check/email/birthdates#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/email/birthdate(.:format)` →
  `auth/app/sign/up/check/email/birthdates#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/email/birthdate(.:format)` →
  `auth/app/sign/up/check/email/birthdates#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/email/birthdate(.:format)` →
  `auth/app/sign/up/check/email/birthdates#destroy`
- **OWN** `auth_app_sign_up_check_telephone_otp` `GET` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#destroy`
- **OWN** `(unnamed)` `POST` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#create`
- **OWN** `auth_app_sign_up_check_telephone_passkey` `GET`
  `/sign/up/check/telephone/passkey(.:format)` → `auth/app/sign/up/check/telephone/passkeys#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/telephone/passkey(.:format)` →
  `auth/app/sign/up/check/telephone/passkeys#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/telephone/passkey(.:format)` →
  `auth/app/sign/up/check/telephone/passkeys#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/telephone/passkey(.:format)` →
  `auth/app/sign/up/check/telephone/passkeys#destroy`
- **OWN** `(unnamed)` `POST` `/sign/up/check/telephone/passkey(.:format)` →
  `auth/app/sign/up/check/telephone/passkeys#create`
- **OWN** `reattempt_auth_app_sign_up_check_telephone_secret` `POST`
  `/sign/up/check/telephone/secret/reattempt(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#reattempt`
- **OWN** `auth_app_sign_up_check_telephone_secret` `GET`
  `/sign/up/check/telephone/secret(.:format)` → `auth/app/sign/up/check/telephone/secrets#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/telephone/secret(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/telephone/secret(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/telephone/secret(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#destroy`
- **OWN** `(unnamed)` `POST` `/sign/up/check/telephone/secret(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#create`
- **OWN** `auth_app_sign_up_check_telephone_birthdate` `GET`
  `/sign/up/check/telephone/birthdate(.:format)` →
  `auth/app/sign/up/check/telephone/birthdates#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/telephone/birthdate(.:format)` →
  `auth/app/sign/up/check/telephone/birthdates#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/telephone/birthdate(.:format)` →
  `auth/app/sign/up/check/telephone/birthdates#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/telephone/birthdate(.:format)` →
  `auth/app/sign/up/check/telephone/birthdates#destroy`
- **OWN** `new_auth_app_sign_in_email` `GET` `/sign/in/email/new(.:format)` →
  `auth/app/sign/in/emails#new`
- **OWN** `edit_auth_app_sign_in_email` `GET` `/sign/in/email/edit(.:format)` →
  `auth/app/sign/in/emails#edit`
- **OWN** `auth_app_sign_in_email` `PATCH` `/sign/in/email(.:format)` →
  `auth/app/sign/in/emails#update`
- **OWN** `(unnamed)` `PUT` `/sign/in/email(.:format)` → `auth/app/sign/in/emails#update`
- **OWN** `(unnamed)` `DELETE` `/sign/in/email(.:format)` → `auth/app/sign/in/emails#destroy`
- **OWN** `(unnamed)` `POST` `/sign/in/email(.:format)` → `auth/app/sign/in/emails#create`
- **OWN** `new_auth_app_sign_in_passkey` `GET` `/sign/in/passkey/new(.:format)` →
  `auth/app/sign/in/passkeys#new`
- **OWN** `new_auth_app_sign_in_secret` `GET` `/sign/in/secret/new(.:format)` →
  `auth/app/sign/in/secrets#new`
- **OWN** `auth_app_sign_in_secret` `POST` `/sign/in/secret(.:format)` →
  `auth/app/sign/in/secrets#create`
- **OWN** `auth_app_sign_in_passkey_options` `POST` `/sign/in/passkey/options(.:format)` →
  `auth/app/sign/in/passkey/options#create`
- **OWN** `auth_app_sign_in_passkey_verification` `POST` `/sign/in/passkey/verification(.:format)` →
  `auth/app/sign/in/passkey/verifications#create`
- **OWN** `auth_app_sign_in_check` `GET` `/sign/in/check(.:format)` → `auth/app/sign/in/checks#show`
- **OWN** `auth_app_sign_in_challenge` `GET` `/sign/in/challenge(.:format)` →
  `auth/app/sign/in/challenges#show`
- **OWN** `(unnamed)` `DELETE` `/sign/in/challenge(.:format)` →
  `auth/app/sign/in/challenges#destroy`
- **OWN** `new_auth_app_sign_in_challenge_passkey` `GET` `/sign/in/challenge/passkey/new(.:format)`
  → `auth/app/sign/in/challenge/passkeys#new`
- **OWN** `auth_app_sign_in_challenge_passkey` `POST` `/sign/in/challenge/passkey(.:format)` →
  `auth/app/sign/in/challenge/passkeys#create`
- **OWN** `auth_app_social_link_completion` `POST` `/social/link_completion(.:format)` →
  `auth/app/social/link_completions#create`
- **OWN** `auth_app_social_google_callback` `GET` `/social/google/callback(.:format)` →
  `auth/app/omniauth/omniauth_callbacks#omniauth`
- **OWN** `auth_app_social_apple_callback` `GET` `/social/apple/callback(.:format)` →
  `auth/app/omniauth/omniauth_callbacks#omniauth`
- **OWN** `auth_app_social_failure` `GET` `/social/failure(.:format)` →
  `auth/app/omniauth/omniauth_callbacks#failure`
- **OWN** `auth_app_social_google_session` `POST` `/social/google/session(.:format)` →
  `auth/app/social/sessions#create`
- **OWN** `auth_app_social_google_registration` `POST` `/social/google/registration(.:format)` →
  `auth/app/social/registrations#create`
- **OWN** `auth_app_social_apple_session` `POST` `/social/apple/session(.:format)` →
  `auth/app/social/sessions#create`
- **OWN** `auth_app_social_apple_registration` `POST` `/social/apple/registration(.:format)` →
  `auth/app/social/registrations#create`
- **OWN** `auth_app_verification` `GET` `/verification(.:format)` → `auth/app/verifications#show`
- **OWN** `auth_app_verification_cancellation` `POST` `/verification/cancellation(.:format)` →
  `auth/app/verification/cancellations#create`
- **OWN** `new_auth_app_verification_setup` `GET` `/verification/setup/new(.:format)` →
  `auth/app/verification/setups#new`
- **OWN** `auth_app_verification_handoff` `GET` `/verification/handoff(.:format)` →
  `auth/app/verification/handoffs#show`
- **OWN** `(unnamed)` `POST` `/verification/handoff(.:format)` →
  `auth/app/verification/handoffs#create`
- **OWN** `auth_app_verification_passkey_options` `POST` `/verification/passkey/options(.:format)` →
  `auth/app/verification/passkeys#options`
- **OWN** `new_auth_app_verification_passkey` `GET` `/verification/passkey/new(.:format)` →
  `auth/app/verification/passkeys#new`
- **OWN** `auth_app_verification_passkey` `POST` `/verification/passkey(.:format)` →
  `auth/app/verification/passkeys#create`
- **OWN** `new_auth_app_verification_totp` `GET` `/verification/totp/new(.:format)` →
  `auth/app/verification/totps#new`
- **OWN** `auth_app_verification_totp` `POST` `/verification/totp(.:format)` →
  `auth/app/verification/totps#create`
- **OWN** `auth_app_verification_registration_passkey_options` `POST`
  `/verification/registration/passkey/options(.:format)` →
  `auth/app/verification/registration/passkeys#options`
- **OWN** `new_auth_app_verification_registration_passkey` `GET`
  `/verification/registration/passkey/new(.:format)` →
  `auth/app/verification/registration/passkeys#new`
- **OWN** `auth_app_verification_registration_passkey` `POST`
  `/verification/registration/passkey(.:format)` →
  `auth/app/verification/registration/passkeys#create`
- **OWN** `auth_app_verification_registration_handoff` `GET`
  `/verification/registration/handoff(.:format)` →
  `auth/app/verification/registration/handoffs#show`
- **OWN** `(unnamed)` `POST` `/verification/registration/handoff(.:format)` →
  `auth/app/verification/registration/handoffs#create`
- **OWN** `auth_app_verification_email_redelivery` `POST`
  `/verification/emails/:email_id/redelivery(.:format)` →
  `auth/app/verification/redeliveries#create`
- **OWN** `auth_app_verification_emails` `POST` `/verification/emails(.:format)` →
  `auth/app/verification/emails#create`
- **OWN** `new_auth_app_verification_email` `GET` `/verification/emails/new(.:format)` →
  `auth/app/verification/emails#new`
- **OWN** `edit_auth_app_verification_email` `GET` `/verification/emails/:id/edit(.:format)` →
  `auth/app/verification/emails#edit`
- **OWN** `auth_app_verification_email` `PATCH` `/verification/emails/:id(.:format)` →
  `auth/app/verification/emails#update`
- **OWN** `(unnamed)` `PUT` `/verification/emails/:id(.:format)` →
  `auth/app/verification/emails#update`
- **OWN** `auth_app_settings` `GET` `/settings(.:format)` → `auth/app/settings#show`
- **OWN** `auth_app_settings_totps_enrollment` `DELETE` `/settings/totps/enrollment(.:format)` →
  `auth/app/settings/totps/enrollments#destroy`
- **OWN** `(unnamed)` `POST` `/settings/totps/enrollment(.:format)` →
  `auth/app/settings/totps/enrollments#create`
- **OWN** `auth_app_settings_totps_handoff` `GET` `/settings/totps/handoff(.:format)` →
  `auth/app/settings/totps/handoffs#show`
- **OWN** `(unnamed)` `POST` `/settings/totps/handoff(.:format)` →
  `auth/app/settings/totps/handoffs#create`
- **OWN** `auth_app_settings_totps` `POST` `/settings/totps(.:format)` →
  `auth/app/settings/totps#create`
- **OWN** `new_auth_app_settings_totp` `GET` `/settings/totps/new(.:format)` →
  `auth/app/settings/totps#new`
- **OWN** `edit_auth_app_settings_apple` `GET` `/settings/apple/edit(.:format)` →
  `auth/app/settings/apples#edit`
- **OWN** `auth_app_settings_apple` `GET` `/settings/apple(.:format)` →
  `auth/app/settings/apples#show`
- **OWN** `(unnamed)` `DELETE` `/settings/apple(.:format)` → `auth/app/settings/apples#destroy`
- **OWN** `(unnamed)` `POST` `/settings/apple(.:format)` → `auth/app/settings/apples#create`
- **OWN** `edit_auth_app_settings_google` `GET` `/settings/google/edit(.:format)` →
  `auth/app/settings/googles#edit`
- **OWN** `auth_app_settings_google` `GET` `/settings/google(.:format)` →
  `auth/app/settings/googles#show`
- **OWN** `(unnamed)` `DELETE` `/settings/google(.:format)` → `auth/app/settings/googles#destroy`
- **OWN** `(unnamed)` `POST` `/settings/google(.:format)` → `auth/app/settings/googles#create`

#### Auth org — auth-staff host constraint (`auth_staff.host`, `PUBLIC_AUTH_STAFF_URL`) (47 routes)

- **OWN** `auth_org_well_known_jwks` `GET` `/.well-known/jwks.json` →
  `auth/org/well_known/jwks#show`
- **OWN** `auth_org_revision` `GET` `/revision` → `auth/org/revisions#show`
- **OWN** `auth_org_health` `GET` `/health` → `auth/org/healths#show`
- **OWN** `auth_org_health_liveness` `GET` `/health/liveness` → `auth/org/health/livenesses#show`
- **OWN** `auth_org_health_readiness` `GET` `/health/readiness` → `auth/org/health/readinesses#show`
- **OWN** `auth_org_health_startup` `GET` `/health/startup` → `auth/org/health/startups#show`
- **OWN** `auth_org_api_v0_health` `GET` `/api/v0/health.json` → `auth/org/api/v0/healths#show`
- **OWN** `auth_org_api_v0_revision` `GET` `/api/v0/revision.json` →
  `auth/org/api/v0/revisions#show`
- **OWN** `auth_org_robots` `GET` `/robots.txt(.:format)` → `auth/org/robots#index`
- **OWN** `auth_org_sitemap` `GET` `/sitemap.xml(.:format)` → `auth/org/sitemaps#show`
- **OWN** `auth_org_csp_violation_report` `POST` `/csp-violation-report(.:format)` →
  `auth/org/csp_violation_reports#create`
- **OWN** `auth_org_ceremony_bindings` `GET` `/ceremony_bindings(.:format)` →
  `auth/org/ceremony_bindings#show`
- **RETIRED** `auth_org_pwa_service_worker` `GET` `/service-worker(.:format)` →
  `auth/org/service_worker_retirements#show`
- **OWN** `auth_org_sign_up` `GET` `/sign/up(.:format)` → `auth/org/sign/ups#show`
- **OWN** `auth_org_sign_in` `GET` `/sign/in(.:format)` → `auth/org/sign/ins#show`
- **OWN** `auth_org_sign_oidc_handoff` `GET` `/sign/oidc/handoff(.:format)` →
  `auth/org/sign/oidc_handoffs#show`
- **OWN** `auth_org_sign_cancellation` `POST` `/sign/cancellation(.:format)` →
  `auth/org/sign/cancellations#create`
- **OWN** `auth_org_sign_in_sentry` `GET` `/sign/in/sentry(.:format)` →
  `auth/org/sign/in/sentries#show`
- **OWN** `auth_org_sign_up_sentry` `GET` `/sign/up/sentry(.:format)` →
  `auth/org/sign/up/sentries#show`
- **OWN** `auth_org_api_v0_preferences_cookie` `GET` `/api/v0/preferences/cookie(.:format)` →
  `auth/org/api/v0/preferences/cookies#show`
- **OWN** `(unnamed)` `PATCH` `/api/v0/preferences/cookie(.:format)` →
  `auth/org/api/v0/preferences/cookies#update`
- **OWN** `auth_org_api_v0_preferences_theme` `GET` `/api/v0/preferences/theme(.:format)` →
  `auth/org/api/v0/preferences/themes#show`
- **OWN** `(unnamed)` `PATCH` `/api/v0/preferences/theme(.:format)` →
  `auth/org/api/v0/preferences/themes#update`
- **OWN** `new_auth_org_sign_in_passkey` `GET` `/sign/in/passkey/new(.:format)` →
  `auth/org/sign/in/passkeys#new`
- **OWN** `auth_org_sign_in_passkey_options` `POST` `/sign/in/passkey/options(.:format)` →
  `auth/org/sign/in/passkey/options#create`
- **OWN** `auth_org_sign_in_passkey_verification` `POST` `/sign/in/passkey/verification(.:format)` →
  `auth/org/sign/in/passkey/verifications#create`
- **OWN** `new_auth_org_sign_in_emergency_passkey` `GET` `/sign/in/emergency/passkey/new(.:format)`
  → `auth/org/sign/in/emergency/passkeys#new`
- **OWN** `auth_org_sign_in_emergency_passkey_options` `POST`
  `/sign/in/emergency/passkey/options(.:format)` →
  `auth/org/sign/in/emergency/passkey/options#create`
- **OWN** `auth_org_sign_in_emergency_passkey_verification` `POST`
  `/sign/in/emergency/passkey/verification(.:format)` →
  `auth/org/sign/in/emergency/passkey/verifications#create`
- **OWN** `auth_org_sign_in_check` `GET` `/sign/in/check(.:format)` → `auth/org/sign/in/checks#show`
- **OWN** `new_auth_org_social_entra_session` `GET` `/social/entra/session/new(.:format)` →
  `auth/org/social/sessions#new`
- **OWN** `auth_org_social_entra_session` `POST` `/social/entra/session(.:format)` →
  `auth/org/social/sessions#create`
- **OWN** `auth_org_social_entra_callback` `GET` `/social/entra/callback(.:format)` →
  `auth/org/omniauth/omniauth_callbacks#omniauth`
- **OWN** `auth_org_social_entra_failure` `GET` `/social/entra/failure(.:format)` →
  `auth/org/omniauth/omniauth_callbacks#failure`
- **OWN** `auth_org_verification` `GET` `/verification(.:format)` → `auth/org/verifications#show`
- **OWN** `auth_org_verification_cancellation` `POST` `/verification/cancellation(.:format)` →
  `auth/org/verification/cancellations#create`
- **OWN** `new_auth_org_verification_setup` `GET` `/verification/setup/new(.:format)` →
  `auth/org/verification/setups#new`
- **OWN** `auth_org_verification_handoff` `GET` `/verification/handoff(.:format)` →
  `auth/org/verification/handoffs#show`
- **OWN** `(unnamed)` `POST` `/verification/handoff(.:format)` →
  `auth/org/verification/handoffs#create`
- **OWN** `auth_org_verification_passkey_options` `POST` `/verification/passkey/options(.:format)` →
  `auth/org/verification/passkeys#options`
- **OWN** `new_auth_org_verification_passkey` `GET` `/verification/passkey/new(.:format)` →
  `auth/org/verification/passkeys#new`
- **OWN** `auth_org_verification_passkey` `POST` `/verification/passkey(.:format)` →
  `auth/org/verification/passkeys#create`
- **OWN** `auth_org_verification_registration_passkey_options` `POST`
  `/verification/registration/passkey/options(.:format)` →
  `auth/org/verification/registration/passkeys#options`
- **OWN** `new_auth_org_verification_registration_passkey` `GET`
  `/verification/registration/passkey/new(.:format)` →
  `auth/org/verification/registration/passkeys#new`
- **OWN** `auth_org_verification_registration_passkey` `POST`
  `/verification/registration/passkey(.:format)` →
  `auth/org/verification/registration/passkeys#create`
- **OWN** `auth_org_verification_registration_handoff` `GET`
  `/verification/registration/handoff(.:format)` →
  `auth/org/verification/registration/handoffs#show`
- **OWN** `(unnamed)` `POST` `/verification/registration/handoff(.:format)` →
  `auth/org/verification/registration/handoffs#create`

#### Visa app — visa-service host constraint (`visa_service.host`, `PUBLIC_VISA_SERVICE_URL`) (37 routes)

- **OWN** `visa_app_ceremony_binding_confirmation` `GET`
  `/ceremony_bindings/:binding_ref/confirmation(.:format)` →
  `visa/app/ceremony_binding_confirmations#show`
- **OWN** `visa_app_well_known_openid_configuration` `GET` `/.well-known/openid-configuration` →
  `visa/app/well_known/discoveries#show`
- **OWN** `visa_app_well_known_jwks` `GET` `/.well-known/jwks.json` →
  `visa/app/well_known/jwks#show`
- **OWN** `visa_app_health` `GET` `/health` → `visa/app/healths#show`
- **OWN** `visa_app_health_liveness` `GET` `/health/liveness` → `visa/app/health/livenesses#show`
- **OWN** `visa_app_health_readiness` `GET` `/health/readiness` → `visa/app/health/readinesses#show`
- **OWN** `visa_app_health_startup` `GET` `/health/startup` → `visa/app/health/startups#show`
- **OWN** `visa_app_api_v0_health` `GET` `/api/v0/health.json` → `visa/app/api/v0/healths#show`
- **OWN** `visa_app_api_v0_revision` `GET` `/api/v0/revision.json` →
  `visa/app/api/v0/revisions#show`
- **OWN** `visa_app_api_v0_sensitive_admissions` `POST` `/api/v0/sensitive_admissions(.:format)` →
  `visa/app/api/v0/sensitive_admissions#create`
- **OWN** `visa_app_api_v0_sensitive_admission_session` `PATCH`
  `/api/v0/sensitive_admission_session(.:format)` →
  `visa/app/api/v0/sensitive_admission_sessions#update`
- **OWN** `(unnamed)` `PUT` `/api/v0/sensitive_admission_session(.:format)` →
  `visa/app/api/v0/sensitive_admission_sessions#update`
- **OWN** `visa_app_api_v0_sensitive_admission_confirmation` `POST`
  `/api/v0/sensitive_admission_confirmation(.:format)` →
  `visa/app/api/v0/sensitive_admission_sessions#create`
- **OWN** `visa_app_revision` `GET` `/revision` → `visa/app/revisions#show`
- **OWN** `visa_app_robots` `GET` `/robots.txt(.:format)` → `visa/app/robots#index`
- **OWN** `visa_app_csp_violation_report` `POST` `/csp-violation-report(.:format)` →
  `visa/app/csp_violation_reports#create`
- **OWN** `visa_app_oauth_authorization` `GET` `/oauth/authorize(.:format)` →
  `visa/app/oauth/authorizations#show`
- **OWN** `(unnamed)` `POST` `/oauth/authorize(.:format)` → `visa/app/oauth/authorizations#create`
- **OWN** `visa_app_oauth_token` `POST` `/oauth/token(.:format)` → `visa/app/oauth/tokens#create`
- **OWN** `visa_app_oauth_userinfo` `GET` `/oauth/userinfo(.:format)` →
  `visa/app/oauth/userinfos#show`
- **OWN** `(unnamed)` `POST` `/oauth/userinfo(.:format)` → `visa/app/oauth/userinfos#create`
- **OWN** `visa_app_oauth_revocation` `POST` `/oauth/revoke(.:format)` →
  `visa/app/oauth/revocations#create`
- **OWN** `visa_app_oidc_logout` `GET` `/oidc/logout(.:format)` → `visa/app/oidc/logouts#show`
- **OWN** `(unnamed)` `POST` `/oidc/logout(.:format)` → `visa/app/oidc/logouts#create`
- **OWN** `visa_app_oidc_logout_confirmation` `POST` `/oidc/logout/confirmation(.:format)` →
  `visa/app/oidc/logouts/confirmations#create`
- **OWN** `visa_app_oidc_logout_completion` `GET` `/oidc/logout/completion(.:format)` →
  `visa/app/oidc/logouts/completions#show`
- **OWN** `visa_app_oidc_result` `GET` `/oidc/result(.:format)` → `visa/app/oidc/results#show`
- **OWN** `visa_app_oidc_cancellation` `GET` `/oidc/cancellation(.:format)` →
  `visa/app/oidc/cancellations#show`
- **OWN** `visa_app_oidc_switch` `GET` `/oidc/switch(.:format)` → `visa/app/oidc/switches#show`
- **OWN** `visa_app_sign_in_limitation` `GET` `/sign/in/limitation(.:format)` →
  `visa/app/sign/in/limitations#show`
- **OWN** `(unnamed)` `PATCH` `/sign/in/limitation(.:format)` →
  `visa/app/sign/in/limitations#update`
- **OWN** `(unnamed)` `PUT` `/sign/in/limitation(.:format)` → `visa/app/sign/in/limitations#update`
- **OWN** `(unnamed)` `DELETE` `/sign/in/limitation(.:format)` →
  `visa/app/sign/in/limitations#destroy`
- **OWN** `visa_app_sign_in_limitation_continue` `POST` `/sign/in/limitation(.:format)` →
  `visa/app/sign/in/limitations#update`
- **OWN** `visa_app_edge_v0_token_check` `GET` `/edge/v0/token/check(.:format)` →
  `visa/app/edge/v0/token/checks#show`
- **OWN** `visa_app_edge_v0_token_dbsc` `POST` `/edge/v0/token/dbsc(.:format)` →
  `visa/app/edge/v0/token/dbsc#create`
- **OWN** `visa_app_edge_v0_token_refresh` `POST` `/edge/v0/token/refresh(.:format)` →
  `visa/app/edge/v0/token/refreshes#create`

#### Visa org — visa-staff host constraint (`visa_staff.host`, `PUBLIC_VISA_STAFF_URL`) (36 routes)

- **OWN** `visa_org_ceremony_binding_confirmation` `GET`
  `/ceremony_bindings/:binding_ref/confirmation(.:format)` →
  `visa/org/ceremony_binding_confirmations#show`
- **OWN** `visa_org_well_known_openid_configuration` `GET` `/.well-known/openid-configuration` →
  `visa/org/well_known/discoveries#show`
- **OWN** `visa_org_well_known_jwks` `GET` `/.well-known/jwks.json` →
  `visa/org/well_known/jwks#show`
- **OWN** `visa_org_health` `GET` `/health` → `visa/org/healths#show`
- **OWN** `visa_org_health_liveness` `GET` `/health/liveness` → `visa/org/health/livenesses#show`
- **OWN** `visa_org_health_readiness` `GET` `/health/readiness` → `visa/org/health/readinesses#show`
- **OWN** `visa_org_health_startup` `GET` `/health/startup` → `visa/org/health/startups#show`
- **OWN** `visa_org_api_v0_health` `GET` `/api/v0/health.json` → `visa/org/api/v0/healths#show`
- **OWN** `visa_org_api_v0_revision` `GET` `/api/v0/revision.json` →
  `visa/org/api/v0/revisions#show`
- **OWN** `visa_org_api_v0_sensitive_admissions` `POST` `/api/v0/sensitive_admissions(.:format)` →
  `visa/org/api/v0/sensitive_admissions#create`
- **OWN** `visa_org_api_v0_sensitive_admission_session` `PATCH`
  `/api/v0/sensitive_admission_session(.:format)` →
  `visa/org/api/v0/sensitive_admission_sessions#update`
- **OWN** `(unnamed)` `PUT` `/api/v0/sensitive_admission_session(.:format)` →
  `visa/org/api/v0/sensitive_admission_sessions#update`
- **OWN** `visa_org_api_v0_sensitive_admission_confirmation` `POST`
  `/api/v0/sensitive_admission_confirmation(.:format)` →
  `visa/org/api/v0/sensitive_admission_sessions#create`
- **OWN** `visa_org_revision` `GET` `/revision` → `visa/org/revisions#show`
- **OWN** `visa_org_robots` `GET` `/robots.txt(.:format)` → `visa/org/robots#index`
- **OWN** `visa_org_csp_violation_report` `POST` `/csp-violation-report(.:format)` →
  `visa/org/csp_violation_reports#create`
- **OWN** `visa_org_oauth_authorization` `GET` `/oauth/authorize(.:format)` →
  `visa/org/oauth/authorizations#show`
- **OWN** `(unnamed)` `POST` `/oauth/authorize(.:format)` → `visa/org/oauth/authorizations#create`
- **OWN** `visa_org_oauth_token` `POST` `/oauth/token(.:format)` → `visa/org/oauth/tokens#create`
- **OWN** `visa_org_oauth_userinfo` `GET` `/oauth/userinfo(.:format)` →
  `visa/org/oauth/userinfos#show`
- **OWN** `(unnamed)` `POST` `/oauth/userinfo(.:format)` → `visa/org/oauth/userinfos#create`
- **OWN** `visa_org_oauth_revocation` `POST` `/oauth/revoke(.:format)` →
  `visa/org/oauth/revocations#create`
- **OWN** `visa_org_oidc_logout` `GET` `/oidc/logout(.:format)` → `visa/org/oidc/logouts#show`
- **OWN** `(unnamed)` `POST` `/oidc/logout(.:format)` → `visa/org/oidc/logouts#create`
- **OWN** `visa_org_oidc_logout_confirmation` `POST` `/oidc/logout/confirmation(.:format)` →
  `visa/org/oidc/logouts/confirmations#create`
- **OWN** `visa_org_oidc_logout_completion` `GET` `/oidc/logout/completion(.:format)` →
  `visa/org/oidc/logouts/completions#show`
- **OWN** `visa_org_oidc_result` `GET` `/oidc/result(.:format)` → `visa/org/oidc/results#show`
- **OWN** `visa_org_oidc_cancellation` `GET` `/oidc/cancellation(.:format)` →
  `visa/org/oidc/cancellations#show`
- **OWN** `visa_org_sign_in_limitation` `GET` `/sign/in/limitation(.:format)` →
  `visa/org/sign/in/limitations#show`
- **OWN** `(unnamed)` `PATCH` `/sign/in/limitation(.:format)` →
  `visa/org/sign/in/limitations#update`
- **OWN** `(unnamed)` `PUT` `/sign/in/limitation(.:format)` → `visa/org/sign/in/limitations#update`
- **OWN** `(unnamed)` `DELETE` `/sign/in/limitation(.:format)` →
  `visa/org/sign/in/limitations#destroy`
- **OWN** `visa_org_sign_in_limitation_continue` `POST` `/sign/in/limitation(.:format)` →
  `visa/org/sign/in/limitations#update`
- **OWN** `visa_org_edge_v0_token_check` `GET` `/edge/v0/token/check(.:format)` →
  `visa/org/edge/v0/token/checks#show`
- **OWN** `visa_org_edge_v0_token_dbsc` `POST` `/edge/v0/token/dbsc(.:format)` →
  `visa/org/edge/v0/token/dbsc#create`
- **OWN** `visa_org_edge_v0_token_refresh` `POST` `/edge/v0/token/refresh(.:format)` →
  `visa/org/edge/v0/token/refreshes#create`

#### Mission — dedicated host constraint (`PUBLIC_MISSION_URL`, `PRIVATE_MISSION_URL`) (25 routes)

- **OWN** `application_queue_pause` `DELETE`
  `/applications/:application_id/queues/:queue_id/pause(.:format)` →
  `mission_control/jobs/queues/pauses#destroy`
- **OWN** `(unnamed)` `POST` `/applications/:application_id/queues/:queue_id/pause(.:format)` →
  `mission_control/jobs/queues/pauses#create`
- **OWN** `application_queues` `GET` `/applications/:application_id/queues(.:format)` →
  `mission_control/jobs/queues#index`
- **OWN** `application_queue` `GET` `/applications/:application_id/queues/:id(.:format)` →
  `mission_control/jobs/queues#show`
- **OWN** `application_job_retry` `POST`
  `/applications/:application_id/jobs/:job_id/retry(.:format)` →
  `mission_control/jobs/retries#create`
- **OWN** `application_job_discard` `POST`
  `/applications/:application_id/jobs/:job_id/discard(.:format)` →
  `mission_control/jobs/discards#create`
- **OWN** `application_job_dispatch` `POST`
  `/applications/:application_id/jobs/:job_id/dispatch(.:format)` →
  `mission_control/jobs/dispatches#create`
- **OWN** `application_bulk_retries` `POST`
  `/applications/:application_id/jobs/bulk_retries(.:format)` →
  `mission_control/jobs/bulk_retries#create`
- **OWN** `application_bulk_discards` `POST`
  `/applications/:application_id/jobs/bulk_discards(.:format)` →
  `mission_control/jobs/bulk_discards#create`
- **OWN** `application_job` `GET` `/applications/:application_id/jobs/:id(.:format)` →
  `mission_control/jobs/jobs#show`
- **OWN** `application_jobs` `GET` `/applications/:application_id/:status/jobs(.:format)` →
  `mission_control/jobs/jobs#index`
- **OWN** `application_workers` `GET` `/applications/:application_id/workers(.:format)` →
  `mission_control/jobs/workers#index`
- **OWN** `application_worker` `GET` `/applications/:application_id/workers/:id(.:format)` →
  `mission_control/jobs/workers#show`
- **OWN** `application_recurring_tasks` `GET`
  `/applications/:application_id/recurring_tasks(.:format)` →
  `mission_control/jobs/recurring_tasks#index`
- **OWN** `application_recurring_task` `GET`
  `/applications/:application_id/recurring_tasks/:id(.:format)` →
  `mission_control/jobs/recurring_tasks#show`
- **OWN** `(unnamed)` `PATCH` `/applications/:application_id/recurring_tasks/:id(.:format)` →
  `mission_control/jobs/recurring_tasks#update`
- **OWN** `(unnamed)` `PUT` `/applications/:application_id/recurring_tasks/:id(.:format)` →
  `mission_control/jobs/recurring_tasks#update`
- **OWN** `application_batches` `GET` `/applications/:application_id/batches(.:format)` →
  `mission_control/jobs/batches#index`
- **OWN** `application_batch` `GET` `/applications/:application_id/batches/:id(.:format)` →
  `mission_control/jobs/batches#show`
- **OWN** `queues` `GET` `/queues(.:format)` → `mission_control/jobs/queues#index`
- **OWN** `queue` `GET` `/queues/:id(.:format)` → `mission_control/jobs/queues#show`
- **OWN** `job` `GET` `/jobs/:id(.:format)` → `mission_control/jobs/jobs#show`
- **OWN** `jobs` `GET` `/:status/jobs(.:format)` → `mission_control/jobs/jobs#index`
- **OWN** `root` `GET` `/` → `mission_control/jobs/queues#index`

#### Flipper — dedicated host constraint (`PUBLIC_FLIPPER_URL`, `PRIVATE_FLIPPER_URL`) (1 route)

- No route entries in this `bin/rails routes` invocation.

#### Blazer — dedicated host constraint (`PUBLIC_BLAZER_URL`, `PRIVATE_BLAZER_URL`) (32 routes)

- **OWN** `run_queries` `POST` `/queries/run(.:format)` → `blazer/queries#run`
- **OWN** `cancel_queries` `POST` `/queries/cancel(.:format)` → `blazer/queries#cancel`
- **OWN** `refresh_query` `POST` `/queries/:id/refresh(.:format)` → `blazer/queries#refresh`
- **OWN** `tables_queries` `GET` `/queries/tables(.:format)` → `blazer/queries#tables`
- **OWN** `schema_queries` `GET` `/queries/schema(.:format)` → `blazer/queries#schema`
- **OWN** `docs_queries` `GET` `/queries/docs(.:format)` → `blazer/queries#docs`
- **OWN** `queries` `GET` `/queries(.:format)` → `blazer/queries#index`
- **OWN** `(unnamed)` `POST` `/queries(.:format)` → `blazer/queries#create`
- **OWN** `new_query` `GET` `/queries/new(.:format)` → `blazer/queries#new`
- **OWN** `edit_query` `GET` `/queries/:id/edit(.:format)` → `blazer/queries#edit`
- **OWN** `query` `GET` `/queries/:id(.:format)` → `blazer/queries#show`
- **OWN** `(unnamed)` `PATCH` `/queries/:id(.:format)` → `blazer/queries#update`
- **OWN** `(unnamed)` `PUT` `/queries/:id(.:format)` → `blazer/queries#update`
- **OWN** `(unnamed)` `DELETE` `/queries/:id(.:format)` → `blazer/queries#destroy`
- **OWN** `run_check` `GET` `/checks/:id/run(.:format)` → `blazer/checks#run`
- **OWN** `checks` `GET` `/checks(.:format)` → `blazer/checks#index`
- **OWN** `(unnamed)` `POST` `/checks(.:format)` → `blazer/checks#create`
- **OWN** `new_check` `GET` `/checks/new(.:format)` → `blazer/checks#new`
- **OWN** `edit_check` `GET` `/checks/:id/edit(.:format)` → `blazer/checks#edit`
- **OWN** `check` `PATCH` `/checks/:id(.:format)` → `blazer/checks#update`
- **OWN** `(unnamed)` `PUT` `/checks/:id(.:format)` → `blazer/checks#update`
- **OWN** `(unnamed)` `DELETE` `/checks/:id(.:format)` → `blazer/checks#destroy`
- **OWN** `refresh_dashboard` `POST` `/dashboards/:id/refresh(.:format)` →
  `blazer/dashboards#refresh`
- **OWN** `dashboards` `POST` `/dashboards(.:format)` → `blazer/dashboards#create`
- **OWN** `new_dashboard` `GET` `/dashboards/new(.:format)` → `blazer/dashboards#new`
- **OWN** `edit_dashboard` `GET` `/dashboards/:id/edit(.:format)` → `blazer/dashboards#edit`
- **OWN** `dashboard` `GET` `/dashboards/:id(.:format)` → `blazer/dashboards#show`
- **OWN** `(unnamed)` `PATCH` `/dashboards/:id(.:format)` → `blazer/dashboards#update`
- **OWN** `(unnamed)` `PUT` `/dashboards/:id(.:format)` → `blazer/dashboards#update`
- **OWN** `(unnamed)` `DELETE` `/dashboards/:id(.:format)` → `blazer/dashboards#destroy`
- **OWN** `root` `GET` `/` → `blazer/queries#home`

#### PgHero — dedicated host constraint (`PUBLIC_PGHERO_URL`, `PRIVATE_PGHERO_URL`) (26 routes)

- **OWN** `space` `GET` `(/:database)/space(.:format)` → `pg_hero/home#space`
- **OWN** `relation_space` `GET` `(/:database)/space/:relation(.:format)` →
  `pg_hero/home#relation_space`
- **OWN** `index_bloat` `GET` `(/:database)/index_bloat(.:format)` → `pg_hero/home#index_bloat`
- **OWN** `live_queries` `GET` `(/:database)/live_queries(.:format)` → `pg_hero/home#live_queries`
- **OWN** `queries` `GET` `(/:database)/queries(.:format)` → `pg_hero/home#queries`
- **OWN** `show_query` `GET` `(/:database)/queries/:query_hash(.:format)` →
  `pg_hero/home#show_query`
- **OWN** `system` `GET` `(/:database)/system(.:format)` → `pg_hero/home#system`
- **OWN** `cpu_usage` `GET` `(/:database)/cpu_usage(.:format)` → `pg_hero/home#cpu_usage`
- **OWN** `connection_stats` `GET` `(/:database)/connection_stats(.:format)` →
  `pg_hero/home#connection_stats`
- **OWN** `replication_lag_stats` `GET` `(/:database)/replication_lag_stats(.:format)` →
  `pg_hero/home#replication_lag_stats`
- **OWN** `load_stats` `GET` `(/:database)/load_stats(.:format)` → `pg_hero/home#load_stats`
- **OWN** `free_space_stats` `GET` `(/:database)/free_space_stats(.:format)` →
  `pg_hero/home#free_space_stats`
- **OWN** `explain` `GET` `(/:database)/explain(.:format)` → `pg_hero/home#explain`
- **OWN** `tune` `GET` `(/:database)/tune(.:format)` → `pg_hero/home#tune`
- **OWN** `connections` `GET` `(/:database)/connections(.:format)` → `pg_hero/home#connections`
- **OWN** `maintenance` `GET` `(/:database)/maintenance(.:format)` → `pg_hero/home#maintenance`
- **OWN** `kill` `POST` `(/:database)/kill(.:format)` → `pg_hero/home#kill`
- **OWN** `kill_long_running_queries` `POST` `(/:database)/kill_long_running_queries(.:format)` →
  `pg_hero/home#kill_long_running_queries`
- **OWN** `kill_all` `POST` `(/:database)/kill_all(.:format)` → `pg_hero/home#kill_all`
- **OWN** `enable_query_stats` `POST` `(/:database)/enable_query_stats(.:format)` →
  `pg_hero/home#enable_query_stats`
- **OWN** `(unnamed)` `POST` `(/:database)/explain(.:format)` → `pg_hero/home#explain`
- **OWN** `reset_query_stats` `POST` `(/:database)/reset_query_stats(.:format)` →
  `pg_hero/home#reset_query_stats`
- **OWN** `system_stats` `GET` `(/:database)/system_stats(.:format)` → `(no controller action)`
- **OWN** `query_stats` `GET` `(/:database)/query_stats(.:format)` → `(no controller action)`
- **OWN** `root` `GET` `/(:database)(.:format)` → `pg_hero/home#index`

#### Coverband — dedicated host constraint (`PUBLIC_COVERBAND_URL`, `PRIVATE_COVERBAND_URL`) (0 routes)

- No route entries in this `bin/rails routes` invocation.

#### Swagger — dedicated host constraint (`PUBLIC_SWAGGER_URL`, `PRIVATE_SWAGGER_URL`) (2 routes)

- No route entries in this `bin/rails routes` invocation.

#### No host constraint — Rails framework routes (FOREIGN/RETIRED) (26 routes)

- **FOREIGN/RETIRED** `turbo_recede_historical_location` `GET`
  `/recede_historical_location(.:format)` → `turbo/native/navigation#recede`
- **FOREIGN/RETIRED** `turbo_resume_historical_location` `GET`
  `/resume_historical_location(.:format)` → `turbo/native/navigation#resume`
- **FOREIGN/RETIRED** `turbo_refresh_historical_location` `GET`
  `/refresh_historical_location(.:format)` → `turbo/native/navigation#refresh`
- **FOREIGN/RETIRED** `rails_postmark_inbound_emails` `POST`
  `/rails/action_mailbox/postmark/inbound_emails(.:format)` →
  `action_mailbox/ingresses/postmark/inbound_emails#create`
- **FOREIGN/RETIRED** `rails_relay_inbound_emails` `POST`
  `/rails/action_mailbox/relay/inbound_emails(.:format)` →
  `action_mailbox/ingresses/relay/inbound_emails#create`
- **FOREIGN/RETIRED** `rails_sendgrid_inbound_emails` `POST`
  `/rails/action_mailbox/sendgrid/inbound_emails(.:format)` →
  `action_mailbox/ingresses/sendgrid/inbound_emails#create`
- **FOREIGN/RETIRED** `rails_mandrill_inbound_health_check` `GET`
  `/rails/action_mailbox/mandrill/inbound_emails(.:format)` →
  `action_mailbox/ingresses/mandrill/inbound_emails#health_check`
- **FOREIGN/RETIRED** `rails_mandrill_inbound_emails` `POST`
  `/rails/action_mailbox/mandrill/inbound_emails(.:format)` →
  `action_mailbox/ingresses/mandrill/inbound_emails#create`
- **FOREIGN/RETIRED** `rails_mailgun_inbound_emails` `POST`
  `/rails/action_mailbox/mailgun/inbound_emails/mime(.:format)` →
  `action_mailbox/ingresses/mailgun/inbound_emails#create`
- **FOREIGN/RETIRED** `rails_conductor_inbound_emails` `GET`
  `/rails/conductor/action_mailbox/inbound_emails(.:format)` →
  `rails/conductor/action_mailbox/inbound_emails#index`
- **FOREIGN/RETIRED** `(unnamed)` `POST` `/rails/conductor/action_mailbox/inbound_emails(.:format)`
  → `rails/conductor/action_mailbox/inbound_emails#create`
- **FOREIGN/RETIRED** `new_rails_conductor_inbound_email` `GET`
  `/rails/conductor/action_mailbox/inbound_emails/new(.:format)` →
  `rails/conductor/action_mailbox/inbound_emails#new`
- **FOREIGN/RETIRED** `rails_conductor_inbound_email` `GET`
  `/rails/conductor/action_mailbox/inbound_emails/:id(.:format)` →
  `rails/conductor/action_mailbox/inbound_emails#show`
- **FOREIGN/RETIRED** `new_rails_conductor_inbound_email_source` `GET`
  `/rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)` →
  `rails/conductor/action_mailbox/inbound_emails/sources#new`
- **FOREIGN/RETIRED** `rails_conductor_inbound_email_sources` `POST`
  `/rails/conductor/action_mailbox/inbound_emails/sources(.:format)` →
  `rails/conductor/action_mailbox/inbound_emails/sources#create`
- **FOREIGN/RETIRED** `rails_conductor_inbound_email_reroute` `POST`
  `/rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)` →
  `rails/conductor/action_mailbox/reroutes#create`
- **FOREIGN/RETIRED** `rails_conductor_inbound_email_incinerate` `POST`
  `/rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)` →
  `rails/conductor/action_mailbox/incinerates#create`
- **FOREIGN/RETIRED** `rails_service_blob` `GET`
  `/rails/active_storage/blobs/redirect/:signed_id/*filename(.:format)` →
  `active_storage/blobs/redirect#show`
- **FOREIGN/RETIRED** `rails_service_blob_proxy` `GET`
  `/rails/active_storage/blobs/proxy/:signed_id/*filename(.:format)` →
  `active_storage/blobs/proxy#show`
- **FOREIGN/RETIRED** `(unnamed)` `GET` `/rails/active_storage/blobs/:signed_id/*filename(.:format)`
  → `active_storage/blobs/redirect#show`
- **FOREIGN/RETIRED** `rails_blob_representation` `GET`
  `/rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format)`
  → `active_storage/representations/redirect#show`
- **FOREIGN/RETIRED** `rails_blob_representation_proxy` `GET`
  `/rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)` →
  `active_storage/representations/proxy#show`
- **FOREIGN/RETIRED** `(unnamed)` `GET`
  `/rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)` →
  `active_storage/representations/redirect#show`
- **FOREIGN/RETIRED** `rails_disk_service` `GET`
  `/rails/active_storage/disk/:encoded_key/*filename(.:format)` → `active_storage/disk#show`
- **FOREIGN/RETIRED** `update_rails_disk_service` `PUT`
  `/rails/active_storage/disk/:encoded_token(.:format)` → `active_storage/disk#update`
- **FOREIGN/RETIRED** `rails_direct_uploads` `POST` `/rails/active_storage/direct_uploads(.:format)`
  → `active_storage/direct_uploads#create`

#### No host constraint — unknown-host fallback (OWN) (1 routes)

- **OWN** `(unnamed)` `GET` `/` → `unknown_hosts#show`

### Final route inventory — every listed route is OWN

### Mounted operator tool dispatcher routes — present in both inventories

| Host group | Name                   | Verb  | Path       | Target                                   | Classification |
| ---------- | ---------------------- | ----- | ---------- | ---------------------------------------- | -------------- |
| Mission    | `mission_control_jobs` | blank | `/`        | `MissionControl::Jobs::Engine`           | OWN            |
| Flipper    | `flipper`              | blank | `/`        | `Flipper::UI` behind `Rack::Auth::Basic` | OWN            |
| Blazer     | `blazer`               | blank | `/`        | `Blazer::Engine`                         | OWN            |
| PgHero     | `pghero`               | blank | `/`        | `PgHero::Engine`                         | OWN            |
| Swagger    | `rswag_api`            | blank | `/openapi` | `Rswag::Api::Engine`                     | OWN            |
| Swagger    | `rswag_ui`             | blank | `/`        | `Rswag::Ui::Engine`                      | OWN            |

### Final `bin/rails routes` inventory (344 entries)

#### Auth app — auth-service host constraint (`auth_service.host`, `PUBLIC_AUTH_SERVICE_URL`) (138 routes)

- **OWN** `auth_app_well_known_jwks` `GET` `/.well-known/jwks.json` →
  `auth/app/well_known/jwks#show`
- **OWN** `auth_app_revision` `GET` `/revision` → `auth/app/revisions#show`
- **OWN** `auth_app_health` `GET` `/health` → `auth/app/healths#show`
- **OWN** `auth_app_health_liveness` `GET` `/health/liveness` → `auth/app/health/livenesses#show`
- **OWN** `auth_app_health_readiness` `GET` `/health/readiness` → `auth/app/health/readinesses#show`
- **OWN** `auth_app_health_startup` `GET` `/health/startup` → `auth/app/health/startups#show`
- **OWN** `auth_app_api_v0_health` `GET` `/api/v0/health.json` → `auth/app/api/v0/healths#show`
- **OWN** `auth_app_api_v0_revision` `GET` `/api/v0/revision.json` →
  `auth/app/api/v0/revisions#show`
- **OWN** `auth_app_robots` `GET` `/robots.txt(.:format)` → `auth/app/robots#index`
- **OWN** `auth_app_sitemap` `GET` `/sitemap.xml(.:format)` → `auth/app/sitemaps#show`
- **OWN** `auth_app_csp_violation_report` `POST` `/csp-violation-report(.:format)` →
  `auth/app/csp_violation_reports#create`
- **OWN** `auth_app_ceremony_bindings` `GET` `/ceremony_bindings(.:format)` →
  `auth/app/ceremony_bindings#show`
- **OWN** `auth_app_apple_notifications` `POST` `/apple/notifications(.:format)` →
  `auth/app/apple/notifications#create`
- **OWN** `auth_app_sign_up` `GET` `/sign/up(.:format)` → `auth/app/sign/ups#show`
- **OWN** `auth_app_sign_in` `GET` `/sign/in(.:format)` → `auth/app/sign/ins#show`
- **OWN** `auth_app_sign_oidc_handoff` `GET` `/sign/oidc/handoff(.:format)` →
  `auth/app/sign/oidc_handoffs#show`
- **OWN** `auth_app_sign_cancellation` `POST` `/sign/cancellation(.:format)` →
  `auth/app/sign/cancellations#create`
- **OWN** `auth_app_sign_switch` `POST` `/sign/switch(.:format)` → `auth/app/sign/switches#create`
- **OWN** `auth_app_sign_in_sentry` `GET` `/sign/in/sentry(.:format)` →
  `auth/app/sign/in/sentries#show`
- **OWN** `auth_app_sign_up_sentry` `GET` `/sign/up/sentry(.:format)` →
  `auth/app/sign/up/sentries#show`
- **OWN** `auth_app_web_v0_in_email_otp` `POST` `/web/v0/in/email/otp(.:format)` →
  `auth/app/web/v0/in/email/otps#create`
- **OWN** `auth_app_api_v0_preferences_cookie` `GET` `/api/v0/preferences/cookie(.:format)` →
  `auth/app/api/v0/preferences/cookies#show`
- **OWN** `(unnamed)` `PATCH` `/api/v0/preferences/cookie(.:format)` →
  `auth/app/api/v0/preferences/cookies#update`
- **OWN** `auth_app_api_v0_preferences_theme` `GET` `/api/v0/preferences/theme(.:format)` →
  `auth/app/api/v0/preferences/themes#show`
- **OWN** `(unnamed)` `PATCH` `/api/v0/preferences/theme(.:format)` →
  `auth/app/api/v0/preferences/themes#update`
- **OWN** `new_auth_app_sign_up_email` `GET` `/sign/up/email/new(.:format)` →
  `auth/app/sign/up/emails#new`
- **OWN** `auth_app_sign_up_email` `POST` `/sign/up/email(.:format)` →
  `auth/app/sign/up/emails#create`
- **OWN** `new_auth_app_sign_up_telephone` `GET` `/sign/up/telephone/new(.:format)` →
  `auth/app/sign/up/telephones#new`
- **OWN** `auth_app_sign_up_telephone` `POST` `/sign/up/telephone(.:format)` →
  `auth/app/sign/up/telephones#create`
- **OWN** `auth_app_sign_up_guard_apple` `GET` `/sign/up/guard/apple(.:format)` →
  `auth/app/sign/up/guard/apples#show`
- **OWN** `auth_app_sign_up_guard_google` `GET` `/sign/up/guard/google(.:format)` →
  `auth/app/sign/up/guard/googles#show`
- **OWN** `auth_app_sign_up_guard_email` `GET` `/sign/up/guard/email(.:format)` →
  `auth/app/sign/up/guard/emails#show`
- **OWN** `auth_app_sign_up_guard_telephone` `GET` `/sign/up/guard/telephone(.:format)` →
  `auth/app/sign/up/guard/telephones#show`
- **OWN** `auth_app_sign_up_check_apple_confirmation` `GET`
  `/sign/up/check/apple/confirmation(.:format)` → `auth/app/sign/up/check/apple/confirmations#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/apple/confirmation(.:format)` →
  `auth/app/sign/up/check/apple/confirmations#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/apple/confirmation(.:format)` →
  `auth/app/sign/up/check/apple/confirmations#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/apple/confirmation(.:format)` →
  `auth/app/sign/up/check/apple/confirmations#destroy`
- **OWN** `auth_app_sign_up_check_apple_birthdate` `GET` `/sign/up/check/apple/birthdate(.:format)`
  → `auth/app/sign/up/check/apple/birthdates#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/apple/birthdate(.:format)` →
  `auth/app/sign/up/check/apple/birthdates#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/apple/birthdate(.:format)` →
  `auth/app/sign/up/check/apple/birthdates#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/apple/birthdate(.:format)` →
  `auth/app/sign/up/check/apple/birthdates#destroy`
- **OWN** `auth_app_sign_up_check_google_confirmation` `GET`
  `/sign/up/check/google/confirmation(.:format)` →
  `auth/app/sign/up/check/google/confirmations#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/google/confirmation(.:format)` →
  `auth/app/sign/up/check/google/confirmations#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/google/confirmation(.:format)` →
  `auth/app/sign/up/check/google/confirmations#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/google/confirmation(.:format)` →
  `auth/app/sign/up/check/google/confirmations#destroy`
- **OWN** `auth_app_sign_up_check_google_birthdate` `GET`
  `/sign/up/check/google/birthdate(.:format)` → `auth/app/sign/up/check/google/birthdates#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/google/birthdate(.:format)` →
  `auth/app/sign/up/check/google/birthdates#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/google/birthdate(.:format)` →
  `auth/app/sign/up/check/google/birthdates#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/google/birthdate(.:format)` →
  `auth/app/sign/up/check/google/birthdates#destroy`
- **OWN** `auth_app_sign_up_check_email_otp` `GET` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#destroy`
- **OWN** `(unnamed)` `POST` `/sign/up/check/email/otp(.:format)` →
  `auth/app/sign/up/check/email/otps#create`
- **OWN** `auth_app_sign_up_check_email_birthdate` `GET` `/sign/up/check/email/birthdate(.:format)`
  → `auth/app/sign/up/check/email/birthdates#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/email/birthdate(.:format)` →
  `auth/app/sign/up/check/email/birthdates#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/email/birthdate(.:format)` →
  `auth/app/sign/up/check/email/birthdates#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/email/birthdate(.:format)` →
  `auth/app/sign/up/check/email/birthdates#destroy`
- **OWN** `auth_app_sign_up_check_telephone_otp` `GET` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#destroy`
- **OWN** `(unnamed)` `POST` `/sign/up/check/telephone/otp(.:format)` →
  `auth/app/sign/up/check/telephone/otps#create`
- **OWN** `auth_app_sign_up_check_telephone_passkey` `GET`
  `/sign/up/check/telephone/passkey(.:format)` → `auth/app/sign/up/check/telephone/passkeys#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/telephone/passkey(.:format)` →
  `auth/app/sign/up/check/telephone/passkeys#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/telephone/passkey(.:format)` →
  `auth/app/sign/up/check/telephone/passkeys#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/telephone/passkey(.:format)` →
  `auth/app/sign/up/check/telephone/passkeys#destroy`
- **OWN** `(unnamed)` `POST` `/sign/up/check/telephone/passkey(.:format)` →
  `auth/app/sign/up/check/telephone/passkeys#create`
- **OWN** `reattempt_auth_app_sign_up_check_telephone_secret` `POST`
  `/sign/up/check/telephone/secret/reattempt(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#reattempt`
- **OWN** `auth_app_sign_up_check_telephone_secret` `GET`
  `/sign/up/check/telephone/secret(.:format)` → `auth/app/sign/up/check/telephone/secrets#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/telephone/secret(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/telephone/secret(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/telephone/secret(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#destroy`
- **OWN** `(unnamed)` `POST` `/sign/up/check/telephone/secret(.:format)` →
  `auth/app/sign/up/check/telephone/secrets#create`
- **OWN** `auth_app_sign_up_check_telephone_birthdate` `GET`
  `/sign/up/check/telephone/birthdate(.:format)` →
  `auth/app/sign/up/check/telephone/birthdates#show`
- **OWN** `(unnamed)` `PATCH` `/sign/up/check/telephone/birthdate(.:format)` →
  `auth/app/sign/up/check/telephone/birthdates#update`
- **OWN** `(unnamed)` `PUT` `/sign/up/check/telephone/birthdate(.:format)` →
  `auth/app/sign/up/check/telephone/birthdates#update`
- **OWN** `(unnamed)` `DELETE` `/sign/up/check/telephone/birthdate(.:format)` →
  `auth/app/sign/up/check/telephone/birthdates#destroy`
- **OWN** `new_auth_app_sign_in_email` `GET` `/sign/in/email/new(.:format)` →
  `auth/app/sign/in/emails#new`
- **OWN** `edit_auth_app_sign_in_email` `GET` `/sign/in/email/edit(.:format)` →
  `auth/app/sign/in/emails#edit`
- **OWN** `auth_app_sign_in_email` `PATCH` `/sign/in/email(.:format)` →
  `auth/app/sign/in/emails#update`
- **OWN** `(unnamed)` `PUT` `/sign/in/email(.:format)` → `auth/app/sign/in/emails#update`
- **OWN** `(unnamed)` `DELETE` `/sign/in/email(.:format)` → `auth/app/sign/in/emails#destroy`
- **OWN** `(unnamed)` `POST` `/sign/in/email(.:format)` → `auth/app/sign/in/emails#create`
- **OWN** `new_auth_app_sign_in_passkey` `GET` `/sign/in/passkey/new(.:format)` →
  `auth/app/sign/in/passkeys#new`
- **OWN** `new_auth_app_sign_in_secret` `GET` `/sign/in/secret/new(.:format)` →
  `auth/app/sign/in/secrets#new`
- **OWN** `auth_app_sign_in_secret` `POST` `/sign/in/secret(.:format)` →
  `auth/app/sign/in/secrets#create`
- **OWN** `auth_app_sign_in_passkey_options` `POST` `/sign/in/passkey/options(.:format)` →
  `auth/app/sign/in/passkey/options#create`
- **OWN** `auth_app_sign_in_passkey_verification` `POST` `/sign/in/passkey/verification(.:format)` →
  `auth/app/sign/in/passkey/verifications#create`
- **OWN** `auth_app_sign_in_check` `GET` `/sign/in/check(.:format)` → `auth/app/sign/in/checks#show`
- **OWN** `auth_app_sign_in_challenge` `GET` `/sign/in/challenge(.:format)` →
  `auth/app/sign/in/challenges#show`
- **OWN** `(unnamed)` `DELETE` `/sign/in/challenge(.:format)` →
  `auth/app/sign/in/challenges#destroy`
- **OWN** `new_auth_app_sign_in_challenge_passkey` `GET` `/sign/in/challenge/passkey/new(.:format)`
  → `auth/app/sign/in/challenge/passkeys#new`
- **OWN** `auth_app_sign_in_challenge_passkey` `POST` `/sign/in/challenge/passkey(.:format)` →
  `auth/app/sign/in/challenge/passkeys#create`
- **OWN** `auth_app_social_link_completion` `POST` `/social/link_completion(.:format)` →
  `auth/app/social/link_completions#create`
- **OWN** `auth_app_social_google_callback` `GET` `/social/google/callback(.:format)` →
  `auth/app/omniauth/omniauth_callbacks#omniauth`
- **OWN** `auth_app_social_apple_callback` `GET` `/social/apple/callback(.:format)` →
  `auth/app/omniauth/omniauth_callbacks#omniauth`
- **OWN** `auth_app_social_failure` `GET` `/social/failure(.:format)` →
  `auth/app/omniauth/omniauth_callbacks#failure`
- **OWN** `auth_app_social_google_session` `POST` `/social/google/session(.:format)` →
  `auth/app/social/sessions#create`
- **OWN** `auth_app_social_google_registration` `POST` `/social/google/registration(.:format)` →
  `auth/app/social/registrations#create`
- **OWN** `auth_app_social_apple_session` `POST` `/social/apple/session(.:format)` →
  `auth/app/social/sessions#create`
- **OWN** `auth_app_social_apple_registration` `POST` `/social/apple/registration(.:format)` →
  `auth/app/social/registrations#create`
- **OWN** `auth_app_verification` `GET` `/verification(.:format)` → `auth/app/verifications#show`
- **OWN** `auth_app_verification_cancellation` `POST` `/verification/cancellation(.:format)` →
  `auth/app/verification/cancellations#create`
- **OWN** `new_auth_app_verification_setup` `GET` `/verification/setup/new(.:format)` →
  `auth/app/verification/setups#new`
- **OWN** `auth_app_verification_handoff` `GET` `/verification/handoff(.:format)` →
  `auth/app/verification/handoffs#show`
- **OWN** `(unnamed)` `POST` `/verification/handoff(.:format)` →
  `auth/app/verification/handoffs#create`
- **OWN** `auth_app_verification_passkey_options` `POST` `/verification/passkey/options(.:format)` →
  `auth/app/verification/passkeys#options`
- **OWN** `new_auth_app_verification_passkey` `GET` `/verification/passkey/new(.:format)` →
  `auth/app/verification/passkeys#new`
- **OWN** `auth_app_verification_passkey` `POST` `/verification/passkey(.:format)` →
  `auth/app/verification/passkeys#create`
- **OWN** `new_auth_app_verification_totp` `GET` `/verification/totp/new(.:format)` →
  `auth/app/verification/totps#new`
- **OWN** `auth_app_verification_totp` `POST` `/verification/totp(.:format)` →
  `auth/app/verification/totps#create`
- **OWN** `auth_app_verification_registration_passkey_options` `POST`
  `/verification/registration/passkey/options(.:format)` →
  `auth/app/verification/registration/passkeys#options`
- **OWN** `new_auth_app_verification_registration_passkey` `GET`
  `/verification/registration/passkey/new(.:format)` →
  `auth/app/verification/registration/passkeys#new`
- **OWN** `auth_app_verification_registration_passkey` `POST`
  `/verification/registration/passkey(.:format)` →
  `auth/app/verification/registration/passkeys#create`
- **OWN** `auth_app_verification_registration_handoff` `GET`
  `/verification/registration/handoff(.:format)` →
  `auth/app/verification/registration/handoffs#show`
- **OWN** `(unnamed)` `POST` `/verification/registration/handoff(.:format)` →
  `auth/app/verification/registration/handoffs#create`
- **OWN** `auth_app_verification_email_redelivery` `POST`
  `/verification/emails/:email_id/redelivery(.:format)` →
  `auth/app/verification/redeliveries#create`
- **OWN** `auth_app_verification_emails` `POST` `/verification/emails(.:format)` →
  `auth/app/verification/emails#create`
- **OWN** `new_auth_app_verification_email` `GET` `/verification/emails/new(.:format)` →
  `auth/app/verification/emails#new`
- **OWN** `edit_auth_app_verification_email` `GET` `/verification/emails/:id/edit(.:format)` →
  `auth/app/verification/emails#edit`
- **OWN** `auth_app_verification_email` `PATCH` `/verification/emails/:id(.:format)` →
  `auth/app/verification/emails#update`
- **OWN** `(unnamed)` `PUT` `/verification/emails/:id(.:format)` →
  `auth/app/verification/emails#update`
- **OWN** `auth_app_settings` `GET` `/settings(.:format)` → `auth/app/settings#show`
- **OWN** `auth_app_settings_totps_enrollment` `DELETE` `/settings/totps/enrollment(.:format)` →
  `auth/app/settings/totps/enrollments#destroy`
- **OWN** `(unnamed)` `POST` `/settings/totps/enrollment(.:format)` →
  `auth/app/settings/totps/enrollments#create`
- **OWN** `auth_app_settings_totps_handoff` `GET` `/settings/totps/handoff(.:format)` →
  `auth/app/settings/totps/handoffs#show`
- **OWN** `(unnamed)` `POST` `/settings/totps/handoff(.:format)` →
  `auth/app/settings/totps/handoffs#create`
- **OWN** `auth_app_settings_totps` `POST` `/settings/totps(.:format)` →
  `auth/app/settings/totps#create`
- **OWN** `new_auth_app_settings_totp` `GET` `/settings/totps/new(.:format)` →
  `auth/app/settings/totps#new`
- **OWN** `edit_auth_app_settings_apple` `GET` `/settings/apple/edit(.:format)` →
  `auth/app/settings/apples#edit`
- **OWN** `auth_app_settings_apple` `GET` `/settings/apple(.:format)` →
  `auth/app/settings/apples#show`
- **OWN** `(unnamed)` `DELETE` `/settings/apple(.:format)` → `auth/app/settings/apples#destroy`
- **OWN** `(unnamed)` `POST` `/settings/apple(.:format)` → `auth/app/settings/apples#create`
- **OWN** `edit_auth_app_settings_google` `GET` `/settings/google/edit(.:format)` →
  `auth/app/settings/googles#edit`
- **OWN** `auth_app_settings_google` `GET` `/settings/google(.:format)` →
  `auth/app/settings/googles#show`
- **OWN** `(unnamed)` `DELETE` `/settings/google(.:format)` → `auth/app/settings/googles#destroy`
- **OWN** `(unnamed)` `POST` `/settings/google(.:format)` → `auth/app/settings/googles#create`

#### Auth org — auth-staff host constraint (`auth_staff.host`, `PUBLIC_AUTH_STAFF_URL`) (46 routes)

- **OWN** `auth_org_well_known_jwks` `GET` `/.well-known/jwks.json` →
  `auth/org/well_known/jwks#show`
- **OWN** `auth_org_revision` `GET` `/revision` → `auth/org/revisions#show`
- **OWN** `auth_org_health` `GET` `/health` → `auth/org/healths#show`
- **OWN** `auth_org_health_liveness` `GET` `/health/liveness` → `auth/org/health/livenesses#show`
- **OWN** `auth_org_health_readiness` `GET` `/health/readiness` → `auth/org/health/readinesses#show`
- **OWN** `auth_org_health_startup` `GET` `/health/startup` → `auth/org/health/startups#show`
- **OWN** `auth_org_api_v0_health` `GET` `/api/v0/health.json` → `auth/org/api/v0/healths#show`
- **OWN** `auth_org_api_v0_revision` `GET` `/api/v0/revision.json` →
  `auth/org/api/v0/revisions#show`
- **OWN** `auth_org_robots` `GET` `/robots.txt(.:format)` → `auth/org/robots#index`
- **OWN** `auth_org_sitemap` `GET` `/sitemap.xml(.:format)` → `auth/org/sitemaps#show`
- **OWN** `auth_org_csp_violation_report` `POST` `/csp-violation-report(.:format)` →
  `auth/org/csp_violation_reports#create`
- **OWN** `auth_org_ceremony_bindings` `GET` `/ceremony_bindings(.:format)` →
  `auth/org/ceremony_bindings#show`
- **OWN** `auth_org_sign_up` `GET` `/sign/up(.:format)` → `auth/org/sign/ups#show`
- **OWN** `auth_org_sign_in` `GET` `/sign/in(.:format)` → `auth/org/sign/ins#show`
- **OWN** `auth_org_sign_oidc_handoff` `GET` `/sign/oidc/handoff(.:format)` →
  `auth/org/sign/oidc_handoffs#show`
- **OWN** `auth_org_sign_cancellation` `POST` `/sign/cancellation(.:format)` →
  `auth/org/sign/cancellations#create`
- **OWN** `auth_org_sign_in_sentry` `GET` `/sign/in/sentry(.:format)` →
  `auth/org/sign/in/sentries#show`
- **OWN** `auth_org_sign_up_sentry` `GET` `/sign/up/sentry(.:format)` →
  `auth/org/sign/up/sentries#show`
- **OWN** `auth_org_api_v0_preferences_cookie` `GET` `/api/v0/preferences/cookie(.:format)` →
  `auth/org/api/v0/preferences/cookies#show`
- **OWN** `(unnamed)` `PATCH` `/api/v0/preferences/cookie(.:format)` →
  `auth/org/api/v0/preferences/cookies#update`
- **OWN** `auth_org_api_v0_preferences_theme` `GET` `/api/v0/preferences/theme(.:format)` →
  `auth/org/api/v0/preferences/themes#show`
- **OWN** `(unnamed)` `PATCH` `/api/v0/preferences/theme(.:format)` →
  `auth/org/api/v0/preferences/themes#update`
- **OWN** `new_auth_org_sign_in_passkey` `GET` `/sign/in/passkey/new(.:format)` →
  `auth/org/sign/in/passkeys#new`
- **OWN** `auth_org_sign_in_passkey_options` `POST` `/sign/in/passkey/options(.:format)` →
  `auth/org/sign/in/passkey/options#create`
- **OWN** `auth_org_sign_in_passkey_verification` `POST` `/sign/in/passkey/verification(.:format)` →
  `auth/org/sign/in/passkey/verifications#create`
- **OWN** `new_auth_org_sign_in_emergency_passkey` `GET` `/sign/in/emergency/passkey/new(.:format)`
  → `auth/org/sign/in/emergency/passkeys#new`
- **OWN** `auth_org_sign_in_emergency_passkey_options` `POST`
  `/sign/in/emergency/passkey/options(.:format)` →
  `auth/org/sign/in/emergency/passkey/options#create`
- **OWN** `auth_org_sign_in_emergency_passkey_verification` `POST`
  `/sign/in/emergency/passkey/verification(.:format)` →
  `auth/org/sign/in/emergency/passkey/verifications#create`
- **OWN** `auth_org_sign_in_check` `GET` `/sign/in/check(.:format)` → `auth/org/sign/in/checks#show`
- **OWN** `new_auth_org_social_entra_session` `GET` `/social/entra/session/new(.:format)` →
  `auth/org/social/sessions#new`
- **OWN** `auth_org_social_entra_session` `POST` `/social/entra/session(.:format)` →
  `auth/org/social/sessions#create`
- **OWN** `auth_org_social_entra_callback` `GET` `/social/entra/callback(.:format)` →
  `auth/org/omniauth/omniauth_callbacks#omniauth`
- **OWN** `auth_org_social_entra_failure` `GET` `/social/entra/failure(.:format)` →
  `auth/org/omniauth/omniauth_callbacks#failure`
- **OWN** `auth_org_verification` `GET` `/verification(.:format)` → `auth/org/verifications#show`
- **OWN** `auth_org_verification_cancellation` `POST` `/verification/cancellation(.:format)` →
  `auth/org/verification/cancellations#create`
- **OWN** `new_auth_org_verification_setup` `GET` `/verification/setup/new(.:format)` →
  `auth/org/verification/setups#new`
- **OWN** `auth_org_verification_handoff` `GET` `/verification/handoff(.:format)` →
  `auth/org/verification/handoffs#show`
- **OWN** `(unnamed)` `POST` `/verification/handoff(.:format)` →
  `auth/org/verification/handoffs#create`
- **OWN** `auth_org_verification_passkey_options` `POST` `/verification/passkey/options(.:format)` →
  `auth/org/verification/passkeys#options`
- **OWN** `new_auth_org_verification_passkey` `GET` `/verification/passkey/new(.:format)` →
  `auth/org/verification/passkeys#new`
- **OWN** `auth_org_verification_passkey` `POST` `/verification/passkey(.:format)` →
  `auth/org/verification/passkeys#create`
- **OWN** `auth_org_verification_registration_passkey_options` `POST`
  `/verification/registration/passkey/options(.:format)` →
  `auth/org/verification/registration/passkeys#options`
- **OWN** `new_auth_org_verification_registration_passkey` `GET`
  `/verification/registration/passkey/new(.:format)` →
  `auth/org/verification/registration/passkeys#new`
- **OWN** `auth_org_verification_registration_passkey` `POST`
  `/verification/registration/passkey(.:format)` →
  `auth/org/verification/registration/passkeys#create`
- **OWN** `auth_org_verification_registration_handoff` `GET`
  `/verification/registration/handoff(.:format)` →
  `auth/org/verification/registration/handoffs#show`
- **OWN** `(unnamed)` `POST` `/verification/registration/handoff(.:format)` →
  `auth/org/verification/registration/handoffs#create`

#### Visa app — visa-service host constraint (`visa_service.host`, `PUBLIC_VISA_SERVICE_URL`) (37 routes)

- **OWN** `visa_app_ceremony_binding_confirmation` `GET`
  `/ceremony_bindings/:binding_ref/confirmation(.:format)` →
  `visa/app/ceremony_binding_confirmations#show`
- **OWN** `visa_app_well_known_openid_configuration` `GET` `/.well-known/openid-configuration` →
  `visa/app/well_known/discoveries#show`
- **OWN** `visa_app_well_known_jwks` `GET` `/.well-known/jwks.json` →
  `visa/app/well_known/jwks#show`
- **OWN** `visa_app_health` `GET` `/health` → `visa/app/healths#show`
- **OWN** `visa_app_health_liveness` `GET` `/health/liveness` → `visa/app/health/livenesses#show`
- **OWN** `visa_app_health_readiness` `GET` `/health/readiness` → `visa/app/health/readinesses#show`
- **OWN** `visa_app_health_startup` `GET` `/health/startup` → `visa/app/health/startups#show`
- **OWN** `visa_app_api_v0_health` `GET` `/api/v0/health.json` → `visa/app/api/v0/healths#show`
- **OWN** `visa_app_api_v0_revision` `GET` `/api/v0/revision.json` →
  `visa/app/api/v0/revisions#show`
- **OWN** `visa_app_api_v0_sensitive_admissions` `POST` `/api/v0/sensitive_admissions(.:format)` →
  `visa/app/api/v0/sensitive_admissions#create`
- **OWN** `visa_app_api_v0_sensitive_admission_session` `PATCH`
  `/api/v0/sensitive_admission_session(.:format)` →
  `visa/app/api/v0/sensitive_admission_sessions#update`
- **OWN** `(unnamed)` `PUT` `/api/v0/sensitive_admission_session(.:format)` →
  `visa/app/api/v0/sensitive_admission_sessions#update`
- **OWN** `visa_app_api_v0_sensitive_admission_confirmation` `POST`
  `/api/v0/sensitive_admission_confirmation(.:format)` →
  `visa/app/api/v0/sensitive_admission_sessions#create`
- **OWN** `visa_app_revision` `GET` `/revision` → `visa/app/revisions#show`
- **OWN** `visa_app_robots` `GET` `/robots.txt(.:format)` → `visa/app/robots#index`
- **OWN** `visa_app_csp_violation_report` `POST` `/csp-violation-report(.:format)` →
  `visa/app/csp_violation_reports#create`
- **OWN** `visa_app_oauth_authorization` `GET` `/oauth/authorize(.:format)` →
  `visa/app/oauth/authorizations#show`
- **OWN** `(unnamed)` `POST` `/oauth/authorize(.:format)` → `visa/app/oauth/authorizations#create`
- **OWN** `visa_app_oauth_token` `POST` `/oauth/token(.:format)` → `visa/app/oauth/tokens#create`
- **OWN** `visa_app_oauth_userinfo` `GET` `/oauth/userinfo(.:format)` →
  `visa/app/oauth/userinfos#show`
- **OWN** `(unnamed)` `POST` `/oauth/userinfo(.:format)` → `visa/app/oauth/userinfos#create`
- **OWN** `visa_app_oauth_revocation` `POST` `/oauth/revoke(.:format)` →
  `visa/app/oauth/revocations#create`
- **OWN** `visa_app_oidc_logout` `GET` `/oidc/logout(.:format)` → `visa/app/oidc/logouts#show`
- **OWN** `(unnamed)` `POST` `/oidc/logout(.:format)` → `visa/app/oidc/logouts#create`
- **OWN** `visa_app_oidc_logout_confirmation` `POST` `/oidc/logout/confirmation(.:format)` →
  `visa/app/oidc/logouts/confirmations#create`
- **OWN** `visa_app_oidc_logout_completion` `GET` `/oidc/logout/completion(.:format)` →
  `visa/app/oidc/logouts/completions#show`
- **OWN** `visa_app_oidc_result` `GET` `/oidc/result(.:format)` → `visa/app/oidc/results#show`
- **OWN** `visa_app_oidc_cancellation` `GET` `/oidc/cancellation(.:format)` →
  `visa/app/oidc/cancellations#show`
- **OWN** `visa_app_oidc_switch` `GET` `/oidc/switch(.:format)` → `visa/app/oidc/switches#show`
- **OWN** `visa_app_sign_in_limitation` `GET` `/sign/in/limitation(.:format)` →
  `visa/app/sign/in/limitations#show`
- **OWN** `(unnamed)` `PATCH` `/sign/in/limitation(.:format)` →
  `visa/app/sign/in/limitations#update`
- **OWN** `(unnamed)` `PUT` `/sign/in/limitation(.:format)` → `visa/app/sign/in/limitations#update`
- **OWN** `(unnamed)` `DELETE` `/sign/in/limitation(.:format)` →
  `visa/app/sign/in/limitations#destroy`
- **OWN** `visa_app_sign_in_limitation_continue` `POST` `/sign/in/limitation(.:format)` →
  `visa/app/sign/in/limitations#update`
- **OWN** `visa_app_edge_v0_token_check` `GET` `/edge/v0/token/check(.:format)` →
  `visa/app/edge/v0/token/checks#show`
- **OWN** `visa_app_edge_v0_token_dbsc` `POST` `/edge/v0/token/dbsc(.:format)` →
  `visa/app/edge/v0/token/dbsc#create`
- **OWN** `visa_app_edge_v0_token_refresh` `POST` `/edge/v0/token/refresh(.:format)` →
  `visa/app/edge/v0/token/refreshes#create`

#### Visa org — visa-staff host constraint (`visa_staff.host`, `PUBLIC_VISA_STAFF_URL`) (36 routes)

- **OWN** `visa_org_ceremony_binding_confirmation` `GET`
  `/ceremony_bindings/:binding_ref/confirmation(.:format)` →
  `visa/org/ceremony_binding_confirmations#show`
- **OWN** `visa_org_well_known_openid_configuration` `GET` `/.well-known/openid-configuration` →
  `visa/org/well_known/discoveries#show`
- **OWN** `visa_org_well_known_jwks` `GET` `/.well-known/jwks.json` →
  `visa/org/well_known/jwks#show`
- **OWN** `visa_org_health` `GET` `/health` → `visa/org/healths#show`
- **OWN** `visa_org_health_liveness` `GET` `/health/liveness` → `visa/org/health/livenesses#show`
- **OWN** `visa_org_health_readiness` `GET` `/health/readiness` → `visa/org/health/readinesses#show`
- **OWN** `visa_org_health_startup` `GET` `/health/startup` → `visa/org/health/startups#show`
- **OWN** `visa_org_api_v0_health` `GET` `/api/v0/health.json` → `visa/org/api/v0/healths#show`
- **OWN** `visa_org_api_v0_revision` `GET` `/api/v0/revision.json` →
  `visa/org/api/v0/revisions#show`
- **OWN** `visa_org_api_v0_sensitive_admissions` `POST` `/api/v0/sensitive_admissions(.:format)` →
  `visa/org/api/v0/sensitive_admissions#create`
- **OWN** `visa_org_api_v0_sensitive_admission_session` `PATCH`
  `/api/v0/sensitive_admission_session(.:format)` →
  `visa/org/api/v0/sensitive_admission_sessions#update`
- **OWN** `(unnamed)` `PUT` `/api/v0/sensitive_admission_session(.:format)` →
  `visa/org/api/v0/sensitive_admission_sessions#update`
- **OWN** `visa_org_api_v0_sensitive_admission_confirmation` `POST`
  `/api/v0/sensitive_admission_confirmation(.:format)` →
  `visa/org/api/v0/sensitive_admission_sessions#create`
- **OWN** `visa_org_revision` `GET` `/revision` → `visa/org/revisions#show`
- **OWN** `visa_org_robots` `GET` `/robots.txt(.:format)` → `visa/org/robots#index`
- **OWN** `visa_org_csp_violation_report` `POST` `/csp-violation-report(.:format)` →
  `visa/org/csp_violation_reports#create`
- **OWN** `visa_org_oauth_authorization` `GET` `/oauth/authorize(.:format)` →
  `visa/org/oauth/authorizations#show`
- **OWN** `(unnamed)` `POST` `/oauth/authorize(.:format)` → `visa/org/oauth/authorizations#create`
- **OWN** `visa_org_oauth_token` `POST` `/oauth/token(.:format)` → `visa/org/oauth/tokens#create`
- **OWN** `visa_org_oauth_userinfo` `GET` `/oauth/userinfo(.:format)` →
  `visa/org/oauth/userinfos#show`
- **OWN** `(unnamed)` `POST` `/oauth/userinfo(.:format)` → `visa/org/oauth/userinfos#create`
- **OWN** `visa_org_oauth_revocation` `POST` `/oauth/revoke(.:format)` →
  `visa/org/oauth/revocations#create`
- **OWN** `visa_org_oidc_logout` `GET` `/oidc/logout(.:format)` → `visa/org/oidc/logouts#show`
- **OWN** `(unnamed)` `POST` `/oidc/logout(.:format)` → `visa/org/oidc/logouts#create`
- **OWN** `visa_org_oidc_logout_confirmation` `POST` `/oidc/logout/confirmation(.:format)` →
  `visa/org/oidc/logouts/confirmations#create`
- **OWN** `visa_org_oidc_logout_completion` `GET` `/oidc/logout/completion(.:format)` →
  `visa/org/oidc/logouts/completions#show`
- **OWN** `visa_org_oidc_result` `GET` `/oidc/result(.:format)` → `visa/org/oidc/results#show`
- **OWN** `visa_org_oidc_cancellation` `GET` `/oidc/cancellation(.:format)` →
  `visa/org/oidc/cancellations#show`
- **OWN** `visa_org_sign_in_limitation` `GET` `/sign/in/limitation(.:format)` →
  `visa/org/sign/in/limitations#show`
- **OWN** `(unnamed)` `PATCH` `/sign/in/limitation(.:format)` →
  `visa/org/sign/in/limitations#update`
- **OWN** `(unnamed)` `PUT` `/sign/in/limitation(.:format)` → `visa/org/sign/in/limitations#update`
- **OWN** `(unnamed)` `DELETE` `/sign/in/limitation(.:format)` →
  `visa/org/sign/in/limitations#destroy`
- **OWN** `visa_org_sign_in_limitation_continue` `POST` `/sign/in/limitation(.:format)` →
  `visa/org/sign/in/limitations#update`
- **OWN** `visa_org_edge_v0_token_check` `GET` `/edge/v0/token/check(.:format)` →
  `visa/org/edge/v0/token/checks#show`
- **OWN** `visa_org_edge_v0_token_dbsc` `POST` `/edge/v0/token/dbsc(.:format)` →
  `visa/org/edge/v0/token/dbsc#create`
- **OWN** `visa_org_edge_v0_token_refresh` `POST` `/edge/v0/token/refresh(.:format)` →
  `visa/org/edge/v0/token/refreshes#create`

#### Mission — dedicated host constraint (`PUBLIC_MISSION_URL`, `PRIVATE_MISSION_URL`) (25 routes)

- **OWN** `application_queue_pause` `DELETE`
  `/applications/:application_id/queues/:queue_id/pause(.:format)` →
  `mission_control/jobs/queues/pauses#destroy`
- **OWN** `(unnamed)` `POST` `/applications/:application_id/queues/:queue_id/pause(.:format)` →
  `mission_control/jobs/queues/pauses#create`
- **OWN** `application_queues` `GET` `/applications/:application_id/queues(.:format)` →
  `mission_control/jobs/queues#index`
- **OWN** `application_queue` `GET` `/applications/:application_id/queues/:id(.:format)` →
  `mission_control/jobs/queues#show`
- **OWN** `application_job_retry` `POST`
  `/applications/:application_id/jobs/:job_id/retry(.:format)` →
  `mission_control/jobs/retries#create`
- **OWN** `application_job_discard` `POST`
  `/applications/:application_id/jobs/:job_id/discard(.:format)` →
  `mission_control/jobs/discards#create`
- **OWN** `application_job_dispatch` `POST`
  `/applications/:application_id/jobs/:job_id/dispatch(.:format)` →
  `mission_control/jobs/dispatches#create`
- **OWN** `application_bulk_retries` `POST`
  `/applications/:application_id/jobs/bulk_retries(.:format)` →
  `mission_control/jobs/bulk_retries#create`
- **OWN** `application_bulk_discards` `POST`
  `/applications/:application_id/jobs/bulk_discards(.:format)` →
  `mission_control/jobs/bulk_discards#create`
- **OWN** `application_job` `GET` `/applications/:application_id/jobs/:id(.:format)` →
  `mission_control/jobs/jobs#show`
- **OWN** `application_jobs` `GET` `/applications/:application_id/:status/jobs(.:format)` →
  `mission_control/jobs/jobs#index`
- **OWN** `application_workers` `GET` `/applications/:application_id/workers(.:format)` →
  `mission_control/jobs/workers#index`
- **OWN** `application_worker` `GET` `/applications/:application_id/workers/:id(.:format)` →
  `mission_control/jobs/workers#show`
- **OWN** `application_recurring_tasks` `GET`
  `/applications/:application_id/recurring_tasks(.:format)` →
  `mission_control/jobs/recurring_tasks#index`
- **OWN** `application_recurring_task` `GET`
  `/applications/:application_id/recurring_tasks/:id(.:format)` →
  `mission_control/jobs/recurring_tasks#show`
- **OWN** `(unnamed)` `PATCH` `/applications/:application_id/recurring_tasks/:id(.:format)` →
  `mission_control/jobs/recurring_tasks#update`
- **OWN** `(unnamed)` `PUT` `/applications/:application_id/recurring_tasks/:id(.:format)` →
  `mission_control/jobs/recurring_tasks#update`
- **OWN** `application_batches` `GET` `/applications/:application_id/batches(.:format)` →
  `mission_control/jobs/batches#index`
- **OWN** `application_batch` `GET` `/applications/:application_id/batches/:id(.:format)` →
  `mission_control/jobs/batches#show`
- **OWN** `queues` `GET` `/queues(.:format)` → `mission_control/jobs/queues#index`
- **OWN** `queue` `GET` `/queues/:id(.:format)` → `mission_control/jobs/queues#show`
- **OWN** `job` `GET` `/jobs/:id(.:format)` → `mission_control/jobs/jobs#show`
- **OWN** `jobs` `GET` `/:status/jobs(.:format)` → `mission_control/jobs/jobs#index`
- **OWN** `root` `GET` `/` → `mission_control/jobs/queues#index`

#### Flipper — dedicated host constraint (`PUBLIC_FLIPPER_URL`, `PRIVATE_FLIPPER_URL`) (1 route)

- No route entries in this `bin/rails routes` invocation.

#### Blazer — dedicated host constraint (`PUBLIC_BLAZER_URL`, `PRIVATE_BLAZER_URL`) (32 routes)

- **OWN** `run_queries` `POST` `/queries/run(.:format)` → `blazer/queries#run`
- **OWN** `cancel_queries` `POST` `/queries/cancel(.:format)` → `blazer/queries#cancel`
- **OWN** `refresh_query` `POST` `/queries/:id/refresh(.:format)` → `blazer/queries#refresh`
- **OWN** `tables_queries` `GET` `/queries/tables(.:format)` → `blazer/queries#tables`
- **OWN** `schema_queries` `GET` `/queries/schema(.:format)` → `blazer/queries#schema`
- **OWN** `docs_queries` `GET` `/queries/docs(.:format)` → `blazer/queries#docs`
- **OWN** `queries` `GET` `/queries(.:format)` → `blazer/queries#index`
- **OWN** `(unnamed)` `POST` `/queries(.:format)` → `blazer/queries#create`
- **OWN** `new_query` `GET` `/queries/new(.:format)` → `blazer/queries#new`
- **OWN** `edit_query` `GET` `/queries/:id/edit(.:format)` → `blazer/queries#edit`
- **OWN** `query` `GET` `/queries/:id(.:format)` → `blazer/queries#show`
- **OWN** `(unnamed)` `PATCH` `/queries/:id(.:format)` → `blazer/queries#update`
- **OWN** `(unnamed)` `PUT` `/queries/:id(.:format)` → `blazer/queries#update`
- **OWN** `(unnamed)` `DELETE` `/queries/:id(.:format)` → `blazer/queries#destroy`
- **OWN** `run_check` `GET` `/checks/:id/run(.:format)` → `blazer/checks#run`
- **OWN** `checks` `GET` `/checks(.:format)` → `blazer/checks#index`
- **OWN** `(unnamed)` `POST` `/checks(.:format)` → `blazer/checks#create`
- **OWN** `new_check` `GET` `/checks/new(.:format)` → `blazer/checks#new`
- **OWN** `edit_check` `GET` `/checks/:id/edit(.:format)` → `blazer/checks#edit`
- **OWN** `check` `PATCH` `/checks/:id(.:format)` → `blazer/checks#update`
- **OWN** `(unnamed)` `PUT` `/checks/:id(.:format)` → `blazer/checks#update`
- **OWN** `(unnamed)` `DELETE` `/checks/:id(.:format)` → `blazer/checks#destroy`
- **OWN** `refresh_dashboard` `POST` `/dashboards/:id/refresh(.:format)` →
  `blazer/dashboards#refresh`
- **OWN** `dashboards` `POST` `/dashboards(.:format)` → `blazer/dashboards#create`
- **OWN** `new_dashboard` `GET` `/dashboards/new(.:format)` → `blazer/dashboards#new`
- **OWN** `edit_dashboard` `GET` `/dashboards/:id/edit(.:format)` → `blazer/dashboards#edit`
- **OWN** `dashboard` `GET` `/dashboards/:id(.:format)` → `blazer/dashboards#show`
- **OWN** `(unnamed)` `PATCH` `/dashboards/:id(.:format)` → `blazer/dashboards#update`
- **OWN** `(unnamed)` `PUT` `/dashboards/:id(.:format)` → `blazer/dashboards#update`
- **OWN** `(unnamed)` `DELETE` `/dashboards/:id(.:format)` → `blazer/dashboards#destroy`
- **OWN** `root` `GET` `/` → `blazer/queries#home`

#### PgHero — dedicated host constraint (`PUBLIC_PGHERO_URL`, `PRIVATE_PGHERO_URL`) (26 routes)

- **OWN** `space` `GET` `(/:database)/space(.:format)` → `pg_hero/home#space`
- **OWN** `relation_space` `GET` `(/:database)/space/:relation(.:format)` →
  `pg_hero/home#relation_space`
- **OWN** `index_bloat` `GET` `(/:database)/index_bloat(.:format)` → `pg_hero/home#index_bloat`
- **OWN** `live_queries` `GET` `(/:database)/live_queries(.:format)` → `pg_hero/home#live_queries`
- **OWN** `queries` `GET` `(/:database)/queries(.:format)` → `pg_hero/home#queries`
- **OWN** `show_query` `GET` `(/:database)/queries/:query_hash(.:format)` →
  `pg_hero/home#show_query`
- **OWN** `system` `GET` `(/:database)/system(.:format)` → `pg_hero/home#system`
- **OWN** `cpu_usage` `GET` `(/:database)/cpu_usage(.:format)` → `pg_hero/home#cpu_usage`
- **OWN** `connection_stats` `GET` `(/:database)/connection_stats(.:format)` →
  `pg_hero/home#connection_stats`
- **OWN** `replication_lag_stats` `GET` `(/:database)/replication_lag_stats(.:format)` →
  `pg_hero/home#replication_lag_stats`
- **OWN** `load_stats` `GET` `(/:database)/load_stats(.:format)` → `pg_hero/home#load_stats`
- **OWN** `free_space_stats` `GET` `(/:database)/free_space_stats(.:format)` →
  `pg_hero/home#free_space_stats`
- **OWN** `explain` `GET` `(/:database)/explain(.:format)` → `pg_hero/home#explain`
- **OWN** `tune` `GET` `(/:database)/tune(.:format)` → `pg_hero/home#tune`
- **OWN** `connections` `GET` `(/:database)/connections(.:format)` → `pg_hero/home#connections`
- **OWN** `maintenance` `GET` `(/:database)/maintenance(.:format)` → `pg_hero/home#maintenance`
- **OWN** `kill` `POST` `(/:database)/kill(.:format)` → `pg_hero/home#kill`
- **OWN** `kill_long_running_queries` `POST` `(/:database)/kill_long_running_queries(.:format)` →
  `pg_hero/home#kill_long_running_queries`
- **OWN** `kill_all` `POST` `(/:database)/kill_all(.:format)` → `pg_hero/home#kill_all`
- **OWN** `enable_query_stats` `POST` `(/:database)/enable_query_stats(.:format)` →
  `pg_hero/home#enable_query_stats`
- **OWN** `(unnamed)` `POST` `(/:database)/explain(.:format)` → `pg_hero/home#explain`
- **OWN** `reset_query_stats` `POST` `(/:database)/reset_query_stats(.:format)` →
  `pg_hero/home#reset_query_stats`
- **OWN** `system_stats` `GET` `(/:database)/system_stats(.:format)` → `(no controller action)`
- **OWN** `query_stats` `GET` `(/:database)/query_stats(.:format)` → `(no controller action)`
- **OWN** `root` `GET` `/(:database)(.:format)` → `pg_hero/home#index`

#### Coverband — dedicated host constraint (`PUBLIC_COVERBAND_URL`, `PRIVATE_COVERBAND_URL`) (0 routes)

- No route entries in this `bin/rails routes` invocation.

#### Swagger — dedicated host constraint (`PUBLIC_SWAGGER_URL`, `PRIVATE_SWAGGER_URL`) (2 routes)

- No route entries in this `bin/rails routes` invocation.

#### No host constraint — Rails framework routes (FOREIGN/RETIRED) (0 routes)

- No route entries in this `bin/rails routes` invocation.

#### No host constraint — unknown-host fallback (OWN) (1 routes)

- **OWN** `(unnamed)` `GET` `/` → `unknown_hosts#show`

## Controller namespace inventory

Namespaces are directories containing controller files (shared `concerns` are listed separately).
The task-start inventory is from the full controller tree at repository HEAD. `auth/app`,
`auth/org`, `visa/app`, and `visa/org` are OWN; all other task-start namespaces are FOREIGN/RETIRED.
The top-level namespace is shared infrastructure and contained only `ApplicationController` and
`UnknownHostsController`.

### Task-start namespaces

| Namespace                                   | Controller files | Classification  |
| ------------------------------------------- | ---------------: | --------------- |
| `(top-level)`                               |                2 | OWN             |
| `auth/app`                                  |               13 | OWN             |
| `auth/app/api/v0`                           |                2 | OWN             |
| `auth/app/api/v0/preferences`               |                2 | OWN             |
| `auth/app/apple`                            |                1 | OWN             |
| `auth/app/health`                           |                3 | OWN             |
| `auth/app/omniauth`                         |                1 | OWN             |
| `auth/app/settings`                         |                4 | OWN             |
| `auth/app/settings/totps`                   |                2 | OWN             |
| `auth/app/sign`                             |                6 | OWN             |
| `auth/app/sign/in`                          |                6 | OWN             |
| `auth/app/sign/in/challenge`                |                1 | OWN             |
| `auth/app/sign/in/passkey`                  |                2 | OWN             |
| `auth/app/sign/up`                          |                3 | OWN             |
| `auth/app/sign/up/check/apple`              |                2 | OWN             |
| `auth/app/sign/up/check/email`              |                2 | OWN             |
| `auth/app/sign/up/check/google`             |                2 | OWN             |
| `auth/app/sign/up/check/telephone`          |                4 | OWN             |
| `auth/app/sign/up/guard`                    |                5 | OWN             |
| `auth/app/social`                           |                3 | OWN             |
| `auth/app/verification`                     |                7 | OWN             |
| `auth/app/verification/registration`        |                2 | OWN             |
| `auth/app/web/v0/in/email`                  |                1 | OWN             |
| `auth/app/well_known`                       |                1 | OWN             |
| `auth/org`                                  |               13 | OWN             |
| `auth/org/api/v0`                           |                2 | OWN             |
| `auth/org/api/v0/preferences`               |                2 | OWN             |
| `auth/org/health`                           |                3 | OWN             |
| `auth/org/omniauth`                         |                1 | OWN             |
| `auth/org/sign`                             |                5 | OWN             |
| `auth/org/sign/in`                          |                3 | OWN             |
| `auth/org/sign/in/emergency`                |                1 | OWN             |
| `auth/org/sign/in/emergency/passkey`        |                2 | OWN             |
| `auth/org/sign/in/passkey`                  |                2 | OWN             |
| `auth/org/sign/up`                          |                2 | OWN             |
| `auth/org/social`                           |                1 | OWN             |
| `auth/org/verification`                     |                4 | OWN             |
| `auth/org/verification/registration`        |                2 | OWN             |
| `auth/org/well_known`                       |                1 | OWN             |
| `base/app`                                  |               32 | FOREIGN/RETIRED |
| `base/app/api/v0`                           |                2 | FOREIGN/RETIRED |
| `base/app/api/v0/avatar`                    |                8 | FOREIGN/RETIRED |
| `base/app/api/v0/identity`                  |                2 | FOREIGN/RETIRED |
| `base/app/api/v0/membership`                |                1 | FOREIGN/RETIRED |
| `base/app/api/v0/preferences`               |                3 | FOREIGN/RETIRED |
| `base/app/avatars`                          |                3 | FOREIGN/RETIRED |
| `base/app/health`                           |                3 | FOREIGN/RETIRED |
| `base/app/identity`                         |               13 | FOREIGN/RETIRED |
| `base/app/identity/emails`                  |                2 | FOREIGN/RETIRED |
| `base/app/identity/mfa`                     |                2 | FOREIGN/RETIRED |
| `base/app/identity/privacy`                 |                1 | FOREIGN/RETIRED |
| `base/app/identity/privacy/erasure`         |                1 | FOREIGN/RETIRED |
| `base/app/identity/recovery`                |                3 | FOREIGN/RETIRED |
| `base/app/identity/revocations`             |                1 | FOREIGN/RETIRED |
| `base/app/identity/telephones`              |                1 | FOREIGN/RETIRED |
| `base/app/identity/withdrawal`              |                1 | FOREIGN/RETIRED |
| `base/app/oidc`                             |                2 | FOREIGN/RETIRED |
| `base/app/organizations`                    |                1 | FOREIGN/RETIRED |
| `base/app/preference`                       |               15 | FOREIGN/RETIRED |
| `base/app/sign`                             |                2 | FOREIGN/RETIRED |
| `base/app/social/authentication`            |                1 | FOREIGN/RETIRED |
| `base/app/verification`                     |                3 | FOREIGN/RETIRED |
| `base/app/verification/oidc`                |                1 | FOREIGN/RETIRED |
| `base/app/well_known`                       |                1 | FOREIGN/RETIRED |
| `base/com`                                  |               10 | FOREIGN/RETIRED |
| `base/com/api/v0`                           |                2 | FOREIGN/RETIRED |
| `base/com/api/v0/preferences`               |                3 | FOREIGN/RETIRED |
| `base/com/health`                           |                3 | FOREIGN/RETIRED |
| `base/com/preference`                       |               14 | FOREIGN/RETIRED |
| `base/dev`                                  |                6 | FOREIGN/RETIRED |
| `base/dev/api/v0`                           |                2 | FOREIGN/RETIRED |
| `base/dev/health`                           |                3 | FOREIGN/RETIRED |
| `base/net`                                  |                6 | FOREIGN/RETIRED |
| `base/net/api/v0`                           |                2 | FOREIGN/RETIRED |
| `base/net/health`                           |                3 | FOREIGN/RETIRED |
| `base/org`                                  |               32 | FOREIGN/RETIRED |
| `base/org/api/v0`                           |                3 | FOREIGN/RETIRED |
| `base/org/api/v0/avatar`                    |                5 | FOREIGN/RETIRED |
| `base/org/api/v0/iam`                       |                1 | FOREIGN/RETIRED |
| `base/org/api/v0/identity`                  |                2 | FOREIGN/RETIRED |
| `base/org/api/v0/membership`                |                1 | FOREIGN/RETIRED |
| `base/org/api/v0/preferences`               |                3 | FOREIGN/RETIRED |
| `base/org/api/v0/publishing`                |                3 | FOREIGN/RETIRED |
| `base/org/api/v0/support`                   |                3 | FOREIGN/RETIRED |
| `base/org/api/v0/support/enforcement_cases` |                3 | FOREIGN/RETIRED |
| `base/org/health`                           |                3 | FOREIGN/RETIRED |
| `base/org/iam`                              |                1 | FOREIGN/RETIRED |
| `base/org/iam/grants`                       |                1 | FOREIGN/RETIRED |
| `base/org/identity`                         |               12 | FOREIGN/RETIRED |
| `base/org/identity/emails`                  |                1 | FOREIGN/RETIRED |
| `base/org/identity/mfa`                     |                1 | FOREIGN/RETIRED |
| `base/org/identity/revocations`             |                1 | FOREIGN/RETIRED |
| `base/org/identity/telephones`              |                1 | FOREIGN/RETIRED |
| `base/org/oidc`                             |                2 | FOREIGN/RETIRED |
| `base/org/organizations`                    |                1 | FOREIGN/RETIRED |
| `base/org/preference`                       |               15 | FOREIGN/RETIRED |
| `base/org/sign`                             |                2 | FOREIGN/RETIRED |
| `base/org/support`                          |                2 | FOREIGN/RETIRED |
| `base/org/support/clients`                  |                1 | FOREIGN/RETIRED |
| `base/org/support/enforcement_cases`        |                3 | FOREIGN/RETIRED |
| `base/org/verification`                     |                3 | FOREIGN/RETIRED |
| `base/org/verification/oidc`                |                1 | FOREIGN/RETIRED |
| `base/org/well_known`                       |                1 | FOREIGN/RETIRED |
| `core/app`                                  |                6 | FOREIGN/RETIRED |
| `core/app/api/v0`                           |                4 | FOREIGN/RETIRED |
| `core/app/api/v0/preferences`               |                2 | FOREIGN/RETIRED |
| `core/app/api/v0/token`                     |                1 | FOREIGN/RETIRED |
| `core/app/health`                           |                3 | FOREIGN/RETIRED |
| `core/app/oidc`                             |                2 | FOREIGN/RETIRED |
| `core/app/sign`                             |                3 | FOREIGN/RETIRED |
| `core/app/well_known`                       |                1 | FOREIGN/RETIRED |
| `core/dev`                                  |                5 | FOREIGN/RETIRED |
| `core/dev/api/v0`                           |                2 | FOREIGN/RETIRED |
| `core/dev/health`                           |                3 | FOREIGN/RETIRED |
| `core/net`                                  |                5 | FOREIGN/RETIRED |
| `core/net/api/v0`                           |                2 | FOREIGN/RETIRED |
| `core/net/health`                           |                3 | FOREIGN/RETIRED |
| `core/org`                                  |                6 | FOREIGN/RETIRED |
| `core/org/api/v0`                           |                4 | FOREIGN/RETIRED |
| `core/org/api/v0/preferences`               |                2 | FOREIGN/RETIRED |
| `core/org/api/v0/token`                     |                1 | FOREIGN/RETIRED |
| `core/org/health`                           |                3 | FOREIGN/RETIRED |
| `core/org/oidc`                             |                2 | FOREIGN/RETIRED |
| `core/org/sign`                             |                3 | FOREIGN/RETIRED |
| `core/org/well_known`                       |                1 | FOREIGN/RETIRED |
| `docs/app`                                  |                5 | FOREIGN/RETIRED |
| `docs/app/api/v0`                           |                3 | FOREIGN/RETIRED |
| `docs/app/health`                           |                3 | FOREIGN/RETIRED |
| `docs/com`                                  |                5 | FOREIGN/RETIRED |
| `docs/com/api/v0`                           |                3 | FOREIGN/RETIRED |
| `docs/com/health`                           |                3 | FOREIGN/RETIRED |
| `docs/org`                                  |                5 | FOREIGN/RETIRED |
| `docs/org/api/v0`                           |                3 | FOREIGN/RETIRED |
| `docs/org/health`                           |                3 | FOREIGN/RETIRED |
| `edit/org`                                  |                7 | FOREIGN/RETIRED |
| `edit/org/api/v0`                           |                2 | FOREIGN/RETIRED |
| `edit/org/health`                           |                3 | FOREIGN/RETIRED |
| `edit/org/oidc`                             |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/docs/app`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/docs/app/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/docs/com`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/docs/com/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/docs/org`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/docs/org/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/help/app`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/help/app/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/help/com`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/help/com/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/help/org`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/help/org/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/info/app`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/info/app/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/info/com`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/info/com/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/info/org`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/info/org/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/news/app`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/news/app/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/news/com`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/news/com/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/publishing/news/org`              |                1 | FOREIGN/RETIRED |
| `edit/org/publishing/news/org/entries`      |                2 | FOREIGN/RETIRED |
| `edit/org/sign`                             |                3 | FOREIGN/RETIRED |
| `guid/net`                                  |                5 | FOREIGN/RETIRED |
| `guid/net/api/v0`                           |                3 | FOREIGN/RETIRED |
| `guid/net/health`                           |                3 | FOREIGN/RETIRED |
| `help/app`                                  |                5 | FOREIGN/RETIRED |
| `help/app/api/v0`                           |                3 | FOREIGN/RETIRED |
| `help/app/health`                           |                3 | FOREIGN/RETIRED |
| `help/com`                                  |                5 | FOREIGN/RETIRED |
| `help/com/api/v0`                           |                3 | FOREIGN/RETIRED |
| `help/com/health`                           |                3 | FOREIGN/RETIRED |
| `help/org`                                  |                5 | FOREIGN/RETIRED |
| `help/org/api/v0`                           |                3 | FOREIGN/RETIRED |
| `help/org/health`                           |                3 | FOREIGN/RETIRED |
| `info/app`                                  |                5 | FOREIGN/RETIRED |
| `info/app/api/v0`                           |                3 | FOREIGN/RETIRED |
| `info/app/health`                           |                3 | FOREIGN/RETIRED |
| `info/com`                                  |                5 | FOREIGN/RETIRED |
| `info/com/api/v0`                           |                3 | FOREIGN/RETIRED |
| `info/com/health`                           |                3 | FOREIGN/RETIRED |
| `info/org`                                  |                5 | FOREIGN/RETIRED |
| `info/org/api/v0`                           |                3 | FOREIGN/RETIRED |
| `info/org/health`                           |                3 | FOREIGN/RETIRED |
| `news/app`                                  |                5 | FOREIGN/RETIRED |
| `news/app/api/v0`                           |                3 | FOREIGN/RETIRED |
| `news/app/health`                           |                3 | FOREIGN/RETIRED |
| `news/com`                                  |                5 | FOREIGN/RETIRED |
| `news/com/api/v0`                           |                3 | FOREIGN/RETIRED |
| `news/com/health`                           |                3 | FOREIGN/RETIRED |
| `news/org`                                  |                5 | FOREIGN/RETIRED |
| `news/org/api/v0`                           |                3 | FOREIGN/RETIRED |
| `news/org/health`                           |                3 | FOREIGN/RETIRED |
| `palm/app`                                  |                9 | FOREIGN/RETIRED |
| `palm/app/api/v0`                           |                2 | FOREIGN/RETIRED |
| `palm/app/health`                           |                3 | FOREIGN/RETIRED |
| `palm/app/oidc`                             |                2 | FOREIGN/RETIRED |
| `palm/app/sign`                             |                3 | FOREIGN/RETIRED |
| `palm/app/sign/out`                         |                1 | FOREIGN/RETIRED |
| `palm/app/well_known`                       |                1 | FOREIGN/RETIRED |
| `tech/org`                                  |                7 | FOREIGN/RETIRED |
| `tech/org/api/v0`                           |                2 | FOREIGN/RETIRED |
| `tech/org/health`                           |                3 | FOREIGN/RETIRED |
| `tech/org/oidc`                             |                2 | FOREIGN/RETIRED |
| `tech/org/sign`                             |                3 | FOREIGN/RETIRED |
| `tech/org/sign/out`                         |                1 | FOREIGN/RETIRED |
| `visa/app`                                  |                8 | OWN             |
| `visa/app/api/v0`                           |                4 | OWN             |
| `visa/app/edge/v0/token`                    |                3 | OWN             |
| `visa/app/health`                           |                3 | OWN             |
| `visa/app/oauth`                            |                4 | OWN             |
| `visa/app/oidc`                             |                4 | OWN             |
| `visa/app/oidc/logouts`                     |                2 | OWN             |
| `visa/app/sign/in`                          |                1 | OWN             |
| `visa/app/well_known`                       |                2 | OWN             |
| `visa/org`                                  |                8 | OWN             |
| `visa/org/api/v0`                           |                4 | OWN             |
| `visa/org/edge/v0/token`                    |                3 | OWN             |
| `visa/org/health`                           |                3 | OWN             |
| `visa/org/oauth`                            |                4 | OWN             |
| `visa/org/oidc`                             |                3 | OWN             |
| `visa/org/oidc/logouts`                     |                2 | OWN             |
| `visa/org/sign/in`                          |                1 | OWN             |
| `visa/org/well_known`                       |                2 | OWN             |
| `warp/app`                                  |               11 | FOREIGN/RETIRED |
| `warp/app/api/v0`                           |                2 | FOREIGN/RETIRED |
| `warp/app/api/v0/preferences`               |                2 | FOREIGN/RETIRED |
| `warp/app/health`                           |                3 | FOREIGN/RETIRED |
| `warp/app/oidc`                             |                2 | FOREIGN/RETIRED |
| `warp/app/sign`                             |                3 | FOREIGN/RETIRED |
| `warp/app/well_known`                       |                1 | FOREIGN/RETIRED |
| `warp/com`                                  |                8 | FOREIGN/RETIRED |
| `warp/com/api/v0`                           |                2 | FOREIGN/RETIRED |
| `warp/com/health`                           |                3 | FOREIGN/RETIRED |
| `warp/org`                                  |               11 | FOREIGN/RETIRED |
| `warp/org/api/v0`                           |                2 | FOREIGN/RETIRED |
| `warp/org/api/v0/preferences`               |                2 | FOREIGN/RETIRED |
| `warp/org/health`                           |                3 | FOREIGN/RETIRED |
| `warp/org/oidc`                             |                2 | FOREIGN/RETIRED |
| `warp/org/sign`                             |                3 | FOREIGN/RETIRED |
| `warp/org/well_known`                       |                1 | FOREIGN/RETIRED |

### Retained namespaces

| Namespace                            | Controller files | Classification |
| ------------------------------------ | ---------------: | -------------- |
| `(top-level)`                        |                2 | OWN            |
| `auth/app`                           |               11 | OWN            |
| `auth/app/api/v0`                    |                2 | OWN            |
| `auth/app/api/v0/preferences`        |                2 | OWN            |
| `auth/app/apple`                     |                1 | OWN            |
| `auth/app/health`                    |                3 | OWN            |
| `auth/app/omniauth`                  |                1 | OWN            |
| `auth/app/settings`                  |                3 | OWN            |
| `auth/app/settings/totps`            |                2 | OWN            |
| `auth/app/sign`                      |                5 | OWN            |
| `auth/app/sign/in`                   |                6 | OWN            |
| `auth/app/sign/in/challenge`         |                1 | OWN            |
| `auth/app/sign/in/passkey`           |                2 | OWN            |
| `auth/app/sign/up`                   |                3 | OWN            |
| `auth/app/sign/up/check/apple`       |                2 | OWN            |
| `auth/app/sign/up/check/email`       |                2 | OWN            |
| `auth/app/sign/up/check/google`      |                2 | OWN            |
| `auth/app/sign/up/check/telephone`   |                4 | OWN            |
| `auth/app/sign/up/guard`             |                5 | OWN            |
| `auth/app/social`                    |                3 | OWN            |
| `auth/app/verification`              |                7 | OWN            |
| `auth/app/verification/registration` |                2 | OWN            |
| `auth/app/web/v0/in/email`           |                1 | OWN            |
| `auth/app/well_known`                |                1 | OWN            |
| `auth/org`                           |               11 | OWN            |
| `auth/org/api/v0`                    |                2 | OWN            |
| `auth/org/api/v0/preferences`        |                2 | OWN            |
| `auth/org/health`                    |                3 | OWN            |
| `auth/org/omniauth`                  |                1 | OWN            |
| `auth/org/sign`                      |                4 | OWN            |
| `auth/org/sign/in`                   |                3 | OWN            |
| `auth/org/sign/in/emergency`         |                1 | OWN            |
| `auth/org/sign/in/emergency/passkey` |                2 | OWN            |
| `auth/org/sign/in/passkey`           |                2 | OWN            |
| `auth/org/sign/up`                   |                2 | OWN            |
| `auth/org/social`                    |                1 | OWN            |
| `auth/org/verification`              |                4 | OWN            |
| `auth/org/verification/registration` |                2 | OWN            |
| `auth/org/well_known`                |                1 | OWN            |
| `visa/app`                           |                8 | OWN            |
| `visa/app/api/v0`                    |                4 | OWN            |
| `visa/app/edge/v0/token`             |                3 | OWN            |
| `visa/app/health`                    |                3 | OWN            |
| `visa/app/oauth`                     |                4 | OWN            |
| `visa/app/oidc`                      |                4 | OWN            |
| `visa/app/oidc/logouts`              |                2 | OWN            |
| `visa/app/sign/in`                   |                1 | OWN            |
| `visa/app/well_known`                |                2 | OWN            |
| `visa/org`                           |                8 | OWN            |
| `visa/org/api/v0`                    |                4 | OWN            |
| `visa/org/edge/v0/token`             |                3 | OWN            |
| `visa/org/health`                    |                3 | OWN            |
| `visa/org/oauth`                     |                4 | OWN            |
| `visa/org/oidc`                      |                3 | OWN            |
| `visa/org/oidc/logouts`              |                2 | OWN            |
| `visa/org/sign/in`                   |                1 | OWN            |
| `visa/org/well_known`                |                2 | OWN            |

- Task-start namespaces with direct controller files: 241.
- Retained namespaces with direct controller files: 57.
- Shared retained controller concern files: 149.
- The shared top-level `UnknownHostsController` remains as the unregistered-host JSON 404.

## 2. Deletions and environment cleanup

- Tracked files deleted: 2418.
- `app/controllers/**`: 714 deleted files.
- `config/routes/**`: 12 deleted route files; the remaining route files and root routing file were
  reduced to owned surfaces.
- `test/**`: 813 deleted files.
- `app/models/**`: 1 file deleted; it was a model concern, not a model class.
- Migration/schema files deleted: 0.
- Database drops: none.

### Deleted tracked files by top-level directory

| Directory | Deleted files |
| --------- | ------------: |
| `app`     |          1194 |
| `config`  |            14 |
| `docs`    |             9 |
| `e2e`     |             4 |
| `gait`    |            60 |
| `lib`     |             6 |
| `openapi` |            11 |
| `src`     |           307 |
| `test`    |           813 |

### Selected deletion totals

| Path                | Deleted files |
| ------------------- | ------------: |
| `app/adapters/`     |            24 |
| `app/controllers/`  |           714 |
| `app/helpers/`      |             2 |
| `app/jobs/`         |             2 |
| `app/models/`       |             1 |
| `app/operations/`   |            47 |
| `app/policies/`     |           188 |
| `app/services/`     |            35 |
| `app/values/`       |            20 |
| `app/views/`        |           122 |
| `config/routes/`    |            12 |
| `test/controllers/` |           196 |
| `test/integration/` |           156 |
| `test/models/`      |           241 |
| `test/operations/`  |            38 |
| `test/policies/`    |            13 |
| `test/services/`    |            42 |
| `src/`              |           307 |
| `gait/`             |            60 |

Other deletions removed foreign frontend assets/pages, mailers, adapters, forms, operations,
policies, services, values, OpenAPI documents, obsolete initializers, and tests. Current
UI/design/navigation documentation was narrowed to retained surfaces; obsolete Contact examples and
the retired Pundit guide were deleted; pre-reset content and model inventories were reduced to
explicit historical notices. The architecture baseline and TODO list were regenerated after cleanup.

Locale cleanup removed eight translation sections from both `config/locales/en.yml` and
`config/locales/ja.yml`: billing, Jump redirector, landing, RP logout, RP interruption, preference
banner, preferences title, and retired shared navigation labels. Static translation-key searches
found no remaining callers in `app/`, `config/`, or `test/`. Auth/Visa translations remain,
including the shared skip-to-content label and recovery-identity validation key with current
callers. The full-suite run exposed a live Auth translation for
`activerecord.attributes.client_totp_ceremony_transaction.operation`; it was restored in both
locales from the current email ceremony transaction translation. The retained TOTP settings flow now
links back to the local verification setup route, and its contract accepts `registration`, the
operation used by the existing issuer and finalizer.

The cleanup had also removed five credentials still used by owned behavior: `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `OMNI_AUTH_GOOGLE_ORG_CLIENT_ID`, `OMNI_AUTH_GOOGLE_ORG_CLIENT_SECRET`, and
`RESEND_SMTP_PASSWORD`. Those keys were restored from the task-start revision to the encrypted
development and test credentials where present; their values were never printed. The SNS provider
and TOTP settings focused tests pass after these corrections. The six public operator host variables
in the development-container template were restored to their task-start definitions so their owned
host constraints keep working. The removed `ORG_EMAIL_ADDRESS_HMAC_KEY` environment entry is present
in encrypted credentials alongside the app/org email and telephone HMAC key entries; none of those
values is recorded here.

### Environment variable names

Values are intentionally omitted. `.env.container.devcontainer` removed these names:

```text
PREFERENCE_COM_JWT_AUDIENCE
PREFERENCE_COM_JWT_ISSUER
PREFERENCE_COM_JWT_REVOKED_KIDS
PRIVATE_AUTH_CORPORATE_URL
PRIVATE_BASE_CORPORATE_URL
PRIVATE_BASE_DEVELOPER_URL
PRIVATE_BASE_NETWORK_URL
PRIVATE_BASE_SERVICE_URL
PRIVATE_BASE_STAFF_URL
PRIVATE_CORE_CORPORATE_URL
PRIVATE_CORE_DEVELOPER_URL
PRIVATE_CORE_SERVICE_URL
PRIVATE_CORE_STAFF_URL
PRIVATE_DOCS_CORPORATE_URL
PRIVATE_DOCS_SERVICE_URL
PRIVATE_DOCS_STAFF_URL
PRIVATE_EDIT_STAFF_URL
PRIVATE_GUID_SERVICE_URL
PRIVATE_HELP_CORPORATE_URL
PRIVATE_HELP_SERVICE_URL
PRIVATE_HELP_STAFF_URL
PRIVATE_INFO_CORPORATE_URL
PRIVATE_INFO_SERVICE_URL
PRIVATE_INFO_STAFF_URL
PRIVATE_JUMP_GATEWAY_URL
PRIVATE_NEWS_CORPORATE_URL
PRIVATE_NEWS_SERVICE_URL
PRIVATE_NEWS_STAFF_URL
PRIVATE_PALM_SERVICE_URL
PRIVATE_PERFORMANCE_URL
PRIVATE_TECH_STAFF_URL
PRIVATE_VISA_CORPORATE_URL
ORG_EMAIL_ADDRESS_HMAC_KEY
PUBLIC_AUTH_CORPORATE_URL
PUBLIC_BASE_CORPORATE_URL
PUBLIC_BASE_DEVELOPER_URL
PUBLIC_CORE_CORPORATE_URL
PUBLIC_CORE_DEVELOPER_URL
PUBLIC_DOCS_CORPORATE_URL
PUBLIC_DOCS_SERVICE_URL
PUBLIC_DOCS_STAFF_URL
PUBLIC_EDGE_CORPORATE_URL
PUBLIC_EDGE_SERVICE_URL
PUBLIC_EDGE_STAFF_URL
PUBLIC_GUID_SERVICE_URL
PUBLIC_INFO_CORPORATE_URL
PUBLIC_INFO_SERVICE_URL
PUBLIC_INFO_STAFF_URL
PUBLIC_PERFORMANCE_URL
PUBLIC_STATUS_URL
PUBLIC_VISA_CORPORATE_URL
PUBLIC_WARP_CORPORATE_URL
RAILS_PERFORMANCE_ENABLED
RAILS_PERFORMANCE_USERNAME
```

Root `compose.yaml` removed interpolation names:
`ALLOY_OTLP_HTTP_HOST_PORT, CLOUDFLARED_EDGE_TOKEN, CLOUDFLARED_WORKERS_VPC_TOKEN, FAKECLOUD_HOST_PORT, GRAFANA_HOST_PORT, POSTGRESQL_PRIMARY_HOST_PORT, POSTGRESQL_REPLICA_HOST_PORT, VALKEY_CACHE_HOST_PORT, VALKEY_HOST_PORT, VALKEY_KVS_HOST_PORT`.
`.devcontainer/compose.yaml` removed interpolation names: `none`.

`.github/workflows/ci.yml` still references 47 retired-surface variable names (44 URL names and 3
rails-performance variables). The final audit found the containing `/home/global/workspace/.github`
mount is a read-only ZFS mount (`findmnt -T` reports `zfs ro`); the file itself is mode `0644`, and
the current process reports `W_OK=false`. A prior normal write attempt was refused before writing.
The mount was not remounted and permissions were not bypassed. `git worktree list` found no
alternate worktree containing the current uncommitted cleanup; the other checkout at this HEAD is a
clean baseline copy. The retained `PUBLIC_JUMP_GATEWAY_URL` is excluded because the accepted Jump
handoff contract and active Auth/Visa callers require it. Names still present:

```text
PRIVATE_AUTH_CORPORATE_URL
PRIVATE_BASE_CORPORATE_URL
PRIVATE_BASE_DEVELOPER_URL
PRIVATE_BASE_NETWORK_URL
PRIVATE_BASE_SERVICE_URL
PRIVATE_BASE_STAFF_URL
PRIVATE_CORE_CORPORATE_URL
PRIVATE_CORE_DEVELOPER_URL
PRIVATE_CORE_SERVICE_URL
PRIVATE_CORE_STAFF_URL
PRIVATE_DOCS_CORPORATE_URL
PRIVATE_DOCS_SERVICE_URL
PRIVATE_DOCS_STAFF_URL
PRIVATE_EDIT_STAFF_URL
PRIVATE_HELP_CORPORATE_URL
PRIVATE_HELP_SERVICE_URL
PRIVATE_HELP_STAFF_URL
PRIVATE_INFO_CORPORATE_URL
PRIVATE_INFO_SERVICE_URL
PRIVATE_INFO_STAFF_URL
PRIVATE_NEWS_CORPORATE_URL
PRIVATE_NEWS_SERVICE_URL
PRIVATE_NEWS_STAFF_URL
PRIVATE_PALM_SERVICE_URL
PRIVATE_PERFORMANCE_URL
PRIVATE_TECH_STAFF_URL
PUBLIC_AUTH_CORPORATE_URL
PUBLIC_BASE_CORPORATE_URL
PUBLIC_BASE_DEVELOPER_URL
PUBLIC_CORE_CORPORATE_URL
PUBLIC_CORE_DEVELOPER_URL
PUBLIC_DOCS_CORPORATE_URL
PUBLIC_DOCS_SERVICE_URL
PUBLIC_DOCS_STAFF_URL
PUBLIC_EDGE_CORPORATE_URL
PUBLIC_EDGE_SERVICE_URL
PUBLIC_EDGE_STAFF_URL
PUBLIC_GUID_SERVICE_URL
PUBLIC_INFO_CORPORATE_URL
PUBLIC_INFO_SERVICE_URL
PUBLIC_INFO_STAFF_URL
PUBLIC_PERFORMANCE_URL
PUBLIC_STATUS_URL
PUBLIC_WARP_CORPORATE_URL
RAILS_PERFORMANCE_ENABLED
RAILS_PERFORMANCE_PASSWORD
RAILS_PERFORMANCE_USERNAME
```

URL readers and host allow-lists in application code, boot config, and development config were
reduced to owned surfaces. The separate CI workflow references above remain an incomplete part of
the requested environment cleanup.

## 3. Model and database report

No model class or migration was deleted. The full static audit below lists each abstract `*Record`
database, concrete model references from non-model code with one example caller, models referenced
only from other models or tests, and the USED / ONLY-VIA-MODELS / UNUSED classification. Static name
matching limits are recorded in the report.

# Model and database usage report

Read-only static audit of the current shared worktree.

- Repository HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`
- Worktree: modified; results reflect its current contents.
- This model/database audit was read-only; the wider surface cleanup is uncommitted. No environment
  values or secrets are recorded.
- External OIDC client registry is treated as an intentional retained exception per owner
  instruction.

## Method and limits

Enumerated principal classes in non-concern `app/models/**/*.rb` files, inferred namespaces from
paths, and followed each model superclass to an abstract `*Record` base. Base database keys came
from `connects_to` declarations/inheritance. `config/database.yml` was inspected without evaluating
ERB: static development/test alias names and literal `rp_cells.connection` names were collected;
database-name expressions and runtime environment values were not evaluated or emitted. The file has
an empty `production: {}` mapping.

The scan found 802 principal model-path classes: 28 abstract record bases, 765 concrete ActiveRecord
models, and 9 classes without resolved ActiveRecord ancestry. Current `rp_cells` ERB generates 9 RP
connection names in development and test.

Non-model references were scanned in `app/` outside `app/models/`, `lib/`, and `config/` (`.rb`,
`.erb`, `.rake`, `.yml`, `.yaml`, `.json`). Model references were scanned in all model source
including concerns and Ruby tests. Static CamelCase tokens were matched after stripping `#` comments
and skipping model class declarations. Unambiguous short names and path-local model namespace names
were resolved. One representative non-model caller (path:line) is listed for every concrete model
with a match.

This is static name matching, not runtime reachability analysis. It can miss dynamic
constantization, SQL/table-name references, generated code, unqualified names whose lexical
namespace is not reflected in source paths, or callers in unscanned file types. No-static-hit names
are not drop recommendations. USED may reflect a catalog/maintenance task; it does not mean every
model on that database is a current surface caller.

## Abstract bases and database keys

| Abstract base        | Writing key   | Reading key           | Development/test config |
| -------------------- | ------------- | --------------------- | ----------------------- |
| `AppPrincipalRecord` | `app_zenith`  | `app_zenith_replica`  | yes                     |
| `AppRpRecord`        | `app_zenith`  | `app_zenith_replica`  | yes                     |
| `AppSettingRecord`   | `app_setting` | `app_setting_replica` | yes                     |
| `AppSignalRecord`    | `app_signal`  | `app_signal_replica`  | yes                     |
| `AppZenithRecord`    | `app_zenith`  | `app_zenith_replica`  | yes                     |
| `ApplicationRecord`  | `primary`     | `primary`             | yes                     |
| `AvatarRecord`       | `avatar`      | `avatar_replica`      | yes                     |
| `ChronicleRecord`    | `chronicle`   | `chronicle_replica`   | yes                     |
| `ComSettingRecord`   | `com_setting` | `com_setting_replica` | yes                     |
| `OccurrenceRecord`   | `occurrence`  | `occurrence_replica`  | yes                     |
| `OpBaseAppRecord`    | `op_base_app` | `op_base_app_replica` | yes                     |
| `OpBaseOrgRecord`    | `op_base_org` | `op_base_org_replica` | yes                     |
| `OrgPrincipalRecord` | `org_zenith`  | `org_zenith_replica`  | yes                     |
| `OrgRpRecord`        | `org_zenith`  | `org_zenith_replica`  | yes                     |
| `OrgSettingRecord`   | `org_setting` | `org_setting_replica` | yes                     |
| `OrgSignalRecord`    | `org_signal`  | `org_signal_replica`  | yes                     |
| `OrgZenithRecord`    | `org_zenith`  | `org_zenith_replica`  | yes                     |
| `PublishingRecord`   | `publishing`  | `publishing_replica`  | yes                     |
| `RpBaseAppRecord`    | `rp_base_app` | `rp_base_app_replica` | yes                     |
| `RpBaseOrgRecord`    | `rp_base_org` | `rp_base_org_replica` | yes                     |
| `RpCoreAppRecord`    | `rp_core_app` | `rp_core_app_replica` | yes                     |
| `RpCoreOrgRecord`    | `rp_core_org` | `rp_core_org_replica` | yes                     |
| `RpEditOrgRecord`    | `rp_edit_org` | `rp_edit_org_replica` | yes                     |
| `RpPalmAppRecord`    | `rp_palm_app` | `rp_palm_app_replica` | yes                     |
| `RpTechOrgRecord`    | `rp_tech_org` | `rp_tech_org_replica` | yes                     |
| `RpWarpAppRecord`    | `rp_warp_app` | `rp_warp_app_replica` | yes                     |
| `RpWarpOrgRecord`    | `rp_warp_org` | `rp_warp_org_replica` | yes                     |
| `SearchRecord`       | `search`      | `search_replica`      | yes                     |

### Database classification summary

- **USED:** `app_zenith`, `op_base_org`, `op_base_app`, `search`, `occurrence`, `org_zenith`,
  `primary`, `publishing`, `com_setting`, `avatar`, `org_setting`, `org_signal`, `app_setting`,
  `chronicle`, `app_signal`.
- **ONLY-VIA-MODELS:** `rp_warp_org`, `rp_core_app`, `rp_core_org`, `rp_warp_app`, `rp_base_org`,
  `rp_edit_org`, `rp_base_app`, `rp_palm_app`, `rp_tech_org`.
- **UNUSED:** none.

The identifier inventory query is still called from `lib/tasks/identifier_contract.rake`. Its
abstract-base catalog specs cover 15 database keys (primary, publishing, app_zenith, org_zenith,
app_setting, com_setting, org_setting, search, op_base_app, op_base_org, app_signal, org_signal,
avatar, chronicle, occurrence). This makes `com_setting` and `search` USED even though they have no
concrete non-model model caller. `primary` is also used by Flipper’s ActiveRecord adapter in
`config/initializers/flipper.rb`. The inventory task does not include RP databases.

`queue`, `storage`, and `storage_replica` are configured framework connections without an abstract
repository `*Record` base and are outside this report’s model/database classification.

## Per-database inventory

### `app_zenith` — USED (configured; 114 concrete models)

Abstract base(s): `AppZenithRecord`, `AppPrincipalRecord`, `AppRpRecord`

Non-model concrete model references (70):

- `AppEnforcementAppeal` — `app/jobs/enforcement_reconciliation_job.rb:19`
- `AppEnforcementCase` — `app/jobs/enforcement_reconciliation_job.rb:18`
- `AppEnforcementIdentifierEffect` — `app/services/social_auth_link_handler.rb:67`
- `AppIdentityAuthenticationEvent` — `app/jobs/op_identity_event_delivery_job.rb:9`
- `Client` — `app/jobs/social_audit_delivery_job.rb:30`
- `ClientAccount` — `app/services/acme_selector_surface_config.rb:43`
- `ClientAppleNotificationEvent` — `app/jobs/apple_notification_processing_job.rb:8`
- `ClientAuthorityLock` — `app/operations/client_persona_creator.rb:37`
- `ClientBanner` — `app/queries/current_banner_query.rb:21`
- `ClientContactAuditOutbox` — `app/jobs/contact_audit_delivery_job.rb:14`
- `ClientEmail` — `app/jobs/retention_purge_job.rb:41`
- `ClientEmailStatus` — `app/services/sign_up_artifact_cleanup.rb:271`
- `ClientEnforcementRecoveryCeremony` — `app/operations/enforcement_case_end_operation.rb:146`
- `ClientExternalIdentity` — `app/jobs/social_audit_delivery_job.rb:64`
- `ClientIdentity` — `app/operations/client_persona_creator.rb:40`
- `ClientIdentityState` — `app/services/acme_selector_surface_config.rb:46`
- `ClientMfaStatus` — `app/controllers/concerns/sign_email_registrable.rb:149`
- `ClientPasskey` — `app/jobs/retention_purge_job.rb:42`
- `ClientPasskeyAuditOutbox` — `app/jobs/passkey_audit_delivery_job.rb:8`
- `ClientPasskeyStatus` — `app/services/sign_up_artifact_cleanup.rb:273`
- `ClientPersona` — `app/operations/client_persona_creator.rb:46`
- `ClientPersonaAuthorityCutover` — `app/queries/authority_owner_migration_inventory.rb:93`
- `ClientPersonaLifecycle` — `app/operations/client_persona_creator.rb:51`
- `ClientPersonaOwnership` — `app/operations/client_persona_creator.rb:55`
- `ClientPreference` — `app/operations/public_id_null_only_backfill_operation.rb:9`
- `ClientPreferenceCurrency` — `app/controllers/concerns/preference_class_registry.rb:129`
- `ClientPreferenceCurrencyOption` — `app/controllers/concerns/preference_class_registry.rb:117`
- `ClientPreferenceDateFormat` — `app/controllers/concerns/preference_class_registry.rb:130`
- `ClientPreferenceDateFormatOption` — `app/controllers/concerns/preference_class_registry.rb:118`
- `ClientPreferenceDensity` — `app/controllers/concerns/preference_class_registry.rb:133`
- `ClientPreferenceDensityOption` — `app/controllers/concerns/preference_class_registry.rb:121`
- `ClientPreferenceLanguage` — `app/controllers/concerns/preference_class_registry.rb:126`
- `ClientPreferenceLanguageOption` — `app/controllers/concerns/preference_class_registry.rb:114`
- `ClientPreferenceMotion` — `app/controllers/concerns/preference_class_registry.rb:132`
- `ClientPreferenceMotionOption` — `app/controllers/concerns/preference_class_registry.rb:120`
- `ClientPreferencePageSize` — `app/controllers/concerns/preference_class_registry.rb:134`
- `ClientPreferencePageSizeOption` — `app/controllers/concerns/preference_class_registry.rb:122`
- `ClientPreferenceRegion` — `app/controllers/concerns/preference_class_registry.rb:127`
- `ClientPreferenceRegionOption` — `app/controllers/concerns/preference_class_registry.rb:115`
- `ClientPreferenceStatus` — `app/controllers/concerns/preference_write_boundary.rb:34`
- `ClientPreferenceTheme` — `app/controllers/concerns/preference_class_registry.rb:128`
- `ClientPreferenceThemeOption` — `app/controllers/concerns/preference_class_registry.rb:116`
- `ClientPreferenceTimeFormat` — `app/controllers/concerns/preference_class_registry.rb:131`
- `ClientPreferenceTimeFormatOption` — `app/controllers/concerns/preference_class_registry.rb:119`
- `ClientPreferenceTimezone` — `app/controllers/concerns/preference_class_registry.rb:125`
- `ClientPreferenceTimezoneOption` — `app/controllers/concerns/preference_class_registry.rb:113`
- `ClientPrivacyRequest` — `app/jobs/retention_purge_job.rb:35`
- `ClientProcessorErasureNotification` — `app/jobs/processor_erasure_notification_retry_job.rb:18`
- `ClientRegistrationCompletion` — `app/operations/app_sign_up_registration_committer.rb:35`
- `ClientRetentionHold` — `app/jobs/retention_purge_job.rb:36`
- `ClientSecretAuditOutbox` — `app/jobs/client_secret_audit_outbox_purge_job.rb:17`
- `ClientSecretCredential` — `app/jobs/client_secret_lifecycle_job.rb:47`
- `ClientSecretIssuance` — `app/jobs/client_secret_lifecycle_job.rb:32`
- `ClientSocialAuditOutbox` — `app/jobs/social_audit_delivery_job.rb:15`
- `ClientStatus` — `app/services/identity_graph_bootstrap_authority.rb:217`
- `ClientTelephone` — `app/jobs/retention_purge_job.rb:41`
- `ClientTelephoneStatus` — `app/services/sign_up_artifact_cleanup.rb:272`
- `ClientTotpCredential` — `app/operations/identity_step_up_totp_verification_committer.rb:22`
- `ClientVisibility` — `app/controllers/concerns/sign_email_registrable.rb:148`
- `ClientWithdrawalFlow` — `app/jobs/retention_purge_job.rb:33`
- `Enterprise` — `app/operations/enterprise_creator.rb:38`
- `EnterpriseAuthorityCutover` — `app/queries/authority_owner_migration_inventory.rb:118`
- `EnterpriseLifecycle` — `app/operations/enterprise_creator.rb:39`
- `EnterpriseOwnership` — `app/operations/enterprise_creator.rb:43`
- `EnterpriseUnit` — `app/services/acme_selector_surface_config.rb:55`
- `Member` — `app/jobs/retention_purge_job.rb:39`
- `PersonaAssignment` — `app/services/acme_selector_surface_config.rb:49`
- `PersonaMembership` — `app/policies/organization_membership_policy.rb:34`
- `PersonaMembershipKind` — `app/resolvers/avatar_permission_resolver.rb:31`
- `PersonaMembershipState` — `app/services/acme_selector_surface_config.rb:59`

Model/test-only (42): `AppEnforcementAuthenticationMethodEffect`, `AppEnforcementPrincipalEffect`,
`AppEnforcementPrincipalLink`, `ClientBulletin`, `ClientEmailHistory`,
`ClientIdentifierRotationAudit`, `ClientMemberDeletion`, `ClientMemberDiscovery`,
`ClientMemberImpersonation`, `ClientMemberObservation`, `ClientMemberRevocation`,
`ClientMemberSuspension`, `ClientMembership`, `ClientOidcIdentityBinding`,
`ClientPersonaAdministrationGrant`, `ClientPersonaDelegationGrant`,
`ClientPersonaOwnershipTransferRequest`, `ClientPersonaUsageGrant`, `ClientPersonaViewGrant`,
`ClientPreferenceAdultContentGate`, `ClientPreferenceAdultContentGateOption`,
`ClientPrivacyRequestStatus`, `ClientProcessorErasureNotificationAttempt`,
`ClientProcessorErasureNotificationStatus`, `ClientProfile`, `ClientProfileStatus`,
`ClientRegistrationCompletionMethod`, `ClientRetentionHoldStatus`, `ClientSecurityMode`,
`ClientTelephoneHistory`, `ClientTotpCredentialStatus`, `ClientWithdrawalCeremony`,
`ClientWithdrawalFlowEvent`, `ClientWithdrawalFlowStatus`, `CoreAppClientBridge`,
`EnterpriseAdministrationGrant`, `EnterpriseDelegationGrant`, `EnterpriseOwnershipTransferRequest`,
`EnterpriseUnitClosure`, `EnterpriseViewGrant`, `MemberStatus`, `PersonaMembershipRevokeReason`

No static hits (2): `ClientMember`, `ClientSocialLinkSourceReceipt`

### `op_base_org` — USED (configured; 53 concrete models)

Abstract base(s): `OpBaseOrgRecord`

Non-model concrete model references (40):

- `OpOrgAuthorityStop` — `app/operations/op_authority_stop_committer.rb:41`
- `OpOrgAuthorityStopEpochCutoff` — `app/operations/op_authority_stop_committer.rb:44`
- `OpOrgAuthorityStopGrantTarget` — `app/operations/op_authority_stop_committer.rb:43`
- `OpOrgAuthorityStopParticipant` — `app/jobs/op_outbox_dispatch_job.rb:18`
- `OpOrgAuthorityStopRootTarget` — `app/operations/op_authority_stop_committer.rb:42`
- `OpOrgGrant` — `app/operations/oidc_step_up_authorization_cancellation_committer.rb:77`
- `OpOrgInboundEventReceipt` — `app/operations/op_identity_event_invalidator.rb:14`
- `OperatorAuthAdmissionBinding` —
  `app/operations/oidc_step_up_authorization_cancellation_committer.rb:79`
- `OperatorAuthCeremonySession` —
  `app/operations/identity_step_up_ceremony_freshness_committer.rb:197`
- `OperatorDeviceSession` —
  `app/operations/oidc_step_up_authorization_cancellation_committer.rb:147`
- `OperatorDpopProofState` — `app/jobs/dpop_proof_state_purge_job.rb:20`
- `OperatorEmailCeremonyTransaction` — `app/operations/email_reentry_otp_issuer.rb:41`
- `OperatorOidcAuthorizationTransaction` —
  `app/operations/oidc_authorization_transaction_purger.rb:10`
- `OperatorOidcConnection` — `app/operations/oidc_connection_recorder.rb:43`
- `OperatorPasskeyCeremonyCandidate` —
  `app/operations/identity_passkey_registration_verification_committer.rb:24`
- `OperatorPasskeyCeremonyTransaction` —
  `app/operations/identity_step_up_ceremony_transaction_purger.rb:15`
- `OperatorSecretCredentialCeremonyTransaction` —
  `app/operations/identity_secret_credential_ceremony_transaction_purger.rb:7`
- `OperatorSensitiveAdmission` — `app/operations/sensitive_admission_accounting_writer.rb:12`
- `OperatorSensitiveAdmissionAuditAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb:7`
- `OperatorSensitiveAdmissionAuditOutbox` —
  `app/operations/sensitive_admission_accounting_writer.rb:12`
- `OperatorSessionLimitResolutionTransaction` — `app/jobs/retention_purge_job.rb:31`
- `OperatorSignInFlow` — `app/jobs/retention_purge_job.rb:32`
- `OperatorSignUpFlow` — `app/jobs/retention_purge_job.rb:37`
- `OperatorStepUpAuditOutbox` — `app/values/step_up_audit_outbox_sources_registry.rb:17`
- `OperatorStepUpAuditOutboxAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb:19`
- `OperatorStepUpCeremonyTransaction` —
  `app/operations/oidc_step_up_authorization_cancellation_committer.rb:192`
- `OperatorStepUpCommit` — `app/services/oidc_token_exchange_coordinator.rb:837`
- `OperatorStepUpContext` —
  `app/operations/oidc_step_up_authorization_cancellation_committer.rb:191`
- `OperatorStepUpContextState` —
  `app/operations/oidc_step_up_authorization_cancellation_committer.rb:74`
- `OperatorStepUpContextTransition` —
  `app/operations/operator_step_up_context_transition_writer.rb:39`
- `OperatorStepUpSession` — `app/jobs/retention_purge_job.rb:45`
- `OperatorTelephoneCeremonyTransaction` —
  `app/operations/telephone_credential_registration_otp_delivery_guard.rb:22`
- `OperatorToken` — `app/jobs/retention_purge_job.rb:43`
- `OperatorTokenBindingMethod` — `app/controllers/concerns/authentication_base.rb:2638`
- `OperatorTokenDbscStatus` — `app/controllers/concerns/authentication_base.rb:2639`
- `OperatorTokenKind` — `app/controllers/concerns/authentication_base.rb:2640`
- `OperatorTokenStatus` — `app/controllers/concerns/authentication_base.rb:2641`
- `OperatorVerification` — `app/jobs/retention_purge_job.rb:44`
- `OperatorVisaSensitiveAdmission` — `app/operations/visa_sensitive_admission_session_revoker.rb:73`
- `OrganizationInvitation` — `app/policies/org_registration_policy.rb:39`

Model/test-only (13): `OpOrgAuthorityStopCause`, `OpOrgAuthorityStopParticipantStatus`,
`OpOrgAuthorityStopScope`, `OpOrgConsumedJti`, `OpOrgGrantLogoutHint`,
`OperatorAuthAdmissionBindingStatus`, `OperatorAuthCeremonySessionStatus`,
`OperatorOauthCallbackState`, `OperatorOidcAuthorizationTransactionStatus`,
`OperatorSessionLimitResolutionState`, `OperatorSignInFlowState`, `OperatorSignUpFlowStatus`,
`OperatorStepUpAuditOutboxDeliveryState`

No static hits (0): None.

### `op_base_app` — USED (configured; 65 concrete models)

Abstract base(s): `OpBaseAppRecord`

Non-model concrete model references (50):

- `ClientAuthAdmissionBinding` —
  `app/operations/oidc_step_up_authorization_cancellation_committer.rb:79`
- `ClientAuthCeremonySession` — `app/operations/client_secret_claim_committer.rb:15`
- `ClientDeviceSession` — `app/operations/oidc_step_up_authorization_cancellation_committer.rb:146`
- `ClientDpopProofState` — `app/jobs/dpop_proof_state_purge_job.rb:19`
- `ClientEmailCeremonyTransaction` — `app/operations/email_reentry_otp_issuer.rb:40`
- `ClientOauthCallbackState` — `app/services/social_auth_callback_state_store.rb:34`
- `ClientOidcAuthorizationTransaction` — `app/jobs/retention_purge_job.rb:374`
- `ClientOidcConnection` — `app/operations/oidc_connection_recorder.rb:44`
- `ClientPasskeyCeremonyTransaction` —
  `app/operations/identity_step_up_ceremony_transaction_purger.rb:11`
- `ClientSecretCredentialCeremonyTransaction` —
  `app/operations/identity_secret_credential_ceremony_transaction_purger.rb:6`
- `ClientSecretSignInReceipt` — `app/jobs/client_secret_lifecycle_job.rb:71`
- `ClientSensitiveAdmission` — `app/operations/sensitive_admission_accounting_writer.rb:11`
- `ClientSensitiveAdmissionAuditAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb:5`
- `ClientSensitiveAdmissionAuditOutbox` —
  `app/operations/sensitive_admission_accounting_writer.rb:11`
- `ClientSessionLimitResolutionTransaction` — `app/jobs/retention_purge_job.rb:31`
- `ClientSignInFlow` — `app/jobs/client_secret_lifecycle_job.rb:70`
- `ClientSignUpFlow` — `app/jobs/client_secret_lifecycle_job.rb:99`
- `ClientSocialCeremonyTransaction` —
  `app/operations/identity_social_ceremony_transaction_purger.rb:6`
- `ClientStepUpAuditOutbox` — `app/values/step_up_audit_outbox_sources_registry.rb:10`
- `ClientStepUpAuditOutboxAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb:12`
- `ClientStepUpCeremonyTransaction` —
  `app/operations/oidc_step_up_authorization_cancellation_committer.rb:192`
- `ClientStepUpCommit` — `app/services/oidc_token_exchange_coordinator.rb:836`
- `ClientStepUpContext` — `app/operations/oidc_step_up_authorization_cancellation_committer.rb:191`
- `ClientStepUpContextState` —
  `app/operations/oidc_step_up_authorization_cancellation_committer.rb:74`
- `ClientStepUpContextTransition` — `app/operations/client_step_up_context_transition_writer.rb:39`
- `ClientStepUpSession` — `app/jobs/retention_purge_job.rb:45`
- `ClientTelephoneCeremonyTransaction` —
  `app/operations/telephone_credential_registration_otp_delivery_guard.rb:20`
- `ClientToken` — `app/jobs/retention_purge_job.rb:43`
- `ClientTokenBindingMethod` — `app/controllers/concerns/authentication_base.rb:2631`
- `ClientTokenDbscStatus` — `app/controllers/concerns/authentication_base.rb:2632`
- `ClientTokenKind` — `app/controllers/concerns/authentication_base.rb:2633`
- `ClientTokenStatus` — `app/controllers/concerns/authentication_base.rb:2634`
- `ClientTotpCeremonyTransaction` — `app/operations/identity_totp_enrollment_final_committer.rb:92`
- `ClientVerification` — `app/jobs/retention_purge_job.rb:44`
- `ClientVisaSensitiveAdmission` — `app/operations/visa_sensitive_admission_session_revoker.rb:70`
- `ClientVisaSocialLinkAdmission` — `app/operations/visa_sensitive_admission_session_revoker.rb:100`
- `IdentityPasskeyCeremonyCandidate` —
  `app/operations/identity_passkey_registration_verification_committer.rb:13`
- `IdentitySecretCredentialCeremonyCandidate` —
  `app/services/identity_secret_credential_ceremony_candidate_store.rb:42`
- `IdentitySocialCeremonyCandidate` — `app/services/identity_social_ceremony_candidate_store.rb:50`
- `IdentityTotpCeremonyCandidate` — `app/operations/identity_totp_enrollment_final_committer.rb:95`
- `OpAppAuthorityStop` — `app/operations/op_authority_stop_committer.rb:28`
- `OpAppAuthorityStopEpochCutoff` — `app/operations/op_authority_stop_committer.rb:31`
- `OpAppAuthorityStopGrantTarget` — `app/operations/op_authority_stop_committer.rb:30`
- `OpAppAuthorityStopParticipant` — `app/jobs/op_outbox_dispatch_job.rb:17`
- `OpAppAuthorityStopRootTarget` — `app/operations/op_authority_stop_committer.rb:29`
- `OpAppGrant` — `app/operations/oidc_step_up_authorization_cancellation_committer.rb:77`
- `OpAppInboundEventReceipt` — `app/operations/op_identity_event_invalidator.rb:13`
- `SecurityConsumedJti` — `app/jobs/security_consumed_jti_purge_job.rb:27`
- `SecurityOneTimeReveal` — `app/jobs/security_one_time_reveal_purge_job.rb:27`
- `TurnstileReplay` — `app/services/turnstile_replay_store.rb:17`

Model/test-only (14): `ClientAuthAdmissionBindingStatus`, `ClientAuthCeremonySessionStatus`,
`ClientOidcAuthorizationTransactionStatus`, `ClientSessionLimitResolutionState`,
`ClientSignInFlowState`, `ClientSignUpFlowCleanupStatus`, `ClientSignUpFlowStatus`,
`ClientStepUpAuditOutboxDeliveryState`, `LogoutTransaction`, `OpAppAuthorityStopCause`,
`OpAppAuthorityStopParticipantStatus`, `OpAppAuthorityStopScope`, `OpAppConsumedJti`,
`OpAppGrantLogoutHint`

No static hits (1): `ClientEmergencySignInOperation`

### `search` — USED (configured; 0 concrete models)

Abstract base(s): `SearchRecord`

No concrete model class has a non-model caller. Abstract-base caller: `SearchRecord` in
`app/queries/identifier_contract_inventory_query.rb:23`, reached by `identifiers:inventory` in
`lib/tasks/identifier_contract.rake`.

Model/test-only (0): None.

No static hits (0): None.

### `occurrence` — USED (configured; 52 concrete models)

Abstract base(s): `OccurrenceRecord`

Non-model concrete model references (12):

- `AreaOccurrence` — `app/jobs/retention_purge_job.rb:46`
- `ClientOccurrence` — `app/jobs/retention_purge_job.rb:46`
- `DomainOccurrence` — `app/jobs/retention_purge_job.rb:47`
- `EmailOccurrence` — `app/jobs/retention_purge_job.rb:47`
- `EmailOccurrenceStatus` — `app/services/sign_in_otp_resender.rb:205`
- `IpOccurrence` — `app/jobs/retention_purge_job.rb:47`
- `JwtAnomalyEvent` — `app/subscribers/jwt_anomaly_subscriber.rb:34`
- `JwtOccurrence` — `app/jobs/retention_purge_job.rb:47`
- `OperatorOccurrence` — `app/jobs/retention_purge_job.rb:46`
- `TelephoneOccurrence` — `app/jobs/retention_purge_job.rb:47`
- `VisitorOccurrence` — `app/jobs/retention_purge_job.rb:46`
- `ZipOccurrence` — `app/jobs/retention_purge_job.rb:46`

Model/test-only (40): `AreaClientOccurrence`, `AreaDomainOccurrence`, `AreaEmailOccurrence`,
`AreaIpOccurrence`, `AreaOccurrenceStatus`, `AreaOperatorOccurrence`, `AreaTelephoneOccurrence`,
`AreaVisitorOccurrence`, `AreaZipOccurrence`, `ClientOccurrenceStatus`, `ClientZipOccurrence`,
`DomainClientOccurrence`, `DomainEmailOccurrence`, `DomainIpOccurrence`, `DomainOccurrenceStatus`,
`DomainOperatorOccurrence`, `DomainTelephoneOccurrence`, `DomainZipOccurrence`,
`EmailClientOccurrence`, `EmailIpOccurrence`, `EmailOperatorOccurrence`, `EmailTelephoneOccurrence`,
`EmailVisitorOccurrence`, `EmailZipOccurrence`, `IpClientOccurrence`, `IpOccurrenceStatus`,
`IpOperatorOccurrence`, `IpTelephoneOccurrence`, `IpVisitorOccurrence`, `IpZipOccurrence`,
`JwtOccurrenceStatus`, `OperatorClientOccurrence`, `OperatorOccurrenceStatus`,
`OperatorTelephoneOccurrence`, `OperatorZipOccurrence`, `TelephoneClientOccurrence`,
`TelephoneOccurrenceStatus`, `TelephoneZipOccurrence`, `VisitorOccurrenceStatus`,
`ZipOccurrenceStatus`

No static hits (0): None.

### `rp_warp_org` — ONLY-VIA-MODELS (configured; 6 concrete models)

Abstract base(s): `RpWarpOrgRecord`

No concrete model class caller in non-model `app/lib/config` code was found.

Model/test-only (5): `RpWarpOrgEventReceipt`, `RpWarpOrgIdentityBinding`,
`RpWarpOrgOpSessionBinding`, `RpWarpOrgPrincipal`, `RpWarpOrgSession`

No static hits (1): `RpWarpOrgCallbackState`

### `org_zenith` — USED (configured; 97 concrete models)

Abstract base(s): `OrgRpRecord`, `OrgZenithRecord`, `OrgPrincipalRecord`

Non-model concrete model references (56):

- `Agent` — `app/operations/agent_creator.rb:43`
- `AgentAssignment` — `app/services/acme_selector_surface_config.rb:80`
- `AgentAuthorityCutover` — `app/queries/authority_owner_migration_inventory.rb:141`
- `AgentLifecycle` — `app/operations/agent_creator.rb:48`
- `AgentMembership` — `app/policies/organization_membership_policy.rb:25`
- `AgentMembershipKind` — `app/resolvers/avatar_permission_resolver.rb:42`
- `AgentMembershipState` — `app/services/acme_selector_surface_config.rb:90`
- `AgentOwnership` — `app/operations/agent_creator.rb:52`
- `Bureau` — `app/operations/bureau_creator.rb:37`
- `BureauAuthorityCutover` — `app/queries/authority_owner_migration_inventory.rb:166`
- `BureauLifecycle` — `app/operations/bureau_creator.rb:38`
- `BureauOwnership` — `app/operations/bureau_creator.rb:42`
- `BureauUnit` — `app/services/acme_selector_surface_config.rb:86`
- `Operator` — `app/jobs/retention_purge_job.rb:48`
- `OperatorAccount` — `app/services/acme_selector_surface_config.rb:74`
- `OperatorAuthorityLock` — `app/operations/bureau_creator.rb:30`
- `OperatorBanner` — `app/queries/current_banner_query.rb:22`
- `OperatorCapabilityGrant` — `lib/tasks/operator_capabilities.rake:22`
- `OperatorEmail` — `app/operations/email_reentry_otp_issuer.rb:41`
- `OperatorEmailHistory` — `app/jobs/retention_purge_job.rb:423`
- `OperatorEntraIdentity` — `app/operations/operator_entra_identity_provisioner.rb:49`
- `OperatorIdentity` — `app/operations/agent_creator.rb:37`
- `OperatorIdentityState` — `app/services/acme_selector_surface_config.rb:77`
- `OperatorPasskey` — `app/operations/identity_passkey_registration_verification_committer.rb:25`
- `OperatorPasskeyAuditOutbox` — `app/jobs/passkey_audit_delivery_job.rb:9`
- `OperatorPasskeyStatus` — `app/values/webauthn/surface.rb:55`
- `OperatorPreference` — `app/operations/public_id_null_only_backfill_operation.rb:10`
- `OperatorPreferenceCurrency` — `app/controllers/concerns/preference_class_registry.rb:156`
- `OperatorPreferenceCurrencyOption` — `app/controllers/concerns/preference_class_registry.rb:144`
- `OperatorPreferenceDateFormat` — `app/controllers/concerns/preference_class_registry.rb:157`
- `OperatorPreferenceDateFormatOption` — `app/controllers/concerns/preference_class_registry.rb:145`
- `OperatorPreferenceDensity` — `app/controllers/concerns/preference_class_registry.rb:160`
- `OperatorPreferenceDensityOption` — `app/controllers/concerns/preference_class_registry.rb:148`
- `OperatorPreferenceLanguage` — `app/controllers/concerns/preference_class_registry.rb:153`
- `OperatorPreferenceLanguageOption` — `app/controllers/concerns/preference_class_registry.rb:141`
- `OperatorPreferenceMotion` — `app/controllers/concerns/preference_class_registry.rb:159`
- `OperatorPreferenceMotionOption` — `app/controllers/concerns/preference_class_registry.rb:147`
- `OperatorPreferencePageSize` — `app/controllers/concerns/preference_class_registry.rb:161`
- `OperatorPreferencePageSizeOption` — `app/controllers/concerns/preference_class_registry.rb:149`
- `OperatorPreferenceRegion` — `app/controllers/concerns/preference_class_registry.rb:154`
- `OperatorPreferenceRegionOption` — `app/controllers/concerns/preference_class_registry.rb:142`
- `OperatorPreferenceStatus` — `app/controllers/concerns/preference_write_boundary.rb:41`
- `OperatorPreferenceTheme` — `app/controllers/concerns/preference_class_registry.rb:155`
- `OperatorPreferenceThemeOption` — `app/controllers/concerns/preference_class_registry.rb:143`
- `OperatorPreferenceTimeFormat` — `app/controllers/concerns/preference_class_registry.rb:158`
- `OperatorPreferenceTimeFormatOption` — `app/controllers/concerns/preference_class_registry.rb:146`
- `OperatorPreferenceTimezone` — `app/controllers/concerns/preference_class_registry.rb:152`
- `OperatorPreferenceTimezoneOption` — `app/controllers/concerns/preference_class_registry.rb:140`
- `OperatorSecretCredential` — `app/jobs/retention_purge_job.rb:38`
- `OperatorStatus` — `app/resolvers/avatar_permission_resolver.rb:35`
- `OperatorTelephone` — `app/operations/telephone_credential_registration_otp_delivery_guard.rb:22`
- `OperatorTelephoneHistory` — `app/jobs/retention_purge_job.rb:424`
- `OperatorWorkspaceAccount` — `app/jobs/retention_purge_job.rb:39`
- `OrgEnforcementAppeal` — `app/jobs/enforcement_reconciliation_job.rb:19`
- `OrgEnforcementCase` — `app/jobs/enforcement_reconciliation_job.rb:18`
- `OrgIdentityAuthenticationEvent` — `app/jobs/op_identity_event_delivery_job.rb:9`

Model/test-only (38): `AgentAdministrationGrant`, `AgentDelegationGrant`,
`AgentMembershipRevokeReason`, `AgentOwnershipTransferRequest`, `AgentUsageGrant`, `AgentViewGrant`,
`BureauAdministrationGrant`, `BureauDelegationGrant`, `BureauOwnershipTransferRequest`,
`BureauUnitClosure`, `BureauViewGrant`, `CoreOrgOperatorBridge`, `Department`, `DepartmentStatus`,
`Division`, `OperatorBulletin`, `OperatorEmailStatus`, `OperatorEntraIdentityState`,
`OperatorLifecycleRequest`, `OperatorMfaStatus`, `OperatorOidcIdentityBinding`,
`OperatorOrganization`, `OperatorPreferenceAdultContentGate`,
`OperatorPreferenceAdultContentGateOption`, `OperatorSecretCredentialKind`,
`OperatorSecretCredentialStatus`, `OperatorSecurityMode`, `OperatorTelephoneStatus`,
`OperatorVisibility`, `OperatorWorkspaceAccountMembership`, `OperatorWorkspaceAccountStatus`,
`OrgEnforcementAuthenticationMethodEffect`, `OrgEnforcementIdentifierEffect`,
`OrgEnforcementPrincipalEffect`, `OrgEnforcementPrincipalLink`, `OrganizationEntraConnection`,
`OrganizationEntraConnectionState`, `OrganizationStatus`

No static hits (3): `DivisionStatus`, `OperatorIdentifierRotationAudit`, `OrgIamOperationOutcome`

### `rp_core_app` — ONLY-VIA-MODELS (configured; 6 concrete models)

Abstract base(s): `RpCoreAppRecord`

No concrete model class caller in non-model `app/lib/config` code was found.

Model/test-only (5): `RpCoreAppEventReceipt`, `RpCoreAppIdentityBinding`,
`RpCoreAppOpSessionBinding`, `RpCoreAppPrincipal`, `RpCoreAppSession`

No static hits (1): `RpCoreAppCallbackState`

### `primary` — USED (configured; 0 concrete models)

Abstract base(s): `ApplicationRecord`

No concrete model class has a non-model caller. Abstract-base caller: `ApplicationRecord` in
`app/queries/identifier_contract_inventory_query.rb:16`, reached by `identifiers:inventory` in
`lib/tasks/identifier_contract.rake`.

Model/test-only (0): None.

No static hits (0): None.

### `rp_core_org` — ONLY-VIA-MODELS (configured; 6 concrete models)

Abstract base(s): `RpCoreOrgRecord`

No concrete model class caller in non-model `app/lib/config` code was found.

Model/test-only (5): `RpCoreOrgEventReceipt`, `RpCoreOrgIdentityBinding`,
`RpCoreOrgOpSessionBinding`, `RpCoreOrgPrincipal`, `RpCoreOrgSession`

No static hits (1): `RpCoreOrgCallbackState`

### `publishing` — USED (configured; 157 concrete models)

Abstract base(s): `PublishingRecord`

Non-model concrete model references (1):

- `Publishing::MediaFile` — `lib/tasks/object_storage.rake:173`

Model/test-only (132): `Publishing::Docs::App::Entry`, `Publishing::Docs::App::EntryRevision`,
`Publishing::Docs::App::EntryVersion`, `Publishing::Docs::App::RevisionMediaUsage`,
`Publishing::Docs::App::RevisionMultipleTaxonomyAssignment`,
`Publishing::Docs::App::RevisionSingleTaxonomyAssignment`, `Publishing::Docs::App::TaxonomyTerm`,
`Publishing::Docs::App::VersionMediaUsage`,
`Publishing::Docs::App::VersionMultipleTaxonomyAssignment`,
`Publishing::Docs::App::VersionSingleTaxonomyAssignment`, `Publishing::Docs::App::Vocabulary`,
`Publishing::Docs::Com::Entry`, `Publishing::Docs::Com::EntryRevision`,
`Publishing::Docs::Com::EntryVersion`, `Publishing::Docs::Com::RevisionMediaUsage`,
`Publishing::Docs::Com::RevisionMultipleTaxonomyAssignment`,
`Publishing::Docs::Com::RevisionSingleTaxonomyAssignment`, `Publishing::Docs::Com::TaxonomyTerm`,
`Publishing::Docs::Com::VersionMediaUsage`,
`Publishing::Docs::Com::VersionMultipleTaxonomyAssignment`,
`Publishing::Docs::Com::VersionSingleTaxonomyAssignment`, `Publishing::Docs::Com::Vocabulary`,
`Publishing::Docs::Org::Entry`, `Publishing::Docs::Org::EntryRevision`,
`Publishing::Docs::Org::EntryVersion`, `Publishing::Docs::Org::RevisionMediaUsage`,
`Publishing::Docs::Org::RevisionMultipleTaxonomyAssignment`,
`Publishing::Docs::Org::RevisionSingleTaxonomyAssignment`, `Publishing::Docs::Org::TaxonomyTerm`,
`Publishing::Docs::Org::VersionMediaUsage`,
`Publishing::Docs::Org::VersionMultipleTaxonomyAssignment`,
`Publishing::Docs::Org::VersionSingleTaxonomyAssignment`, `Publishing::Docs::Org::Vocabulary`,
`Publishing::Help::App::Entry`, `Publishing::Help::App::EntryRevision`,
`Publishing::Help::App::EntryVersion`, `Publishing::Help::App::RevisionMediaUsage`,
`Publishing::Help::App::RevisionMultipleTaxonomyAssignment`,
`Publishing::Help::App::RevisionSingleTaxonomyAssignment`, `Publishing::Help::App::TaxonomyTerm`,
`Publishing::Help::App::VersionMediaUsage`,
`Publishing::Help::App::VersionMultipleTaxonomyAssignment`,
`Publishing::Help::App::VersionSingleTaxonomyAssignment`, `Publishing::Help::App::Vocabulary`,
`Publishing::Help::Com::Entry`, `Publishing::Help::Com::EntryRevision`,
`Publishing::Help::Com::EntryVersion`, `Publishing::Help::Com::RevisionMediaUsage`,
`Publishing::Help::Com::RevisionMultipleTaxonomyAssignment`,
`Publishing::Help::Com::RevisionSingleTaxonomyAssignment`, `Publishing::Help::Com::TaxonomyTerm`,
`Publishing::Help::Com::VersionMediaUsage`,
`Publishing::Help::Com::VersionMultipleTaxonomyAssignment`,
`Publishing::Help::Com::VersionSingleTaxonomyAssignment`, `Publishing::Help::Com::Vocabulary`,
`Publishing::Help::Org::Entry`, `Publishing::Help::Org::EntryRevision`,
`Publishing::Help::Org::EntryVersion`, `Publishing::Help::Org::RevisionMediaUsage`,
`Publishing::Help::Org::RevisionMultipleTaxonomyAssignment`,
`Publishing::Help::Org::RevisionSingleTaxonomyAssignment`, `Publishing::Help::Org::TaxonomyTerm`,
`Publishing::Help::Org::VersionMediaUsage`,
`Publishing::Help::Org::VersionMultipleTaxonomyAssignment`,
`Publishing::Help::Org::VersionSingleTaxonomyAssignment`, `Publishing::Help::Org::Vocabulary`,
`Publishing::Info::App::Entry`, `Publishing::Info::App::EntryRevision`,
`Publishing::Info::App::EntryVersion`, `Publishing::Info::App::RevisionMediaUsage`,
`Publishing::Info::App::RevisionMultipleTaxonomyAssignment`,
`Publishing::Info::App::RevisionSingleTaxonomyAssignment`, `Publishing::Info::App::TaxonomyTerm`,
`Publishing::Info::App::VersionMediaUsage`,
`Publishing::Info::App::VersionMultipleTaxonomyAssignment`,
`Publishing::Info::App::VersionSingleTaxonomyAssignment`, `Publishing::Info::App::Vocabulary`,
`Publishing::Info::Com::Entry`, `Publishing::Info::Com::EntryRevision`,
`Publishing::Info::Com::EntryVersion`, `Publishing::Info::Com::RevisionMediaUsage`,
`Publishing::Info::Com::RevisionMultipleTaxonomyAssignment`,
`Publishing::Info::Com::RevisionSingleTaxonomyAssignment`, `Publishing::Info::Com::TaxonomyTerm`,
`Publishing::Info::Com::VersionMediaUsage`,
`Publishing::Info::Com::VersionMultipleTaxonomyAssignment`,
`Publishing::Info::Com::VersionSingleTaxonomyAssignment`, `Publishing::Info::Com::Vocabulary`,
`Publishing::Info::Org::Entry`, `Publishing::Info::Org::EntryRevision`,
`Publishing::Info::Org::EntryVersion`, `Publishing::Info::Org::RevisionMediaUsage`,
`Publishing::Info::Org::RevisionMultipleTaxonomyAssignment`,
`Publishing::Info::Org::RevisionSingleTaxonomyAssignment`, `Publishing::Info::Org::TaxonomyTerm`,
`Publishing::Info::Org::VersionMediaUsage`,
`Publishing::Info::Org::VersionMultipleTaxonomyAssignment`,
`Publishing::Info::Org::VersionSingleTaxonomyAssignment`, `Publishing::Info::Org::Vocabulary`,
`Publishing::News::App::Entry`, `Publishing::News::App::EntryRevision`,
`Publishing::News::App::EntryVersion`, `Publishing::News::App::RevisionMediaUsage`,
`Publishing::News::App::RevisionMultipleTaxonomyAssignment`,
`Publishing::News::App::RevisionSingleTaxonomyAssignment`, `Publishing::News::App::TaxonomyTerm`,
`Publishing::News::App::VersionMediaUsage`,
`Publishing::News::App::VersionMultipleTaxonomyAssignment`,
`Publishing::News::App::VersionSingleTaxonomyAssignment`, `Publishing::News::App::Vocabulary`,
`Publishing::News::Com::Entry`, `Publishing::News::Com::EntryRevision`,
`Publishing::News::Com::EntryVersion`, `Publishing::News::Com::RevisionMediaUsage`,
`Publishing::News::Com::RevisionMultipleTaxonomyAssignment`,
`Publishing::News::Com::RevisionSingleTaxonomyAssignment`, `Publishing::News::Com::TaxonomyTerm`,
`Publishing::News::Com::VersionMediaUsage`,
`Publishing::News::Com::VersionMultipleTaxonomyAssignment`,
`Publishing::News::Com::VersionSingleTaxonomyAssignment`, `Publishing::News::Com::Vocabulary`,
`Publishing::News::Org::Entry`, `Publishing::News::Org::EntryRevision`,
`Publishing::News::Org::EntryVersion`, `Publishing::News::Org::RevisionMediaUsage`,
`Publishing::News::Org::RevisionMultipleTaxonomyAssignment`,
`Publishing::News::Org::RevisionSingleTaxonomyAssignment`, `Publishing::News::Org::TaxonomyTerm`,
`Publishing::News::Org::VersionMediaUsage`,
`Publishing::News::Org::VersionMultipleTaxonomyAssignment`,
`Publishing::News::Org::VersionSingleTaxonomyAssignment`, `Publishing::News::Org::Vocabulary`

No static hits (24): `Publishing::Docs::App::EntrySlug`, `Publishing::Docs::App::Publication`,
`Publishing::Docs::Com::EntrySlug`, `Publishing::Docs::Com::Publication`,
`Publishing::Docs::Org::EntrySlug`, `Publishing::Docs::Org::Publication`,
`Publishing::Help::App::EntrySlug`, `Publishing::Help::App::Publication`,
`Publishing::Help::Com::EntrySlug`, `Publishing::Help::Com::Publication`,
`Publishing::Help::Org::EntrySlug`, `Publishing::Help::Org::Publication`,
`Publishing::Info::App::EntrySlug`, `Publishing::Info::App::Publication`,
`Publishing::Info::Com::EntrySlug`, `Publishing::Info::Com::Publication`,
`Publishing::Info::Org::EntrySlug`, `Publishing::Info::Org::Publication`,
`Publishing::News::App::EntrySlug`, `Publishing::News::App::Publication`,
`Publishing::News::Com::EntrySlug`, `Publishing::News::Com::Publication`,
`Publishing::News::Org::EntrySlug`, `Publishing::News::Org::Publication`

### `com_setting` — USED (configured; 29 concrete models)

Abstract base(s): `ComSettingRecord`

No concrete model class has a non-model caller. Abstract-base caller: `ComSettingRecord` in
`app/queries/identifier_contract_inventory_query.rb:21`, reached by `identifiers:inventory` in
`lib/tasks/identifier_contract.rake`.

Model/test-only (26): `ComPreference`, `ComPreferenceAdultContentGate`,
`ComPreferenceAdultContentGateOption`, `ComPreferenceBrowserBinding`, `ComPreferenceCurrency`,
`ComPreferenceCurrencyOption`, `ComPreferenceDateFormat`, `ComPreferenceDateFormatOption`,
`ComPreferenceDensity`, `ComPreferenceDensityOption`, `ComPreferenceLanguage`,
`ComPreferenceLanguageOption`, `ComPreferenceMotion`, `ComPreferenceMotionOption`,
`ComPreferencePageSize`, `ComPreferencePageSizeOption`, `ComPreferenceRegion`,
`ComPreferenceRegionOption`, `ComPreferenceStatus`, `ComPreferenceTheme`,
`ComPreferenceThemeOption`, `ComPreferenceTimeFormat`, `ComPreferenceTimeFormatOption`,
`ComPreferenceTimezone`, `ComPreferenceTimezoneOption`, `ComPreferenceWebPushOption`

No static hits (3): `ComPreferenceConsentReceipt`, `ComPreferenceCookie`, `ComPreferenceWebPush`

### `rp_warp_app` — ONLY-VIA-MODELS (configured; 6 concrete models)

Abstract base(s): `RpWarpAppRecord`

No concrete model class caller in non-model `app/lib/config` code was found.

Model/test-only (5): `RpWarpAppEventReceipt`, `RpWarpAppIdentityBinding`,
`RpWarpAppOpSessionBinding`, `RpWarpAppPrincipal`, `RpWarpAppSession`

No static hits (1): `RpWarpAppCallbackState`

### `rp_base_org` — ONLY-VIA-MODELS (configured; 14 concrete models)

Abstract base(s): `RpBaseOrgRecord`

No concrete model class caller in non-model `app/lib/config` code was found.

Model/test-only (13): `RpBaseOrgEventReceipt`, `RpBaseOrgIdentityBinding`,
`RpBaseOrgOpSessionBinding`, `RpBaseOrgPrincipal`, `RpBaseOrgSession`,
`RpBaseOrgSessionAvatarSelection`, `RpBaseOrgSessionSelection`, `RpBaseOrgStepUpAuditOutbox`,
`RpBaseOrgStepUpAuditOutboxAttempt`, `RpBaseOrgStepUpAuditOutboxDeliveryState`,
`RpBaseOrgStepUpState`, `RpBaseOrgStepUpStateStatus`, `RpBaseOrgStepUpStateTransition`

No static hits (1): `RpBaseOrgCallbackState`

### `avatar` — USED (configured; 45 concrete models)

Abstract base(s): `AvatarRecord`

Non-model concrete model references (14):

- `Avatar` — `app/jobs/retention_purge_job.rb:39`
- `AvatarAgentBinding` — `app/services/identity_graph_bootstrap_authority.rb:338`
- `AvatarAssignment` — `app/services/retention_cross_database_child_purge.rb:53`
- `AvatarBureauAgentGrant` — `app/resolvers/avatar_access_grant_resolver.rb:8`
- `AvatarBureauOwnershipPeriod` — `app/resolvers/avatar_access_grant_resolver.rb:8`
- `AvatarCapability` — `app/services/identity_graph_bootstrap_authority.rb:106`
- `AvatarEnterpriseOwnershipPeriod` — `app/resolvers/avatar_access_grant_resolver.rb:6`
- `AvatarEnterprisePersonaGrant` — `app/resolvers/avatar_access_grant_resolver.rb:6`
- `AvatarLifecycleState` — `app/services/avatar_provisioning/create.rb:90`
- `AvatarMoniker` — `app/operations/avatar_moniker_writer_operation.rb:30`
- `AvatarPersonaBinding` — `app/services/identity_graph_bootstrap_authority.rb:336`
- `AvatarPurgeDeferral` — `app/jobs/retention_purge_job.rb:204`
- `Handle` — `app/services/avatar_provisioning/create.rb:94`
- `HandleStatus` — `app/services/identity_graph_bootstrap_authority.rb:107`

Model/test-only (17): `AvatarBlock`, `AvatarBureauToBureauTransferDetail`,
`AvatarBureauToEnterpriseTransferDetail`, `AvatarEnterpriseToBureauTransferDetail`,
`AvatarEnterpriseToEnterpriseTransferDetail`, `AvatarFollow`, `AvatarGroup`,
`AvatarGroupConcreteOwnershipPeriod`, `AvatarGroupOwnershipPeriod`, `AvatarMute`,
`AvatarOwnershipCutover`, `AvatarOwnershipPeriod`, `AvatarOwnershipStatus`,
`AvatarOwnershipTransfer`, `AvatarTransferReservation`, `GroupAvatarMembership`, `HandleAssignment`

No static hits (14): `AvatarLifecycleEvent`, `AvatarMembership`, `AvatarMembershipStatus`,
`AvatarPermission`, `AvatarRole`, `AvatarRolePermission`, `HandleAssignmentStatus`,
`MemberAvatarAccess`, `MemberAvatarDeletion`, `MemberAvatarExtraction`, `MemberAvatarImpersonation`,
`MemberAvatarOversight`, `MemberAvatarSuspension`, `MemberAvatarVisibility`

### `org_setting` — USED (configured; 29 concrete models)

Abstract base(s): `OrgSettingRecord`

Non-model concrete model references (27):

- `OrgPreference` — `app/jobs/retention_purge_job.rb:40`
- `OrgPreferenceBrowserBinding` — `app/controllers/concerns/preference_browser_state_reader.rb:17`
- `OrgPreferenceConsentReceipt` — `app/controllers/concerns/preference_browser_state_reader.rb:13`
- `OrgPreferenceCookie` — `app/controllers/concerns/preference_class_registry.rb:81`
- `OrgPreferenceCurrency` — `app/controllers/concerns/preference_class_registry.rb:102`
- `OrgPreferenceCurrencyOption` — `app/controllers/concerns/preference_class_registry.rb:90`
- `OrgPreferenceDateFormat` — `app/controllers/concerns/preference_class_registry.rb:103`
- `OrgPreferenceDateFormatOption` — `app/controllers/concerns/preference_class_registry.rb:91`
- `OrgPreferenceDensity` — `app/controllers/concerns/preference_class_registry.rb:106`
- `OrgPreferenceDensityOption` — `app/controllers/concerns/preference_class_registry.rb:94`
- `OrgPreferenceLanguage` — `app/controllers/concerns/preference_class_registry.rb:99`
- `OrgPreferenceLanguageOption` — `app/controllers/concerns/preference_class_registry.rb:87`
- `OrgPreferenceMotion` — `app/controllers/concerns/preference_class_registry.rb:105`
- `OrgPreferenceMotionOption` — `app/controllers/concerns/preference_class_registry.rb:93`
- `OrgPreferencePageSize` — `app/controllers/concerns/preference_class_registry.rb:107`
- `OrgPreferencePageSizeOption` — `app/controllers/concerns/preference_class_registry.rb:95`
- `OrgPreferenceRegion` — `app/controllers/concerns/preference_class_registry.rb:100`
- `OrgPreferenceRegionOption` — `app/controllers/concerns/preference_class_registry.rb:88`
- `OrgPreferenceStatus` — `app/controllers/concerns/preference_class_registry.rb:80`
- `OrgPreferenceTheme` — `app/controllers/concerns/preference_class_registry.rb:101`
- `OrgPreferenceThemeOption` — `app/controllers/concerns/preference_class_registry.rb:89`
- `OrgPreferenceTimeFormat` — `app/controllers/concerns/preference_class_registry.rb:104`
- `OrgPreferenceTimeFormatOption` — `app/controllers/concerns/preference_class_registry.rb:92`
- `OrgPreferenceTimezone` — `app/controllers/concerns/preference_class_registry.rb:98`
- `OrgPreferenceTimezoneOption` — `app/controllers/concerns/preference_class_registry.rb:86`
- `OrgPreferenceWebPush` — `app/controllers/concerns/preference_write_boundary.rb:374`
- `OrgPreferenceWebPushOption` — `app/controllers/concerns/preference_write_boundary.rb:375`

Model/test-only (2): `OrgPreferenceAdultContentGate`, `OrgPreferenceAdultContentGateOption`

No static hits (0): None.

### `org_signal` — USED (configured; 2 concrete models)

Abstract base(s): `OrgSignalRecord`

Non-model concrete model references (1):

- `OperatorNotificationRecord` — `app/services/retention_cross_database_child_purge.rb:57`

Model/test-only (1): `OperatorNotification`

No static hits (0): None.

### `rp_edit_org` — ONLY-VIA-MODELS (configured; 6 concrete models)

Abstract base(s): `RpEditOrgRecord`

No concrete model class caller in non-model `app/lib/config` code was found.

Model/test-only (5): `RpEditOrgEventReceipt`, `RpEditOrgIdentityBinding`,
`RpEditOrgOpSessionBinding`, `RpEditOrgPrincipal`, `RpEditOrgSession`

No static hits (1): `RpEditOrgCallbackState`

### `app_setting` — USED (configured; 29 concrete models)

Abstract base(s): `AppSettingRecord`

Non-model concrete model references (27):

- `AppPreference` — `app/jobs/retention_purge_job.rb:40`
- `AppPreferenceBrowserBinding` — `app/controllers/concerns/preference_browser_state_reader.rb:16`
- `AppPreferenceConsentReceipt` — `app/controllers/concerns/preference_browser_state_reader.rb:12`
- `AppPreferenceCookie` — `app/controllers/concerns/preference_class_registry.rb:49`
- `AppPreferenceCurrency` — `app/controllers/concerns/preference_class_registry.rb:70`
- `AppPreferenceCurrencyOption` — `app/controllers/concerns/preference_class_registry.rb:58`
- `AppPreferenceDateFormat` — `app/controllers/concerns/preference_class_registry.rb:71`
- `AppPreferenceDateFormatOption` — `app/controllers/concerns/preference_class_registry.rb:59`
- `AppPreferenceDensity` — `app/controllers/concerns/preference_class_registry.rb:74`
- `AppPreferenceDensityOption` — `app/controllers/concerns/preference_class_registry.rb:62`
- `AppPreferenceLanguage` — `app/controllers/concerns/preference_class_registry.rb:67`
- `AppPreferenceLanguageOption` — `app/controllers/concerns/preference_class_registry.rb:55`
- `AppPreferenceMotion` — `app/controllers/concerns/preference_class_registry.rb:73`
- `AppPreferenceMotionOption` — `app/controllers/concerns/preference_class_registry.rb:61`
- `AppPreferencePageSize` — `app/controllers/concerns/preference_class_registry.rb:75`
- `AppPreferencePageSizeOption` — `app/controllers/concerns/preference_class_registry.rb:63`
- `AppPreferenceRegion` — `app/controllers/concerns/preference_class_registry.rb:68`
- `AppPreferenceRegionOption` — `app/controllers/concerns/preference_class_registry.rb:56`
- `AppPreferenceStatus` — `app/controllers/concerns/preference_class_registry.rb:48`
- `AppPreferenceTheme` — `app/controllers/concerns/preference_class_registry.rb:69`
- `AppPreferenceThemeOption` — `app/controllers/concerns/preference_class_registry.rb:57`
- `AppPreferenceTimeFormat` — `app/controllers/concerns/preference_class_registry.rb:72`
- `AppPreferenceTimeFormatOption` — `app/controllers/concerns/preference_class_registry.rb:60`
- `AppPreferenceTimezone` — `app/controllers/concerns/preference_class_registry.rb:66`
- `AppPreferenceTimezoneOption` — `app/controllers/concerns/preference_class_registry.rb:54`
- `AppPreferenceWebPush` — `app/controllers/concerns/preference_write_boundary.rb:374`
- `AppPreferenceWebPushOption` — `app/controllers/concerns/preference_write_boundary.rb:375`

Model/test-only (1): `AppPreferenceAdultContentGateOption`

No static hits (1): `AppPreferenceAdultContentGate`

### `chronicle` — USED (configured; 22 concrete models)

Abstract base(s): `ChronicleRecord`

Non-model concrete model references (18):

- `AccountAccessEvent` — `app/jobs/enforcement_reconciliation_job.rb:93`
- `AppPreferenceChronicle` — `app/jobs/retention_purge_job.rb:29`
- `AppPreferenceChronicleEvent` — `app/controllers/concerns/preference_class_registry.rb:51`
- `AppPreferenceChronicleLevel` — `app/controllers/concerns/preference_class_registry.rb:52`
- `Chronicle` — `app/jobs/social_audit_delivery_job.rb:33`
- `ChronicleOutboxEntry` — `app/controllers/concerns/authentication_audit_writer.rb:143`
- `ChronicleRetentionPolicy` — `app/jobs/client_secret_audit_delivery_job.rb:80`
- `ChronicleVisibility` — `app/operations/chronicle_intent_writer.rb:61`
- `ChronicleVisibilityContext` — `app/operations/chronicle_intent_writer.rb:69`
- `ClientChronicle` — `app/jobs/social_audit_delivery_job.rb:77`
- `ClientChronicleEvent` — `app/jobs/social_audit_delivery_job.rb:80`
- `ClientChronicleLevel` — `app/jobs/social_audit_delivery_job.rb:81`
- `OperatorChronicle` — `app/jobs/retention_purge_job.rb:30`
- `OperatorChronicleEvent` — `app/services/operator_secret_credentials_destroy.rb:102`
- `OperatorChronicleLevel` — `app/services/operator_secret_credentials_destroy.rb:103`
- `OrgPreferenceChronicle` — `app/jobs/retention_purge_job.rb:29`
- `OrgPreferenceChronicleEvent` — `app/controllers/concerns/preference_class_registry.rb:83`
- `OrgPreferenceChronicleLevel` — `app/controllers/concerns/preference_class_registry.rb:84`

Model/test-only (3): `ComPreferenceChronicle`, `ComPreferenceChronicleEvent`, `EnforcementEvent`

No static hits (1): `ComPreferenceChronicleLevel`

### `rp_base_app` — ONLY-VIA-MODELS (configured; 13 concrete models)

Abstract base(s): `RpBaseAppRecord`

No concrete model class caller in non-model `app/lib/config` code was found.

Model/test-only (12): `RpBaseAppEventReceipt`, `RpBaseAppIdentityBinding`,
`RpBaseAppOpSessionBinding`, `RpBaseAppPrincipal`, `RpBaseAppSession`, `RpBaseAppSessionSelection`,
`RpStepUpAuditOutbox`, `RpStepUpAuditOutboxAttempt`, `RpStepUpAuditOutboxDeliveryState`,
`RpStepUpState`, `RpStepUpStateStatus`, `RpStepUpStateTransition`

No static hits (1): `RpBaseAppCallbackState`

### `rp_palm_app` — ONLY-VIA-MODELS (configured; 6 concrete models)

Abstract base(s): `RpPalmAppRecord`

No concrete model class caller in non-model `app/lib/config` code was found.

Model/test-only (5): `RpPalmAppEventReceipt`, `RpPalmAppIdentityBinding`,
`RpPalmAppOpSessionBinding`, `RpPalmAppPrincipal`, `RpPalmAppSession`

No static hits (1): `RpPalmAppCallbackState`

### `rp_tech_org` — ONLY-VIA-MODELS (configured; 6 concrete models)

Abstract base(s): `RpTechOrgRecord`

No concrete model class caller in non-model `app/lib/config` code was found.

Model/test-only (5): `RpTechOrgEventReceipt`, `RpTechOrgIdentityBinding`,
`RpTechOrgOpSessionBinding`, `RpTechOrgPrincipal`, `RpTechOrgSession`

No static hits (1): `RpTechOrgCallbackState`

### `app_signal` — USED (configured; 2 concrete models)

Abstract base(s): `AppSignalRecord`

Non-model concrete model references (1):

- `ClientNotificationRecord` — `app/services/retention_cross_database_child_purge.rb:52`

Model/test-only (1): `MemberNotification`

No static hits (0): None.

## Configuration key notes

- `development` configured aliases (including ERB expansion): `app_setting`, `app_setting_replica`,
  `app_signal`, `app_signal_replica`, `app_zenith`, `app_zenith_replica`, `avatar`,
  `avatar_replica`, `chronicle`, `chronicle_replica`, `com_setting`, `com_setting_replica`,
  `occurrence`, `occurrence_replica`, `op_base_app`, `op_base_app_replica`, `op_base_org`,
  `op_base_org_replica`, `org_setting`, `org_setting_replica`, `org_signal`, `org_signal_replica`,
  `org_zenith`, `org_zenith_replica`, `primary`, `publishing`, `publishing_replica`, `queue`,
  `rp_base_app`, `rp_base_org`, `rp_core_app`, `rp_core_org`, `rp_edit_org`, `rp_palm_app`,
  `rp_tech_org`, `rp_warp_app`, `rp_warp_org`, `search`, `search_replica`, `storage`,
  `storage_replica`.
- `test` configured aliases (including ERB expansion): `app_setting`, `app_setting_replica`,
  `app_signal`, `app_signal_replica`, `app_zenith`, `app_zenith_replica`, `avatar`,
  `avatar_replica`, `chronicle`, `chronicle_replica`, `com_setting`, `com_setting_replica`,
  `occurrence`, `occurrence_replica`, `op_base_app`, `op_base_app_replica`, `op_base_org`,
  `op_base_org_replica`, `org_setting`, `org_setting_replica`, `org_signal`, `org_signal_replica`,
  `org_zenith`, `org_zenith_replica`, `primary`, `publishing`, `publishing_replica`, `queue`,
  `rp_base_app`, `rp_base_org`, `rp_core_app`, `rp_core_org`, `rp_edit_org`, `rp_palm_app`,
  `rp_tech_org`, `rp_warp_app`, `rp_warp_org`, `search`, `search_replica`, `storage`,
  `storage_replica`.
- ERB-generated RP write aliases in both development and test: `rp_base_app`, `rp_base_org`,
  `rp_core_app`, `rp_core_org`, `rp_edit_org`, `rp_palm_app`, `rp_tech_org`, `rp_warp_app`,
  `rp_warp_org`; corresponding `_replica` aliases are generated by the paired ERB block.
- `production` is `{}` in this file; there are no explicit per-database aliases under that
  environment block.

Identifier inventory names: `primary`, `publishing`, `app_zenith`, `org_zenith`, `app_setting`,
`com_setting`, `org_setting`, `search`, `op_base_app`, `op_base_org`, `app_signal`, `org_signal`,
`avatar`, `chronicle`, `occurrence`.

## 4. Foreign-looking items retained

- Visa OP/OIDC authorization, token, logout, JWKS, and DBSC paths remain because the user explicitly
  kept the provider surface.
- Cross-repository OIDC client records and their external redirect URI host readers remain per the
  user’s answer. Related client-secret lifecycle and audit code stays with that registry.
- Auth/Visa Jump RT handoff and its public gateway URL remain because the accepted handoff contract
  and active Auth/Visa callers require them. The unsupported private Jump URL was removed from the
  development-container template, including its empty placeholder.
- `BaseOauthTokenEndpoint` and `BaseOauthRevocationEndpoint` concerns remain because Visa app/org
  OAuth controllers include them. The `BaseAuthAdmissionCoordinator` and Base-prefixed step-up
  operations remain because Auth/Visa admission and OIDC flows call them; the names do not identify
  a remaining Base route surface.
- ACME selector/quota helpers remain with Auth social-sign-in and identity-creation callers; no ACME
  route or controller namespace remains.
- Publishing taxonomy value objects remain because retained Publishing model classes reference them.
  Those models are intentionally deferred to the next database/model step.
- Auth and Visa app/org surfaces and their shared controller concerns remain because they are the
  owned authentication and provider boundaries.
- Mission, Flipper, Blazer, PgHero, Coverband, and Swagger host constraints/configuration remain as
  explicitly owned operator tools. A zero route count means the current route invocation did not
  load that optional engine’s routes.
- The hostless `UnknownHostsController` 404 remains to fail closed for unregistered hosts.
- Identity and RP model classes remain untouched by instruction; the database report identifies
  those now reachable only through models/tests. Historical UI-normalization and pre-reset
  architecture records remain explicitly marked as history rather than current surface contracts.
- Operator development hosts retain the existing `*.core.dev.localhost` naming convention because
  the current Mission/Flipper/Blazer/PgHero/Coverband/Swagger host constraints use it; these are
  operator hosts, not a Core application surface.
- The accepted Auth/Visa and external-client ownership record remains because it governs the
  retained OP registration boundary. The separate webmaster-tools note remains as historical
  external provider-registration state, not local Access routing.

## 5. Verification

| Check                                 | Result                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bin/rails zeitwerk:check`            | PASS — eager loading completed, `All is good!`                                                                                                                                                                                                                                                                                                                                           |
| `bin/rails routes`                    | PASS — command exited 0; final route inventory contains 344 entries grouped above                                                                                                                                                                                                                                                                                                        |
| `bundle exec erb_lint --lint-all`     | PASS — 554 ERB files, no errors                                                                                                                                                                                                                                                                                                                                                          |
| `bin/rubocop`                         | FAIL — 3,759 files inspected, 230 offenses; the earlier baseline comparison found no new offense sites (the prior run had 234)                                                                                                                                                                                                                                                           |
| `bin/rails test`                      | FAIL — 12,357 runs, 89,536 assertions, 38 failures, 38 errors, 0 skips                                                                                                                                                                                                                                                                                                                   |
| Focused client-secret audit test      | PASS — 1 run, 5 assertions, 0 failures/errors; the transient pre-restoration failure did not reproduce in isolation or in the final full run                                                                                                                                                                                                                                             |
| Focused TOTP settings controller test | PASS — 21 runs, 344 assertions, 0 failures/errors/skips                                                                                                                                                                                                                                                                                                                                  |
| Focused AWS SNS provider test         | PASS — 6 runs, 14 assertions, 0 failures/errors/skips                                                                                                                                                                                                                                                                                                                                    |
| Focused RI/Vite contracts             | PASS — 14 runs, 153 assertions, 0 failures/errors                                                                                                                                                                                                                                                                                                                                        |
| Focused telephone contract            | PASS — 5 runs, 62 assertions, 0 failures/errors                                                                                                                                                                                                                                                                                                                                          |
| Public ID fixed-length contract       | PASS — 2 runs, 2,969 assertions, 0 failures/errors                                                                                                                                                                                                                                                                                                                                       |
| Architecture baseline refresh         | PASS                                                                                                                                                                                                                                                                                                                                                                                     |
| `git diff --check`                    | FAIL (exit 2) — seven added blank lines at EOF in `gait/components/ui/choice.test.tsx`, `gait/components/ui/links.test.tsx`, `gait/features/auth/passkeys/passkey_panels.test.tsx`, `gait/features/auth/signin/signin_interaction.test.tsx`, `gait/lib/cookies.test.ts`, `src/lib/payload.ts`, and `src/lib/step_up_challenge.ts`; these files were left as found in the shared worktree |

### Full-suite comparison to the saved checkpoint

The saved checkpoint had 12,642 runs, 88,367 assertions, 83 failures, and 115 errors. All 38 failure
identifiers and all 38 error identifiers in the final run matched that checkpoint; 45 prior failure
identifiers and 77 prior error identifiers no longer appeared. Before restoring the owned
credentials, the client-secret audit paging test was the only additional failure identifier; it
passed when isolated and did not recur in the final run. Four additional SNS setup `KeyError`s also
appeared before credential restoration; the final SNS focused run and full suite have no SNS setup
errors. The full-suite failures and errors remaining in the final run are pre-existing checkpoint
identifiers.

No test or lint failure is claimed as passing. The full test suite and RuboCop remain non-green for
the reasons above; the CI workflow variable references are also outstanding because the file is
read-only.
