Task (umaxica-apps-cosmos-access only): reopen the Visa App authorization endpoint
(`GET/POST /oauth/authorize` on `visa.umaxica.app`) so that a valid request from a registered
first-party RP is validated, recorded as an authorization transaction and handed to the Auth App
sign-in entry. The ceremonies themselves stay unavailable; this order ends where the browser reaches
Auth. Visa Org follows in a later order. No commit. Never print secrets, key material, tokens or
environment values. Never edit config/credentials/*.yml.enc. No push, no deploy, no Cloudflare
change, no change outside this repository.

This container sees only this repository. Facts from other repositories are written below under
"Observed on 2026-11-14"; treat them as given and do not look for sibling checkouts. The removed
implementation is in this repository's history: read it with `git show 727cdb560~1:<path>`
(`727cdb560` is the 2026-11-13 checkpoint that replaced the endpoint with
`Visa::App::UnavailableCeremoniesController`).

## Decision

Owner, 2026-11-14: reconnect the Base App relying party now, starting at the authorization endpoint.
This brings forward the Visa App part of stage 3 in `plans/2026-11-12-handoff.md`. Where this order
restores a file that another 2026-11-13 order removed, this order wins for the files it names.

Fixed by the owner on 2026-11-14 (do not reopen):

- Sign-up has no separate RP entry. First-party RPs send no `prompt=create`; Discovery keeps
  `create` in `prompt_values_supported` (`adr/cosmos-base-surface-decomposition.md`, amendment of
  2026-11-14, and `adr/sign-neutral-entry-and-logout-target-authorization.md` decision 1).
- A redirect to a different FQDN goes through Jump, including OIDC redirects. The handoff from Visa
  to Auth therefore leaves through Jump, as the removed code did (`redirect_to_jump_url`).

## Observed on 2026-11-14 (browser and other repositories)

- Governance (Base App, `https://www.umaxica.app`) has restored its RP entry. `POST /sign` answers
  303 to Jump; Jump answers 302 to `https://visa.umaxica.app/oauth/authorize` with the query
  `client_id=base-app-ww`, `code_challenge`, `code_challenge_method=S256`, `nonce`,
  `redirect_uri=https%3A%2F%2Fwww.umaxica.app%2Foidc%2Fcallback`, `response_type=code`, `ri=jp`,
  `scope=openid+profile`, `state` and `rt`. Visa answers 503 ("Service unavailable") today.
- The query carries `rt` (the Jump return token) in addition to the OIDC parameters. Decide from
  `JumpRtReturnVerification` and the removed code how Visa treats it; it must never be taken as an
  OIDC parameter, and a duplicated or unknown OIDC parameter must still be refused.
- Jump is live with PS256 key `jump-prod-2026-11-14-ps256-b9126160`; its JWKS answers 200.
- Governance sends no `prompt`, no `max_age`, no PAR and no `request` object; `state` is a PS256 JWS
  of about 700 characters.

## Boundary

Restore only the Visa App authorization endpoint and what it needs to:

1. enforce request size and rate limits;
2. resolve and validate the request (`OidcAuthorizeRequestResolver`, still present): client, exact
   registered `redirect_uri`, `response_type=code`, scope with `openid`, `state`, `nonce`, PKCE
   `S256`, `prompt`, `max_age`, duplicate parameters;
3. report errors the OAuth way: before the client and `redirect_uri` are trusted, a local error with
   no redirect; after, an error redirect to the registered `redirect_uri` with `state` and `iss`
   (RFC 6749 4.1.2.1, RFC 9207);
4. without an OP session: `prompt=none` returns `login_required` to the RP; otherwise issue the
   authorization transaction and handoff
   (`OidcAuthorizationTransactionCoordinator.issue_with_handoff!`, still present) and send the
   browser through Jump with 303 to the Auth App sign-in sentry (`/sign/in/sentry`), which today
   answers 503 from `Auth::App::UnavailableCeremoniesController`. Keep that 503; reopening Auth is
   not part of this order.

Do not restore: step-up (`step_up_requested`, step-up callback continuation, the step-up
committers), the O9 sensitive-admission dispatch, the authorization result POST and continuation
that finish a ceremony, silent SSO from an existing OP session, the sign-up branch (there is no
sign-up intent from an RP), and any Visa Org file. If the restored `show` needs one of these to
compile, cut the branch and report it; do not leave a stub that pretends to succeed. Stop and report
if any of them turns out to be required for the four steps above.

## Work

1. Inventory before editing. For each item report: present at `727cdb560~1`, present now, and what
   the restored endpoint needs from it. Follow references until the set closes. Starting list:
   - `app/controllers/visa/app/oauth/authorizations_controller.rb`,
     `app/controllers/visa/app/authorization_base_controller.rb` (parent
     `Visa::App::AuthorityController`, still present);
   - concerns `oauth_authorize_rate_limit.rb` (229 lines), `oauth_authorize_request_size_limit.rb`,
     `oidc_authorization_request_errors.rb`, and the parts of `authorization_audit.rb` that record
     an authorization start (authoritative audit events are kept as records, per AGENTS.md);
   - present collaborators: `OidcAuthorizeRequestResolver`,
     `OidcAuthorizationTransactionCoordinator`, `ClientOidcAuthorizationTransaction`,
     `OidcAuthorizationTransactionable`, `OidcPkce`, `OidcClientRegistry`,
     `BaseAuthAdmissionCoordinator`, `JumpRtReturnVerification`, `OpBrowserSessionRequest`;
   - the route in `config/routes/visa.rb` (App block only) and the Auth App sign-in sentry route
     helper used for the handoff URL; the configuration that names the Auth App host (names only).
2. Restore the closed set from history, adapted to the current tree. Change only what the current
   tree or this order requires and give the reason for every deviation from history. Route the App
   `authorization` resource (`show`, `create`) back to `Visa::App::Oauth::AuthorizationsController`;
   leave the Org route on the unavailable controller.
3. Behaviour to keep exactly (`adr/oidc-authorization-request-profile.md`,
   `adr/oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md`,
   `adr/oidc-authn-hardening-implementation-decisions.md`, `adr/rp-oidc-state-and-return-target.md`,
   `project/browser-rp-contract.mdc`): fail closed; `Cache-Control: no-store` and
   `Referrer-Policy: no-referrer` on every response; no token, code, `state`, `nonce`, verifier or
   URL value in logs; the error description for a missing record never names a model or key.
4. Discovery: if `request_parameter_supported`, PAR or any other advertised capability is not
   actually served after this change, report the mismatch; do not change Discovery in this order.

Stop on an item, record the options and continue with the rest when it needs: a schema change or
migration, a new environment variable or credential, an ADR amendment, or a contract that differs
from "Observed on 2026-11-14".

## Tests (Red first)

Restore from history and adapt: `test/integration/visa_authorization_start_boundary_test.rb`,
`oidc_authorization_parameter_multiplicity_test.rb`,
`acceptance_wu13_authorize_unrelated_params_test.rb`,
`test/services/oidc/authorize_service_test.rb`, `oidc_authorization_transaction_service_test.rb`.
Update `test/controllers/visa/ceremony_unavailable_test.rb` so it no longer expects 503 from the App
authorize route (the Org route and the Auth ceremonies still answer 503).

Cover at least, for `base-app-ww`: the exact request Governance sends (parameters above plus `rt`)
answers 303 through Jump to the Auth App sign-in sentry and creates one transaction; unknown client;
unregistered or near-miss `redirect_uri` (no redirect, local error); `response_type` other than
`code`; scope without `openid`; missing `state`; missing `nonce`; missing or non-`S256` PKCE;
duplicated parameter; `prompt=none` without an OP session (error redirect `login_required` with
`state` and `iss`); `prompt=create` and `prompt=login` accepted and recorded; oversize request; rate
limit; an Org client on the App endpoint refused; the Org endpoint still 503. Boundaries per
AGENTS.md (below, at and above the size limit). No mocked resolver or coordinator; no test-only
branch in production code; no placeholder or skipped test.

## Checks and report

bin/rails zeitwerk:check, bin/rails routes (Visa App block), bin/rubocop, bundle exec erb_lint
--lint-all, bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error, bun run check, the
restored and changed test files, then bin/rails test (separate pre-existing failures; latest full
run in `evidence/2026-11-13-access-ps256-workorder-recheck-E6N4.md`). If test boot refuses because
`POSTGRESQL_TEST_PREPARE_DATABASES` lists databases that no longer exist, run with that variable
unset as the earlier evidence did, and report the stale list as a follow-up. Add no new static-check
offense. Update `README.md`, `plans/2026-11-12-handoff.md`, affected `docs/mermaid` diagrams and
checklists in the same change.

Record in evidence/YYYY-MM-DD-visa-app-authorization-reopening-XXXX.md (full `git rev-parse HEAD`;
uncommitted changes affected results): the inventory; files restored and each deviation with its
reason; branches cut and why; test results; items stopped for the owner; what a browser check from
`https://www.umaxica.app/sign` should now show (Visa answers 303 through Jump, the browser ends on
`auth.umaxica.app/sign/in/sentry` with 503) and what fails until Auth reopens; and confirmation that
config/credentials files are unchanged.
