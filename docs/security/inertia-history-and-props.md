# Inertia History and Page Props

This document records the security rules for what an Inertia page leaves in the browser: the history
entries that hold page props, and the props themselves. `adr/inertia-rails-thin-adapter.md` makes
history encryption mandatory and leaves history clearing and page-prop content to this document.
Current local scope is Auth APP/ORG and Visa APP/ORG. Former Base, Core, Warp, Palm, Edit, Tech, and
other RP rows are retired from the Access route inventory. External RP clients own their own page
history and completion pages. Retained model history does not establish an active local controller.

## Why history needs clearing

Inertia stores each visited page object, props included, in the tab's history so Back can restore
the page without a server request. `encrypt_history` is on globally, but the key that decrypts the
entries lives in the tab's `sessionStorage`. `reset_session`, cookie deletion, session revocation
and `Cache-Control: no-store` do not reach that key, so a same-tab Back after a session ends can
restore the signed-in page from history. Only `clearHistory: true` on a rendered Inertia page, or
`Clear-Site-Data` with `"storage"`, discards the key.

## When history must be cleared

Every response that ends or changes the browser's authenticated state, and every one-time display of
a secret, must end on a page that clears history:

| Event                                                      | Mechanism                                              | Owner                              |
| ---------------------------------------------------------- | ------------------------------------------------------ | ---------------------------------- |
| Visa APP/ORG OP logout completion and post-commit failures | `clear_history: true` on the Inertia result page       | Visa logout controllers            |
| Auth APP/ORG ceremony end or one-time secret display       | Clear history on the terminal or one-time display page | The owning Auth controller         |
| Any retained Auth/Visa session-state change                | Clear history on the final page after the state change | The owning Auth or Visa controller |

Ordinary navigation must not clear history; doing so would break Back for every page.

## The session flag survives only redirects

`session[:inertia_clear_history]` is read by the next Inertia render, either explicitly or through
the inertia_rails default for `clear_history`. The inertia_rails middleware deletes the flag on
every non-redirect response, including plain HTML pages. A flag set before an HTML page is therefore
lost before any Inertia page renders. A terminal page that must clear history is either an Inertia
page with `clear_history: true`, a redirect that carries the flag to such a page, or an HTML page
that sends `Clear-Site-Data` with `"storage"`. `Clear-Site-Data: "storage"` also unregisters service
workers, so it is used only on surfaces that register none they must keep.

## Page props are public to the page viewer

Inertia embeds the whole page object in the HTML (`use_script_element_for_initial_page`) or in the
JSON body of an Inertia visit. Every prop is readable in the page source, whether or not the page
displays it, and is stored in history until cleared. Props must therefore:

- contain only the fields the page displays or needs to act, built field by field rather than by
  serializing a record (`as_json`, `attributes` and similar);
- expose public references (`public_id`) rather than internal database identifiers;
- never carry tokens, credential digests, hashes, keyed proofs or another actor's data;
- keep shared props (`inertia_share`) free of personal data, because every page of the surface
  carries them;
- be built only after the page's authorization, so an unauthorized request never receives them.

A secret shown once (for example an issued App Secret) may be a prop only on its one-time display
page, which clears history.

## Development tooling

The inertia_rails DevTools recorder stores request URLs and props, redacting only a fixed key list.
`config/initializers/inertia_rails.rb` pins it to development, ignoring `INERTIA_DEVTOOLS_ENABLED`
in every other environment.

## Verification

Verify Visa APP/ORG OP logout and Auth APP/ORG one-time display/ceremony terminal pages using the
retained surface tests. External RP completion pages and their session history must be verified by
their owning repositories. Retired Base/RP test paths are not current Access verification targets.

A full audit of page props remains follow-up work; it must target retained Auth/Visa pages and
exclude removed RP surfaces.
