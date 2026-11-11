# Access: Centered Ceremony Layout Without Site Chrome (2026-11-10)

Owner: Access (`auth`, `visa`). Status: decided (owner), queued. Appearance follows `DESIGN.md`.

## Decision (owner, 2026-11-10)

Access is a sign-in and sign-out component (`adr/access-is-a-pure-openid-provider.md`), not an
application site. Its screens are reached by redirect from a relying party, run one ceremony and
return. They use a single centered layout like the Apple and Google sign-in pages: one card centered
horizontally and vertically, no site header, navigation or footer.

Reason: the current layouts (`app/views/layouts/{auth,visa}/{app,org}/application.html.erb` and
`inertia.html.erb`, `src/layouts/SurfaceLayout.tsx`) carry application-site chrome (header with
banner and flash area, footer with copyright). It makes the ceremony screens look like a site to
browse, adds parts to maintain on every Access screen, and does not fit a component that only runs
sign-in and sign-out.

## Intended shape

- Page: the card is centered horizontally and vertically in the viewport; on narrow screens it fills
  the width with the side gutter from `DESIGN.md` and starts from the top when taller than the
  viewport (no clipped content, no horizontal scroll).
- Card, top to bottom: service mark, the ceremony title (for example "Sign in"), the requesting
  relying party's name when known, the form or the passkey and social buttons, errors inside the
  card next to what they concern.
- Under the card, small and quiet: the copyright line and a fixed allow-list of links to static,
  session-independent pages (terms, privacy, help), each opening in a new window (`target="_blank"`,
  `rel="noopener noreferrer"`; owner, 2026-11-10) so the ceremony is not interrupted. Nothing else.
- No site header, navigation, flash area or account menu; no links or menus to preferences, sign-in,
  sign-up or sign-out, and no language or theme switcher
  (`adr/cosmos-base-surface-decomposition.md`, decision 8: Auth and Visa carry no navigation out of
  their ceremonies; the only way back is the RP's `redirect_uri` with `state`).
- The Umaxica logo is an image, not a link: a logo link to a home page is navigation out of the
  ceremony, and Auth and Visa have no home page (decision 9).
- Third-party buttons follow `docs/reference/third-party-sign-in-button-requirements.md`.

## Work order (Codex, this repository)

```
Give Access (auth and visa, app and org realms) one centered ceremony layout, replacing site chrome.
Read DESIGN.md, docs/reference/react.md, docs/design.md,
docs/reference/third-party-sign-in-button-requirements.md, generic/no-flash-messages.mdc and the
AGENTS.md rules for app/views/**, src/** and app/controllers/**.

- Replace the header/footer structure in app/views/layouts/{auth,visa}/{app,org}/application.html.erb
  and inertia.html.erb, and src/layouts/SurfaceLayout.tsx where Access pages use it, with a single
  shared centered-card layout (one ERB layout and one React layout, shared by both realms; no copy
  per realm unless a realm difference is required, and then state it).
- Keep: the skip link, the Turnstile script where it is loaded now, CSP nonces, meta tags,
  Inertia history encryption and every security-relevant include. Do not change controllers'
  authentication, CSRF or redirect behavior.
- Remove from Access layouts: the header (current_banner, flash_messages), the footer (copyright)
  and any navigation. Show ceremony errors inside the card through the existing form error
  mechanism, not flash. If a banner carries a required notice (for example a non-production
  environment marker), keep it as a small line inside the page and report it.
- Under the card: the copyright line and links to terms, privacy and help only, if those pages
  exist today. Keep the allow-list in one place. Each footer link opens in a new window:
  target="_blank" with rel="noopener noreferrer", so the ceremony page stays intact.
- The logo renders as a non-link image. Remove any link, menu or switcher to preferences, sign-in,
  sign-up, sign-out, language or theme (adr/cosmos-base-surface-decomposition.md decisions 8 and 9);
  links between steps of the same ceremony stay.
- Add a test that Access pages contain no link other than ceremony steps and the footer
  allow-list, that every footer link has target="_blank" and rel="noopener noreferrer", and that
  the logo is not a link.
- Responsive: centered both ways on desktop; full width with the DESIGN.md gutter on phones; no
  horizontal scroll; tall content scrolls from the top.
- Verify in a browser at desktop and phone widths: sign-in, sign-up, passkey, step-up, OIDC logout
  confirmation, an error state. Run bun run check, bundle exec erb_lint --lint-all, bin/rubocop and
  the affected tests (update layout assertions; add a test that Access pages render no site
  header or footer). No commit. Report the screens checked and anything kept from the old chrome.
```
