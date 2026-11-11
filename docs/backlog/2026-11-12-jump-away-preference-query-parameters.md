# Pass Display Preferences to Jump and Away as Query Parameters (2026-11-12)

Owner: Cosmos (the link-issuing concern in all four repositories), with Jump and Away. Status:
decided (owner), queued.

Decided (owner, 2026-11-12): Jump and Away cannot read Cosmos preference cookies (different domain).
To keep the experience consistent, the Cosmos link issuer adds the person's preference values as
plain GET query parameters, separate from the signed token, only when a value is not `sys` (system
default). The owner rejected putting preferences inside the signed token. Language is not passed
now; it may be added later.

## Contract

- Parameter: `theme=light|dark`. Omitted when the preference is `sys`. Other display preferences
  (for example reduced motion) only by a later decision.
- The parameter is display-only and untrusted: it never affects token verification, routing,
  destination checks or any security decision. The signed token (`rt` for Jump, the Away token for
  Away) is verified exactly as today and is unchanged.
- Receivers accept only the listed values; anything else, repeated or unknown parameters are ignored
  and the default applies. Values are never reflected unescaped and never logged.
- Without the parameter, the page follows the browser: CSS `prefers-color-scheme` (no JavaScript).
- Responses stay `Cache-Control: no-store`; the parameter does not create cacheable variants.
- Jump has no page except errors; the parameter only styles its error pages. Away styles its
  interstitial. Neither copies the parameter into the onward link or the return token.

## Work

1. Cosmos (all four repositories, the one link-issuing concern): append `theme` when the stored
   preference is not `sys`; amend `adr/secure-jump-link-redirector.md` to record this display-only
   exception to "no raw values next to `rt`".
2. Jump: read and validate `theme` for error pages.
3. Away: read and validate `theme` for the interstitial.
4. Tests: omitted for `sys`; invalid values ignored; tampering with `theme` changes only the look; a
   tampered token is still refused.
