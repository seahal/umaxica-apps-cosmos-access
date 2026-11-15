# Auth Sign-In Ceremony Restoration Evidence

## Outcome

The restoration work was not started. Its required predecessor,
`plans/2026-11-14-front-channel-id-token-sign-in-work-order.md`, has no matching evidence record
under `evidence/`, and the current implementation still stops before front-channel issuance. The
restoration order explicitly requires stopping when this predecessor is missing or stopped on the
lookup contract. Building ceremonies now would rely on an unimplemented sign-in lookup contract.

## Findings

- `app/resolvers/oidc_authorize_request_resolver.rb` accepts `response_type=id_token` for registered
  front-channel clients.
- `app/controllers/concerns/oidc_authorization_start.rb` returns HTTP 503 for those requests before
  allocating the authorization handoff. No ID Token reaches the RP callback.
- The client and operator OIDC authorization transaction tables still require `response_type`,
  `code_challenge`, and `code_challenge_method`; their models accept only `code`. The transaction
  coordinator fetches the PKCE fields as required values.
- `config/routes/auth.rb` still routes the App and Org sign-in resources, including the ingress
  paths, to their `UnavailableCeremoniesController`s.

These observations leave the required Visa ID Token issuance and the approved browser lookup
contract unverified and incomplete. No Auth ceremony controllers, routes, or tests were changed.

## Verification and Scope

- Inspected the two work orders, the current authorization resolver/start path, transaction models
  and coordinator, and Auth route definitions.
- No tests or checks were run because the work order's prerequisite requires stopping before
  ceremony implementation.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The pre-existing worktree was already dirty: 838 non-untracked status entries and 110 untracked
  entries were present before this evidence file was added. Those changes were preserved and affect
  the inspected implementation state.
- `git status --short -- config/credentials` and `git diff --name-only -- config/credentials`
  returned no entries. No credentials files were edited. No commit or push was made.

## Required Follow-Up

Finish the front-channel ID Token issuance and the Governance-to-Auth browser lookup contract under
the predecessor work order, record its evidence, and then resume this restoration order. Until then,
both App and Org Auth sign-in ceremonies remain unavailable; sign-up remains outside this order and
must remain unavailable.
