# Preference Architecture

> **Current scope (2026-11-10):** Access serves Auth APP/ORG, Visa APP/ORG, and its operator tools.
> This document preserves preference model, database, and protocol history. Its former Base, COM,
> Core, Warp, Palm, Edit, and Tech route/writer assignments are retired and do not establish current
> local routes or writers. Do not drop the retained models or migrations as part of this route
> cleanup; the separate model/database report will classify their remaining callers and ownership.
> Use the live route and controller inventory to determine which Auth/Visa preference endpoints and
> writers remain active.

## Purpose

The preference system has two different roles.

- `AppPreference`, `OrgPreference`, and `ComPreference` hold login-independent surface setting
  state.
- `ClientPreference` and `OperatorPreference` hold per-account local settings for app and org. Com
  has no account-local preference.

The system must keep these roles separate.

The database is the source of truth for both shared and local preference state. The Preference JWT
is a signed projection of that database state for runtime reads. Auth access tokens do not carry the
`prf` preference snapshot.

## JWT Projection Boundary

The retained Preference transport history uses one realm-scoped signed value and two display
cookies. App, org, and com had a shared anonymous token contract. Base save/reset and Visa
sign-in/sign-out reflection describe the earlier route ownership; current local writer ownership is
determined by the Auth/Visa route and caller inventory. WU-9's shape cutover was recorded for the
local development/test databases; this route cleanup does not alter that model history.

| Data         | JWT projection                 | Accepted target contract                                                                                                                             |
| ------------ | ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Preference   | Preference JWT only            | App, org, and com use a realm-scoped `__Secure-preference`, `language`, and `__Secure-experience` cookie set. Auth access tokens do not carry `prf`. |
| Identity     | Auth/OIDC identity claims only | Credential, contact, verification, and lifecycle state remain DB-only.                                                                               |
| Avatar       | None                           | Avatar selection and authority remain DB-only/session-row state.                                                                                     |
| Organization | None                           | Organization membership and role checks remain DB-only policy state.                                                                                 |
| Group        | None                           | Group membership and authorization remain DB-only policy state.                                                                                      |

OIDC ID token claims and auth access token claims are separate contracts. An ID token may describe
the authenticated subject for an RP. An auth access token may carry authentication/session facts for
the Rails authorization boundary. Neither token turns identity, avatar, organization, or group rows
into JWT-owned source-of-truth state.

Preference authority and preference transport are separate. The earlier contract assigned writes to
matching Base and Visa surfaces and assigned the host-only `__Host-preference_binding` cookie to
Base. Those ownership statements are retained history, not a current local route map. A signed JWT
by itself is not consent authority. Runtime consumers that remain use display state as read-only
context through `Actor.preferences`.

## URL Role Boundary

Preference, setting, and operational configuration routes have separate responsibilities:

- `/preference` is the login-independent preference boundary. It may be used before login, after
  logout, or while authenticated. It owns shared surface preference state such as language, region,
  timezone, theme, display options, and cookie consent.
- `/setting` is the signed-in user setting boundary. It owns account-local and security settings for
  the current actor, such as credentials, sessions, MFA, contact methods, notification settings, and
  withdrawal flows.
- `/configurator` is the generic operator-controlled configuration boundary. It owns settings an
  authorized operator manages for an organization, workspace, tenant, public surface, or managed
  runtime.

Earlier Base ORG `/settings`, Auth ORG `/settings`, Base ORG Entra display, and Auth ORG
`/configuration` migration decisions are historical. The hard reset removes the foreign Base route
ownership; current Auth/Visa route availability must be read from the live route inventory. Matching
path text never shares an implementation, and user settings remain distinct from operator-managed
configuration.

Do not move preference writes under `/setting` merely because the actor is authenticated. Do not
expose account settings through `/preference` merely because a settings page also displays
preference context. Do not mix operator-managed configuration with user self-service settings.

These URL roles remain design guidance for new documentation. Do not infer current routability from
the older Base/Auth examples or from repeated `/settings` path text.

## Scope

### Shared preference

Shared preference is the source of truth for login-independent surface preference state.

- It belongs to the `App` / `Org` / `Com` surfaces.
- It stores the current token-like preference state.
- It is used before login and after logout.
- It lives in `app_setting`, `org_setting`, or `com_setting`.

### Local preference

Local preference is the source of truth for account-local settings.

- It belongs to `Client` or `Operator` records. Corporate (`com`) has no account-local preference.
- It stores per-account language, region, timezone, and theme settings.
- It is kept in each domain database.

## Synchronization Rules

The accepted target is one-way and field-explicit. The replacement
[sign-in application ADR](../../adr/preference-sign-in-application-is-one-directional.md) and
[realm JWT and binding ADR](../../adr/preference-realm-jwt-and-host-bound-browser-binding.md)
supersede the older record-recency and host-local transport contracts. App/org and com now use the
same realm JWT and Base host binding rules.

### Before login

- Anonymous preference writes target the matching `AppPreference`, `OrgPreference`, or
  `ComPreference` row.
- Account-local values are not written by anonymous save paths.

### During login

- After Visa has finalized sign-in, its shared Preference writer applies only account display values
  named in the account row's explicit metadata to the anonymous row. The anonymous row never writes
  back to the account. An account row with `explicit_fields IS NULL` has unknown historical
  provenance: it remains unchanged and supplies no inferred values.
- `region` is not applied by itself. A region save marks the fixed language, date format, time
  format, and currency companions explicit; those companions are the values applied on sign-in.
- Consent, Web Push, and browser binding remain browser-local. Sign-in does not import them from the
  account. Corporate preferences have no account adoption path.

The Visa authorization-result GET is a read-only display step. It validates the browser binding,
transaction and result reference, then renders a same-origin POST continuation. Only that POST
revalidates and finalizes the result, applies the actor's explicit Preference fields, and issues the
authorization code. Continuations are purpose-bound and expire within 60 seconds or at the parent
transaction deadline, whichever comes first. Rails CSRF and Origin/Fetch Metadata validation remain
required.

### During logout

After authentication logout commits, Visa sign-out asks the shared Preference writer to create a new
anonymous generation, copy display values plus consent, Web Push option, and the binding record from
the old row's database state, and retire the old row in one setting transaction. It does not infer
Preference state from cookies. Account-local settings remain in place.

### Sync failure handling

The target writer follows the ordered Z-then-setting commits and explicit failure outcomes in
`two.md` §4.4 and §4.8. An account save that commits in Z but fails in the setting database is a
visible partial failure; it is not reported as saved. A sign-out remains complete when the
independent Preference rebuild fails, and the failure is reported without claiming that the new
Preference cookie reached the browser.

## Write Boundary

The earlier `PreferenceWriteBoundary#write_preference!` contract centralized `save`, `sign_in`,
`sign_out`, and `reset`, with Base and Visa as named writers. Treat those route assignments and the
former COM mapping as historical until a remaining Auth/Visa caller establishes current ownership.
Any writer that remains must receive a server-verified actor and explicit submitted values; request
data cannot choose the actor, realm, or operation, and the surface-to-realm map must stay closed.

## Data Sharing Rules

`App`, `Org`, and `Com` preference data remain separate realm-local state.

- Do not copy `App` data into `Org` or `Com`.
- Do not copy `Org` data into `App` or `Com`.
- Do not copy `Com` data into `App` or `Org`.

Account-local preference records also remain isolated inside their matching principal boundary.
`ClientPreference` uses the app Zenith database; `OperatorPreference` uses the org Zenith database.
There is no corporate account-local preference.

## Shared Fields

The anonymous display snapshot supports these ten fields:

- `theme`
- `language`
- `timezone`
- `currency`
- `date_format`
- `time_format`
- `motion`
- `density`
- `page_size` (including the registered `infinity` value)
- `region`

`region` is stored in the database but is not a JWT display claim. A region save also marks its four
fixed display companions explicit. The shared cookie projection carries language and the experience
object with the other display values. Consent, Web Push option, and browser binding are stored in
separate browser-row children; they are not account-local fields. `adult_content_gate` remains a
dormant model/option/child family and is excluded from runtime display and save registries.

## Anonymous Preference Retention

The public `PreferenceLifecycleJob` processes anonymous APP, ORG, and COM Preference rows in batches
of 200. A row becomes eligible only after its owner database reports that the last issued JWT expiry
plus the 30-day retention period has elapsed. The job rechecks that deadline under the owner-row
lock, then deletes dependent children and the parent in one owner-database transaction. Preference
chronicle rows retain their referenced parent: the job takes an exclusive Chronicle advisory lock
and checks matching typed subject and actor references before deleting. A chronicle with a different
`subject_type` that happens to reuse the same numeric ID remains independent and does not retain or
get deleted with the Preference row. Chronicle writers take the matching shared lock and validate
new or changed Preference references before committing them. The job leaves audited rows in place
and can safely retry a row after a failed transaction.

## Promotional Email Unsubscribe

The former Base `/preference/email/:id` opt-out routes are retired with the Base surface. They are
not current Access public endpoints. Any retained unsubscribe models, services, or data remain
subject to the separate model/database report; this section does not establish an active writer.

- authentication secrets
- identity documents
- billing data
- moderation data
- message content
- operational audit payloads

## Request Context Parameters

The historical app/org/com sign surfaces used the request context contract below. Current Auth and
Visa paths must follow their retained controller and route behavior; old Base and COM examples do
not establish current endpoints.

- `ri` carries the region.
- `lx` carries the language.
- `ct` carries the theme.
- `tz` carries the timezone.
- `cu`, `df`, `tf`, `mo`, `dn`, and `ps` carry optional display and locale-adjacent overlays.
- `pt` and `nt` carry redirect target lanes and are not propagated through ordinary preference
  navigation by default.

`ri` was mandatory request context for the documented sign `app` and `org` routes and anonymous
`com` preference pages. If `ri` is missing or invalid on a GET or HEAD request, the controller
redirects to the same route with a valid `ri` value. `ri` is request context, not a preference write
path.

The former global browser HTML contract covered Base, Auth, Tech and Edit, including Base
Home/Dashboard. Those foreign-surface route statements are retired. Under that contract, a missing
region used the existing resolved context, defaulting to `jp`; explicit valid `jp` and `us` stayed
selected, and valid query context survived a same-origin, same-path 302 redirect. Current Auth/Visa
paths must follow their surviving controller behavior. Protocol, JSON, metadata, and health
endpoints retain their transport exemptions where implemented.

`lx`, `ct`, `tz`, `cu`, `df`, `tf`, `mo`, `dn`, and `ps` are optional request context. They are only
propagated when explicitly present and valid. The runtime preference subset may override the current
request's locale, theme, timezone, display reflection, or content-gating reflection by applying a
request-local overlay to `Actor.preferences`, but these parameters do not update the database or
preference access-token JWT. If they are missing, Rails request code should read the already
resolved value from `Actor.preferences`, without adding those optional keys back to generated URLs.
On GET and HEAD requests, invalid or blank optional context parameters are removed from the query
string by redirect.

Supported optional request values:

- `lx`: `ja`, `en`
- `ct`: `li`, `dr`, `sy`, or their long forms `light`, `dark`, `system`
- `tz`: `utc`, `etc/utc`, `asia/tokyo`
- `tf`: `12`, `24`, or their long forms `hour_12`, `hour_24`
- `mo`: `st`, `rd`, or their long forms `standard`, `reduced`
- `dn`: `st`, `cp`, or their long forms `standard`, `compact`
- `ps`: valid page size option values

## Public And Private URL Boundaries

Preference token validation is sensitive to the difference between a browser-visible host and an
internal Rails origin.

- `PUBLIC_` should be used for the host or URL the browser sees.
- `PRIVATE_` should be used for the host or URL Rails or a pod uses internally.

The Preference JWT cookie path must keep these boundaries aligned. If Rails issues a token for one
boundary and immediately validates against the other, the browser can end up with a freshly issued
cookie that is then deleted on the same response.

Examples:

- `/preference?ri=jp&lx=en` uses English for that request.
- `/preference?ri=jp&lx=kr` redirects to `/preference?ri=jp`.
- `/preference?ri=jp&ct=purple&tz=Mars/Base` redirects to `/preference?ri=jp`.
- `/preference` redirects to the same route with a valid `ri`, but does not add `lx`, `ct`, or `tz`.

## Preference Reset

The former Base reset transition retired the currently valid anonymous row and created a new row
with its registered defaults in the same setting-database transaction. After commit, the writer
issues the three shared Preference cookies from that new snapshot and deletes the old host-only
browser binding cookie. If the supplied JWT is invalid, the row it names stays unchanged; reset
creates a default row instead. The new contract does not return to the refresh/DBSC path.

That Base route is retired. The row lifecycle and cookie details remain as schema/transition
history; current Auth/Visa writer ownership is determined from surviving callers.

## Runtime Read Contract

The read-only runtime projection is a domain-scoped Preference JWT. App/org and com hydrate through
the same realm claim shape:

```text
Preference JWT payload (`__Secure-preference`) -> Actor.preferences
```

The anonymous Preference JWT uses the closed realm shape defined by the accepted Preference ADRs.
Its `sub` identifies the anonymous preference row; `aud` identifies the realm. It is separate from
the RFC 9068 authentication access token.

The database is the durable storage boundary used by explicit Preference writes. The signed
Preference JWT is a runtime read cache. `Actor.preferences` is the immutable request-local
preference value exposed to controllers, views, and services. Preference JWT refresh-token and DBSC
flows are retired.

The `prf` claim is not a Preference source. `Actor.preferences` is hydrated from the verified
Preference JWT by `set_preferences_cookie` before `set_current_actor`; that hydration itself does
not query the database. The former Base runtime could separately read the active anonymous row and
explicit actor fields to rebuild missing or mismatched display cookies. That read did not issue or
extend a JWT or update persisted Preference state.

In a normal app/org request, `Actor.preferences` is built in two stages:

1. Build the base preference from the Preference JWT payload (`preference_payload_preferences`), via
   `Actor::Preference.from_jwt`. When no Preference JWT cookie exists (Bearer/OIDC APIs and
   endpoints that skip `set_preferences_cookie`), fall back to the default preference values (theme
   `sy`). `Actor::Preference::NULL` is the unbound-context snapshot, not the guest default.
2. Overlay supported request-local context values, including `ri`, `lx`, `ct`, and `tz`, when they
   were explicitly present in the request.

The overlay changes only the current request's runtime preference. It is not a preference write.

### Historical anonymous corporate request projection

The corporate (`com`) hosts have no principal, credential, session, or admission boundary, so their
hydration is a separate path:

1. `ComAnonymousActorContext#set_anonymous_context` installs one request-local actor snapshot with
   `Unauthenticated`, `Actor::Authentication::NULL`, `Actor::Authz::NULL`,
   `Actor::Configuration::NULL`, and `Actor::SelectedContext::NULL`.
2. The initial preference starts from `Actor::Preference.new` and the request overlay. After token
   verification, a valid com JWT supplies the display values and the request overlay is applied to
   the request-local snapshot. With no valid JWT, the initial default and overlay remain in use.
3. `prepend_around_action :with_anonymous_context_lifecycle` clears the actor snapshot and restores
   the thread's time zone when the request ends.

`Base::Com::ApplicationController` and `Warp::Com::ApplicationController` include the concern
explicitly and do not include the principal-resolving authentication or adoption concerns. Warp com
verifies the JWT without reading the setting database. Base app, org, and com HTML GET/HEAD requests
may project the active anonymous row's region into `Actor.preferences`; an explicit URL region
overlays it for the request. Base also projects consent and Web Push into `Actor.preferences` only
when the active row, unexpired realm JWT, receipt (for consent), and host-only browser binding
authorize that browser. Consent version and decision time come from the matching receipt. A missing
or mismatched binding yields declined consent and disabled Web Push. The Base browser API returns
its state in the endpoint response and does not mutate the request Actor. Warp com and other
non-Base hosts do not read the setting database and retain the disabled Web Push default. Projection
read failures are logged and leave the Actor's safe browser defaults in place. The independent com
signing namespace and lifecycle schema are present locally; deployment key distribution and full
WU-7 acceptance remain unverified.

### Language resolution and regional defaults

The anonymous JWT stores language as a display value and has no explicitness marker. Request context
is applied locally in this order:

1. `?lx` request param (request-local; never written to DB/JWT).
2. `?ri` regional locale (`jp` -> ja, `us` -> en).
3. Language from the verified Preference JWT.
4. Default (`ja`).

Example:

```text
Preference JWT: lx=ja, ct=sy, tz=Asia/Tokyo
request params:   lx=en
Actor.preferences: language=en, theme=sy, timezone=Asia/Tokyo
```

The page renders in English for that request. The database and Preference JWT remain Japanese until
an explicit preference write changes them and reissues a token.

### Region is a regional-bundle reset

A `/preference/region` write is not a single-field write. It rewrites the region-owned locale
defaults to the region's values in one transaction. For a signed-in actor, it marks the region and
its four companion values explicit in the actor-local preference metadata:

| Region | language | date format        | clock | currency |
| ------ | -------- | ------------------ | ----- | -------- |
| `jp`   | `ja`     | `iso` (YYYY-MM-DD) | 24h   | `jpy`    |
| `us`   | `en`     | `us` (MM/DD/YYYY)  | 12h   | `usd`    |

The individual language / calendar / clock / currency screens still let a person override any of
these afterwards. A later request-region overlay affects only that request. If any of the five child
writes fails, the whole preference update reports failure rather than claiming the bundle was saved.

Do not reverse this flow.

- Do not issue preference JWTs from `Actor.preferences`.
- Do not write the database from `Actor.preferences`.
- Do not read JS-readable preference cookies as Rails runtime input.
- Do not treat request context params as preference writes.
- Do not copy request-local `lx`, `ct`, or `tz` overlays back to the database or JWT.

The former `acme` and `jump` runtime readers were not preference writers. They must not be treated
as current Access surfaces or callers after the reset.

The current readable display cookies are `language` and `__Secure-experience`. Rails derives both
from the same verified database snapshot as the Preference JWT. Per-item cookies such as `ct` and
`tz` are retired; Rails request code does not trust readable display cookies as preference input.

The prior write contract allowed database writes only in bounded flows:

- explicit Base Preference save and reset (retired with Base routes)
- Visa sign-in application after the authenticated transaction is finalized, if a current caller
  remains
- Visa sign-out rebuilding after authentication logout commits, if a current caller remains
- no other host, endpoint, or maintenance path writes Preference state

GET and HEAD do not create, update, or refresh Preference rows. Preference reads are limited to
verified JWT state and bounded database reads such as the former Base consent/binding checks.

Normal request setup must not recover a missing, broken, or malformed Preference JWT by reading the
Preference database. Writes start a default row when the supplied JWT does not identify a current
row; GET/HEAD do not issue a replacement token.

The earlier authenticated preference screens resolved the verified anonymous JWT and actor context
like other Base requests. A screen read never copied actor values into the anonymous row. An
explicit save updated only submitted actor fields and the browser snapshot. Base route ownership is
retired; use current Auth/Visa callers to establish any surviving screen behavior.

## Implementation Notes

- `PreferenceClassRegistry` names the registered realm and account classes. New code uses the
  registry's static class maps and fails on an unknown prefix.
- `PreferenceWriteBoundary#write_preference!` records the earlier shared write entrance for `save`,
  `sign_in`, `sign_out`, and `reset`. Base ownership is retired; only callers that remain under
  Auth/Visa are current writers.
- `ActorPreferenceExplicitDisplay#explicit_values` reads only explicitly named display children. An
  old actor row whose `explicit_fields` is `NULL` remains historical and read-only; it cannot supply
  a snapshot, and child values do not establish explicit intent. The approved shape requires this
  field to be NOT NULL. `region` and dormant `adult_content_gate` are not transferred by Visa
  sign-in.
- App/org setting databases have consent receipt, browser binding, and Web Push option child tables.
  Visa sign-out copies those records only from the source row in the matching setting transaction.
- App/org Preference adoption, refresh, DBSC, assurance, and item-cookie paths are retired.
- The accepted anonymous JWT projection is the closed display snapshot, with `language` and
  `__Secure-experience` generated from one database snapshot. The registered page-size value
  `infinity` remains valid. Unknown option names and keys fail instead of acquiring aliases.
- `adult_content_gate` models, options, and child tables remain dormant. Its controller/runtime
  registry references have been removed while the model-layer tables remain.
- Runtime readers consume verified preference context through `Actor.preferences`. Request-local
  region/language/theme/timezone overlays do not become writes.
- The accepted ADRs are indexed in `adr/README.md`. The older record-recency and host-local
  transport ADRs are historical and must not be reinstated as the current contract.

## Remaining Follow-ups

- Classify retained Preference models, writers, and databases in the separate model/database report.
- Reconcile current Auth/Visa callers with the historical WU-7/WU-9 schema and transition records.
- Keep existing database checkpoints and snapshots available for recovery; this route cleanup does
  not drop databases or rewrite persisted history.

## Open Questions

The accepted preference transport and sign-in decisions remain recorded in the linked plan and
evidence. Current route/writer ownership and the fate of retained Base/COM preference data remain
open for the separate model/database report; no model or database removal is authorized here.
