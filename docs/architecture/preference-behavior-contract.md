# Preference Behavior Contract

Preference model and persisted row history remain in place pending the separate model/database usage
report. The former Base, COM, and other foreign route assignments are retired; they do not establish
current routes or writers.

## Current writer ownership

`PreferenceWriteBoundary` has a closed surface-to-operation map:

| Surface  | Operation             | Owner |
| -------- | --------------------- | ----- |
| Auth APP | `save`                | Auth  |
| Auth ORG | `save`                | Auth  |
| Visa APP | `sign_in`, `sign_out` | Visa  |
| Visa ORG | `sign_in`, `sign_out` | Visa  |

No other surface has Preference write authority. Request parameters and cookies cannot choose an
account or Preference row. A Preference JWT is a signed read projection; it does not create database
rows by itself, and browser cookies are not copied into Preference tables.

## Read and persistence rules

- GET and HEAD do not create, refresh, or retire Preference rows, rotate credentials, or extend
  cookie expiry.
- Auth actor saves authorize the current authenticated actor and persist only submitted fields.
- Visa sign-in reflection follows finalized authorization state and applies only explicit values
  from the matching realm's actor Preference.
- Visa sign-out rebuilding follows committed logout and copies allowed browser preference state from
  the database, not from cookie contents.
- Preference persistence failure does not undo a committed authentication transition or issue an
  authorization code from a failed continuation.
- Unknown fields, malformed JWTs, invalid option values, missing required children, and cross-realm
  writer requests fail explicitly.

The database and cookie transition details are documented in [`preference.md`](preference.md). This
contract describes only retained Auth/Visa callers. A model's presence in a database does not
establish an active writer.
