# Cosmos Identity Renders Without Inertia (2026-11-08)

## Status

Accepted (2026-11-08), direction only. Conversion order and completion are not decided by this
record.

Scope: the `umaxica-apps-cosmos-identity` repository only. `umaxica-apps-cosmos-global`,
`umaxica-apps-cosmos-regional` and `umaxica-apps-cosmos-press` continue to use Inertia under
`adr/inertia-rails-thin-adapter.md`.

## Context

`adr/cosmos-identity-authentication-global-authorization-split.md` limits Identity to ceremony
screens: sign-in, MFA, passkey ceremonies, consent, step-up and sign-out. Identity has few screens
and no dashboard.

Inertia keeps page state in browser history. `adr/inertia-rails-thin-adapter.md` therefore makes
history encryption mandatory and requires every sign-out, withdrawal and step-up cancellation path
to set `session[:inertia_clear_history]` so the next Inertia response clears history. At this
decision that flag is set from at least six controller paths. A path that forgets the flag leaves
pages from the previous session readable in history. This is an easily missed, cross-cutting duty,
and it sits on exactly the screens Identity keeps.

At this decision Inertia renders roughly 130 actions under `auth` and `base`, plus Visa OIDC logout
endpoints. Many `base` screens leave Identity under the split, so their conversion is not Identity
work.

## Decision

1. Identity renders all screens with Rails defaults: server-rendered ERB views, forms submitted as
   normal requests, and Stimulus only where a ceremony needs browser APIs (for example WebAuthn).
2. Identity does not use `inertia_rails`, `@inertiajs/*`, Inertia pages under `src/pages/`, or the
   `inertia_clear_history` session flag. Every response that ends a session or ceremony relies on
   ordinary navigation and `Cache-Control: no-store` instead of client history clearing.
3. Screens that leave Identity under the split move to their new owner as they are; they are not
   converted to ERB first.
4. Inertia is removed from Identity by deletion, not hidden behind a compatibility layer
   (`generic/no-compatibility-layer.mdc`).

## Consequences

- The history-clearing duty disappears from Identity; session-ending paths no longer carry a flag
  that every new path must remember.
- Ceremony screens lose client-side page transitions; Identity's small screen count keeps this cost
  low.
- Identity's frontend toolchain shrinks to Vite, Stimulus and CSS; React and Inertia dependencies
  can be removed once no Identity screen uses them.
- The remaining repositories keep `adr/inertia-rails-thin-adapter.md` unchanged, including its
  history-clearing duty.
- Conversion should follow the screen placement decided by the split, so only screens Identity keeps
  are rewritten.
