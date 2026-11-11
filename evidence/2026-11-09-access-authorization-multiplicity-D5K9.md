# Access authorization parameter multiplicity

Executed 2026-11-09 UTC against full HEAD `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. Extensive
pre-existing uncommitted application, configuration, documentation and test work affects these
results and was preserved. This task implements item 2 in
`docs/backlog/2026-11-10-access-acceptance-gaps.md`; the related no-store work has its own evidence.
No commit, development database write/reset, credential rotation or external request was performed.

## Implemented behavior

The two realm-local Visa authorization bases now supply raw duplicate field names to the existing
request resolver. Recognized parameter names have one shared explicit catalog used by both
strong-parameter allowlists and duplicate classification. Query names are decoded before counting;
Rails' public `request_parameters_list` supplies the original URL-encoded or multipart form pairs.
Counts include repetitions across query and POST form. Values remain in normal Rails parsing and are
neither logged by this change nor recorded here. If a form pair list is unavailable, the request
explicitly fails instead of treating collapsed fields as unique.

Repeated client_id or redirect_uri yields a local invalid_request even for equal values. Other
recognized repeats become the resolver's DuplicateParameters error only after client registration
and exact realm redirect validation succeed. GET's existing protocol-error handler delivers that
error to the registered redirect. The authorization POST adds the same delivery for this specific
error class before its existing general refusal rescue. Normal POST error classifications are
otherwise unchanged. Existing CSRF, request-size, rate-limit, authentication, browser-binding,
continuation and transaction checks remain in place.

Unknown parameter names remain ignored. No transaction is allocated by the tested duplicate
refusals. The accepted request-profile ADR and AUTH-31 checklist now state the durable multiplicity
contract. No existing comment or accepted prose was removed to hide a discrepancy.

## Verification

`PARALLEL_WORKERS=1 OTEL_SDK_DISABLED=true bin/rails test  test/integration/oidc_authorization_parameter_multiplicity_test.rb  test/resolvers/oidc_authorize_request_resolver_test.rb`:
62 runs, 421 assertions, zero failures, errors or skips.

Coverage includes all twelve recognized fields on both realms over GET and POST, equal repeated
values (including empty optional values and zero max_age), percent-encoded field names, repetition
across query/body, three target occurrences with empty values, multipart repeated fields with
unequal values, unregistered client and unsafe redirect refusal, a normal single-occurrence
unauthenticated request, and ignored repeated unknown fields. Assertions check
local-versus-registered destination classification, protocol error names, no-store and unchanged
authorization counts. Required-field absence remains covered by the normal endpoint/refusal tests,
including the companion no-store integration tests. Neither generated request values nor redirect
tokens are retained in this evidence.

Redirect checks inspect locally generated Jump payloads in test memory; they do not contact Jump or
establish external delivery/signature verification. Normal CSRF checks in application code were not
disabled; the standard test environment supplies its existing forgery-protection setting. Fixture
data and cleanup remain confined to the test environment.

Targeted RuboCop on the five application files plus the new integration file passed with zero
offenses. Initial formatting offenses in the new test were corrected. Scoped diff whitespace checks
passed. Full security and final combined verification are recorded in the night-work closure
evidence rather than inferred from these focused results.
