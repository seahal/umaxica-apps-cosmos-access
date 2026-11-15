Task (umaxica-apps-cosmos-access only): reopen the Auth sign-in ceremonies for App and Org so that a
browser handed over by Visa can complete sign-in and return to Visa, which then issues the
front-channel ID Token. No commit. Never print secrets, key material, tokens or environment values.
Never edit config/credentials/*.yml.enc. No push, no deploy, no Cloudflare change, no change outside
this repository.

## Prerequisite

`plans/2026-11-14-front-channel-id-token-sign-in-work-order.md` must be finished first (Visa accepts
`response_type=id_token` for `base-app-ww` and `base-org-ww`, issues the ID Token, and the sign-in
lookup contract exists). If its evidence is missing, or it stopped on the lookup contract, stop and
report; do not build ceremonies on a guessed contract.

## Decision (owner; do not reopen)

- During sign-up and sign-in, no server-side call between applications except JWKS reads
  (`adr/access-is-a-pure-openid-provider.md` decision 18 (e)). Everything Auth needs from Governance
  arrives by the browser handoff defined in the lookup contract.
- Every redirect to a different FQDN goes through Jump (edges `auth-*-ww` <-> `visa-*`, `base-*`
  already exist).
- Terminology (`adr/sign-flow-terminology.md`, accepted 2026-11-14): code restored now uses the new
  names, not the old ones then renamed (rule 4): `ingress` (old `sentry` entry and sign-up `guard`),
  `availability` (old `sentry` switch; Flipper keys `sign_in_available_app|org` unchanged),
  `eligibility` (old `guardrail`), `requirements` (old `checkpoint`). Stored integer state codes and
  Flipper keys do not change. No aliases for old paths. This absorbs the sign-in part of
  `plans/backlog/2026-11-14-sign-flow-terminology-rename-work-order.md`; leave its sign-up part.
- Scope: sign-in only, App and Org. Sign-up stays closed (503) until Governance's pending
  registration design exists. Sign-out, settings, social linking and verification screens stay as
  they are unless sign-in cannot work without one; report each one you needed.

## Observed on 2026-11-15

- Commit `727cdb560` (HEAD) removed about 90 controllers and 800 `app/` files; the last tree that
  has them is `f84c87b060876a25994e30e9274420d9067f1367`. Removed sign-in controllers under
  `app/controllers/auth/{app,org}/` include `sign/ins`, `sign/in/sentries`, `sign/in/challenges`,
  `sign/in/checks`, `sign/in/emails`, `sign/in/passkeys`, `sign/in/passkey/options`,
  `sign/in/secrets`, `sign/switches`, `sign/cancellations`, `sign/oidc_handoffs`,
  `ceremony_bindings`, and the realm `application_controller`s.
- About 93 route entries point at `UnavailableCeremoniesController` (503).
- The browser entry from Visa lands on `/sign/in/sentry` today; it becomes `/sign/in/ingress`. Visa
  builds that URL from the route helper, so rename the helper and its caller together.

## Work

1. Inventory the removed sign-in code at `f84c87b06`: controllers, services, models, views, locales,
   tests, routes. Classify each: needed for sign-in now / sign-up only / other (leave). Mark any
   piece that made a server-side call to Governance; it must use the lookup contract instead, or
   stay out.
2. Restore the "needed now" set under the new names, for App and Org through shared concerns where
   the old code already shared them. Remove the matching routes from
   `UnavailableCeremoniesController`; sign-up and other routes keep pointing at it.
3. Ingress: `resource :ingress, only: :show` under `sign/in`; it checks availability and the Visa
   handoff, then sends the browser to the first requirement. Availability off answers the existing
   503 page.
4. Completion: when requirements and eligibility pass, Auth hands the result back to Visa through
   Jump (existing handoff; PS256), and Visa continues the authorization transaction to the
   front-channel ID Token. No server-side call in either direction.
5. Keep security order exactly as the old code had it (rate limits, Turnstile, CSRF, binding of the
   handoff to the browser, passkey and passcode checks). Report any check you could not restore.

Stop on an item and continue with the rest when it needs a schema change you cannot make reversibly,
a new environment variable or credential, or a contract that differs from the ADRs.

## Tests (Red first)

For both realms, through public endpoints without mocking the ceremony: Visa handoff -> ingress ->
each requirement -> hand-back -> Visa issues the ID Token (303 through Jump to the Base callback);
availability off -> 503; invalid, expired or replayed handoff refused; ineligible account refused;
old paths (`/sign/in/sentry`, `checkpoint`, `guardrail`) are 404; sign-up still 503; rate limits and
Turnstile at their boundaries. Static guard: no HTTP client reachable from sign-in controllers and
services except the JWKS client.

## Checks and report

bin/rails zeitwerk:check, bin/rubocop, bundle exec erb_lint --lint-all, bin/brakeman --quiet
--no-pager --exit-on-warn --exit-on-error, bundle exec database_consistency, bun run check, the
changed tests, then bin/rails test (unset `POSTGRESQL_TEST_PREPARE_DATABASES` if its stale list
blocks boot). Update README, docs/mermaid sign-in diagrams and inventories, checklists.

Evidence: `evidence/YYYY-MM-DD-auth-sign-in-ceremony-restoration-XXXX.md` (full
`git rev-parse HEAD`): inventory and classification, restored and left-out pieces, renamed
identifiers, routes still on 503, test results, the browser path expected end to end, owner items,
confirmation that config/credentials files are unchanged.
