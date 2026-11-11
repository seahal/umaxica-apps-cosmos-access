# omniauth-apple Upstream Hardening: Owner Verification First (2026-11-10)

Owner: Access. Status: waiting for the owner's own verification; nothing has been sent upstream.

## Why this exists

Apple sign-in uses omniauth-apple 1.4.0 with json-jwt 1.17.2. The ID token signature is verified
without an explicit algorithm allowlist, so algorithms Apple does not publish are accepted when
correctly signed with Apple's key (Apple publishes RS256 only). A local second opinion found no way
to forge a token with the installed versions; the gap is a missing explicit policy, not a confirmed
bypass. The application-side fix (pin RS256) is queued in
`docs/backlog/2026-11-10-core-security-review-followups.md`, item 2.

The owner intends to propose the same hardening to omniauth-apple, and possibly to report a separate
json-jwt observation about ECDSA key and curve checking. Before submitting either, the owner wants
to reproduce and explain the behavior personally: a submitter who cannot verify the claim should not
send it.

## Rules for this record

- No exploit steps, crafted tokens, keys or proof-of-concept code are written in the repository.
  Detailed notes stay only in the owner's private notes. The agent's local second-opinion report was
  deleted on 2026-11-10 for this reason.
- Do not open a public issue describing a weakness before the owner decides the disclosure route. If
  a real bypass is ever reproduced, use the maintainer's private reporting channel instead of a
  public pull request.

## Owner verification plan (outline only)

1. Load only the installed gems with Bundler, without booting Rails.
2. Use locally generated test keys and synthetic claims; never Apple's real tokens or keys, and no
   network calls to Apple.
3. Compare json-jwt's verification with no algorithm list against verification with an explicit
   RS256 list, across the algorithm families json-jwt recognizes, and record which are accepted.
4. Confirm the proposed one-line change (`[:RS256]` as a symbol list) changes only that acceptance
   and keeps the existing error contract.
5. For json-jwt's ECDSA observation, analyze separately whether it matters for any consumer before
   deciding whether and how to report it.

## Exit

- Upstream: a hardening pull request to omniauth-apple (and, if warranted, a private report to
  json-jwt) submitted by the owner after verification.
- This record is then closed and linked from the ADR update in
  `adr/jwt-validation-and-key-risk-decisions.md`.
