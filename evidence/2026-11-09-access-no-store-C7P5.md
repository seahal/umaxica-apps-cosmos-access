# Access personal-response cache enforcement

Executed 2026-11-09 UTC against full HEAD `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. Extensive
pre-existing uncommitted changes affect these results and were preserved. This task adds the
middleware and two test files named below, adds its require/wiring to the already-modified
application configuration, and appends an implementation explanation to the already-amended identity
navigation ADR. No commit was made.

## Result

Implemented backlog item 3 from `docs/backlog/2026-11-10-access-acceptance-gaps.md` without changing
admission, authentication, authorization, CSRF, rate limits or controller execution order.

`lib/access_personal_response_cache_control.rb` enforces `private, no-store` on the final response
for these host-owned paths, regardless of response status:

- Auth App: settings and nested settings paths; Google and Apple callback paths.
- Auth Org: Entra callback paths.
- Visa App and Org: the OAuth authorization path.

Configured boot hosts, explicitly configured public aliases and the corresponding existing local
route aliases form immutable per-realm host sets. The middleware observes the host after the
existing trusted-forwarded-header filter has processed the request. It snapshots the original path
before the downstream call because ShowExceptions rewrites the path while rendering an error. It
changes only Cache-Control, preserves status/body/other headers, and does not mutate downstream
header hashes. It has no persistence, network, logging or authentication behavior.

Wiring in `config/application.rb` places it outside exception rendering and OmniAuth, so framework
422 responses, before-action refusals and provider-middleware redirects all retain the policy. The
amended `adr/cosmos-identity-without-inertia.md` documents this final enforcement. Public JWKS,
Discovery, robots, sitemap, health and revision paths are outside its scope and retain their
existing policy. Other hosts and adjacent similarly named paths remain outside the boundary.

## Verification

Command:

`PARALLEL_WORKERS=1 OTEL_SDK_DISABLED=true bin/rails test  test/integration/access_personal_response_cache_control_test.rb  test/lib/access_personal_response_cache_control_test.rb`

Initial complete result: **9 runs, 153 assertions, 0 failures, 0 errors, 0 skips**. The final
normalized-path verification below supersedes that assertion count.

Observed through public HTTP interfaces:

- All five reported anonymous Auth App settings paths returned their existing admission refusal and
  `private, no-store` when a valid region context was supplied.
- Google, Apple and Entra callback GET and POST refusals passed through the real OmniAuth middleware
  stack and retained `private, no-store`. The provider boundary used OmniAuth's mock-auth failure
  mode; no provider endpoint was called and no successful social login is claimed.
- Enabling the existing real CSRF protection for the duration of the test and sending a POST without
  a token produced HTTP 422 on both Visa authorization endpoints, with `private, no-store`. The test
  restored the prior protection settings afterward; no implementation bypass was added.
- JWKS responses on all four Auth/Visa hosts remained successful and free of no-store. Discovery on
  both Visa hosts remained successful and did not receive the personal cache policy.

Public middleware-call tests additionally cover success, redirects, client/server failures;
header/body preservation and frozen downstream headers; format suffixes/trailing slashes; public
resources and wrong-realm/unknown-host/adjacent-path exclusions; framework status-path rewriting;
and four trusted/untrusted forwarded-host permutations composed with the actual
`TrustedForwardedHeaders` implementation.

Scoped `bin/rubocop` across the middleware, its two tests and application configuration passed: **4
files inspected, no offenses detected**. Initial formatting findings were corrected. Scoped
`git diff --check` passed. Initial integration expectations were corrected to include the region
context; the application was not altered to satisfy that expectation. Initial provider probes were
blocked by the suite's outbound guard before network transport; the final hermetic provider-boundary
configuration described above replaced those probes.

## Limits and preserved state

No development database was written, reset or rebuilt; only normal test-environment verification
ran. No external service or credentials payload was changed. Keys, tokens, cookies, personal data,
request/response bodies and raw callback/redirect values are absent from this evidence. The
protected pre-existing comments, message-pack settings and unrelated documentation additions were
preserved. Container/browser back-forward behavior and completed authenticated ceremonies were not
verified by this task. The parent task runs the combined security gate separately.

## Final path-equivalence check

A targeted public-request probe compared canonical controls with the literal escaped paths
`/%73ettings`, `/social/%67oogle/callback` and `/oauth/%61uthorize`. The three escaped paths all
returned 404 with no recognized controller; their canonical controls reached the expected personal
settings/refusal/callback responses. No percent-decoding was added.

The installed Rails RouteSet normalizes repeated/trailing slashes through
`ActionDispatch::Journey::Router::Utils.normalize_path`, without decoding escaped path segments. A
public probe confirmed a reachable omission: `/social//google/callback` returned 302 with only
`no-cache` before the fix; `/oauth//authorize` also reached its authorization controller. The
final-response boundary now snapshots the path using that same router normalizer before
ShowExceptions can rewrite it. This aligns the policy with accepted route equivalence rather than
inventing additional accepted paths or changing routing.

Expanded the public request regressions to include repeated-slash settings, GET/POST callback
refusals for all three providers, and real CSRF422 on both Visa authorization realms. Middleware
negative tests retain public-metadata exclusion even with repeated slashes. Final targeted test
result: **9 runs, 192 assertions, 0 failures, 0 errors, 0 skips**. Scoped RuboCop: **4 files
inspected, no offenses detected**. `git diff --check` passed. No development DB write or external
transport was performed during this follow-up. This closes the concrete path-normalization check; no
wider path/parser changes were made.
