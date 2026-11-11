# Re-verify the Sign-up Age Limit Removal (2026-11-11)

Owner: Access. Status: queued; verification only, no change decided.

## Context

`adr/sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md` (accepted 2026-10-28,
implemented 2026-10-30) replaced the 16-year (`.app`) and 13-year (`.com`) sign-up thresholds with a
one-day minimum: a birthdate is accepted when it is before today. The owner asked on 2026-11-11
whether old constants remain and wants the whole area checked again.

## Observed on 2026-11-11 (code reading only; nothing run)

- `app/policies/sign_up_eligibility_policy.rb` accepts a birthdate when `birthdate < today`; it
  serves `app` and `org` only.
- No 13 or 16 year threshold was found in `app/`, `lib/` or `config/`.
- `13` and `18` remain only as sample values in `test/models/concerns/has_birthdate_test.rb` and
  `test/services/age_eligibility_test.rb`.
- `valid_sign_up_birthdate?` in `app/controllers/concerns/sign_up_sequence_controller_support.rb`
  still calls the policy; `HasBirthdate#birthdate_not_future` overlaps with its only condition.
- `AgeEligibility.minimum_age_reached?` and `HasBirthdate#minimum_age_reached?` may now have no
  non-test caller.

## To verify

1. Search documentation and copy for stale statements: `docs/policy/signup-eligibility.md`,
   `docs/design.md`, `config/locales/**` (the `sign.shared.birthdate.*` and age copy), checklists,
   Mermaid diagrams and QA documents; also the Edge and front-end sources outside this repository
   that may show "16" or "13" in sign-up screens.
2. Run the sign-up birthdate tests at the boundaries: yesterday accepted, today refused, tomorrow
   refused, missing, malformed, and leap-day values.
3. Decide whether `AgeEligibility.minimum_age_reached?` and the matching `HasBirthdate` method are
   kept for a future feature-level age rule (ADR decision 5) or removed as unused.
4. Confirm that no COM sign-up age code remains anywhere (`.com` is retired).

Record the result in `evidence/` and update this entry.
