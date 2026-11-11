# Preference Lifecycle

Use this checklist for Preference behavior reached from the retained Auth APP/ORG and Visa APP/ORG
surfaces. Persisted model history outside those surfaces remains subject to the separate
model/database usage report.

- PREF-1: Only the closed `PreferenceWriteBoundary` map grants writes: Auth APP/ORG own `save`; Visa
  APP/ORG own sign-in reflection and sign-out rebuilding. Unknown surface/operation pairs refuse.
- PREF-2: GET and HEAD do not create, update, retire, or refresh Preference rows, reissue a JWT, or
  extend expiry.
- PREF-3: An Auth save authorizes the current actor and persists only submitted fields. Cookie or
  request values never select a different account or row.
- PREF-4: Visa sign-in reflection reads only explicit display values from the matching realm's actor
  Preference after authorization finalizes; missing values are not inferred from child records.
- PREF-5: Visa sign-out rebuilds anonymous state only after logout commits and copies allowed values
  from the database. Cookie contents do not populate database state.
- PREF-6: A Preference persistence or token-issuance failure does not undo a committed
  authentication transition or issue an authorization code from a failed continuation.
- PREF-7: APP and ORG reject each other's Preference row and token authority.
- PREF-8: Malformed JWTs, unknown fields, invalid options, missing required child records, and
  unsupported writer combinations fail explicitly.
- PREF-9: Request-local `ri`, `lx`, `ct`, and `tz` overlays affect only the current Actor snapshot;
  they do not update persisted Preference values or a token.
- PREF-10: A model or database row left from a retired route does not authorize an implicit writer.

See the current [Preference behavior contract](../architecture/preference-behavior-contract.md) and
[Preference architecture](../architecture/preference.md). Checklist criteria state required
behavior; their presence is not evidence that the behavior has passed.
