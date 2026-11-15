# Sign Flow Terminology: Availability, Ingress, Eligibility, Requirements (2026-11-14)

## Status

Accepted (owner, 2026-11-14). Naming only; behaviour, security order and stored values do not
change. Implementation is in the backlog:
`plans/backlog/2026-11-14-sign-flow-terminology-rename-work-order.md`.

## Context

The sign-in and sign-up flows used metaphors that read unnaturally to English speakers and do not
say what the code does: "sentry" (a guard) for both an on/off switch and an entry endpoint, "guard"
for another entry endpoint, "guardrail" for a policy decision, and "checkpoint" for the steps a
person must complete. "Sentry" is also the name of a widely used error-monitoring tool, so the term
would be ambiguous in logs, dependencies and conversation. Most Auth ceremony code was removed on
2026-11-13 (`727cdb560`) and will be restored from history, which makes this the cheapest moment to
rename.

## Decision

Each term is one English noun and maps onto Rails resourceful routing without custom inflections
(checked with ActiveSupport: `ingress` ↔ `ingresses`, `availability` ↔ `availabilities`,
`eligibility` ↔ `eligibilities`, `requirement` ↔ `requirements`).

| Old                                            | New                                     | Meaning                                                                                                                                                                   | Code and routing shape                                                                                                                                                                        |
| ---------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| sentry (switch)                                | **availability**                        | Whether sign-in or sign-up is open, per realm and flow (Flipper flags `sign_in_available_app`, `sign_up_available_app`, `sign_in_available_org`, `sign_up_available_org`) | Internal value and resolver (`SignEntryAvailability…`, `available?`); no route. A notice page, if ever needed, is `resource :availability, only: :show`                                       |
| sentry (entry endpoint), guard (sign-up entry) | **ingress**                             | The endpoint where a browser handed over by Visa enters Auth: it checks availability and the handoff, then sends the browser to the first step                            | `resource :ingress, only: :show` under `sign/in` and `sign/up` (`/sign/in/ingress`, `/sign/up/ingress`, `Sign::In::IngressesController`)                                                      |
| guardrail                                      | **eligibility**                         | The policy decision whether this person may continue (for example a forbidden account)                                                                                    | State `ELIGIBILITY_PENDING`, outcome `ineligible`, transition `enter_eligibility`; a refusal page, if any, is `resource :eligibility, only: :show`                                            |
| checkpoint                                     | **requirements** (one: **requirement**) | The steps a person must complete before the flow can finish (birthdate, passkey, passcode, and the post-session steps of sign-in)                                         | State `REQUIREMENTS_PENDING`; routes `namespace :requirements` with one singular resource per step (`/sign/up/requirements/birthdate`); aligned with the existing `SignUpRequirementRegistry` |

Rules:

1. Rename identifiers: Ruby constants, classes, modules, methods, route names and paths, helpers,
   views, locale keys, log event names, tests and docs.
2. Keep stored values: integer state codes (40, 60 and so on), database column values and Flipper
   flag keys do not change. Where a reference table stores a name string, update the row with a
   reversible migration.
3. No aliases or compatibility layer for old names or paths. The entry path has no external
   consumer: Jump knows origins only, and Visa builds the URL from the route helper.
4. Code that is currently removed is restored under the new names, not restored and then renamed.
5. Rejected names: `start` (too plain), `admission` (collides with `AuthAdmissionBinding` and
   `BaseAuthAdmissionCoordinator`, and with availability in meaning), `policy check` (two words;
   `policy` alone collides with `app/policies/`), `lobby` (a retired path), `gateway` (Jump's role).
6. ADR file names keep their old wording (for example `sign-up-checkpoint-turnstile-boundary.md`) so
   that links stay stable; their text gets a note pointing here.

## Consequences

- One vocabulary across routes, controllers, states and docs; old terms remain only in history and
  in ADR file names.
- Every work order written from now on uses the new terms.
- `ingress` is also used in `lib/runtime_role_route_guard.rb` in its general sense (requests
  entering the application); that use is unrelated and stays.
