# Email Subscription Feature: Retire for COM and Org, Re-check for App (2026-11-11)

Owner: Access. Status: decided (owner) for COM and Org; App needs a fresh check. Nothing is
implemented.

## Decision (owner, 2026-11-11)

- **COM: retire.** Any email-subscription or promotional-mail capability that existed for COM is
  removed with the rest of COM.
- **Org: not needed.** Org is for staff; subscription preferences are not wanted there.
- **App: check again** before deciding. The App behavior below is recorded as observed, not as a
  decision.

## Observed on 2026-11-11 (code reading only; nothing run)

- Outbound email stops through the Flipper switch `outbound_email_suspended`
  (`app/services/outbound_channel_suspension.rb`,
  `app/mailers/outbound_email_suspension_interceptor.rb`). It stops all mail, OTP included, not
  subscriptions alone.
- Access sends only OTP mail: `Email::App::OtpMailer` and `Email::Org::OtpMailer`. No promotional
  mailer exists in code (`docs/dds.md` still lists `PromotionalMailer`).
  `research/implementation/2026-11-09-access-route-separation.md` records that no production
  promotional sender was found and that unsubscribe handling was removed from Access mailers.
- Preference columns `promotional`, `notifiable` and `subscribable`, all `DEFAULT true`, exist in
  `user_emails` (App, `db/app_zenith_structure.sql`) and `staff_emails` (Org,
  `db/org_zenith_structure.sql`), modelled by `ClientEmail` and `OperatorEmail`
  (`promotional_unsubscribe_scope`, `subscription_preferences_locked?`).
- App sign-up collects `promotional` and `notifiable`
  (`app/controllers/auth/app/sign/up/emails_controller.rb`, around lines 23, 90 and 233 to 240).
- `IdentityEmailPreferenceCommitter` (step-up-gated preference change) is called only by tests; no
  settings screen in Access reaches it (`app/controllers/auth/app/settings/` holds Apple, Google and
  TOTP only).
- `PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT` is named in
  `docs/backlog/2026-11-10-secrets-from-credentials-only.md`; no code in `app/`, `lib/` or `config/`
  reads it.
- COM leftovers still present in code: the `ComPreference*` model family under `app/models/`
  (preference, chronicle, options, web push, timezone and others), and `Email::Com` /
  `PromotionalMailer` references in `docs/dds.md`.

## Work

### COM (retire)

1. Inventory every COM email-subscription trace: models, tables, jobs, mailers, locales, documents
   and diagrams (start with the `ComPreference*` models and `docs/dds.md`).
2. Remove them, with their tests and the references in current documents. Decide table drops under
   the hard-reset policy (development data may be destroyed with approval at execution time).

### Org (not needed)

1. Remove `promotional`, `notifiable` and `subscribable` from `staff_emails`, the `OperatorEmail`
   methods and tests that exist only for them, and any Org copy.
2. If staff need a delivery switch for operational mail, that is a separate decision.

### App (re-check, then decide)

Questions to settle first:

1. Is there any planned sender of promotional or notification mail, and from which repository?
   Access is an OpenID Provider only (`adr/access-is-a-pure-openid-provider.md`: notifications and
   preferences live in Governance), so Access probably should not hold these columns or collect them
   at sign-up.
2. If subscription preferences stay: where is the source of truth (Governance), what is the legal
   basis for promotional mail (consent must be an explicit opt-in, not a default of true; confirm
   the sign-up checkbox is not pre-selected), and how does a person unsubscribe (a working path that
   needs no sign-in).
3. If they go: remove the sign-up fields, the columns, `IdentityEmailPreferenceCommitter`, the
   unsubscribe scope and the unused secret name above.

Record the result in `evidence/` and update this entry.
