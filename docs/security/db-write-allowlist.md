# DB Write Allowlist

## Purpose

Normal GET and HEAD requests are read-only unless a write is an explicit lifecycle exception. This
allowlist records current accepted exceptions so future CI can fail unreviewed INSERT, UPDATE, or
DELETE statements observed during read-only request tests.

The database remains the source of truth. JWTs are projections or runtime credentials, not authority
to invent state.

## Current Allowlist

| ID  | Classification             | Request phase          | Expected write                                                                   | GET/HEAD lifecycle exception? | Current scope                             |
| --- | -------------------------- | ---------------------- | -------------------------------------------------------------------------------- | ----------------------------- | ----------------------------------------- |
| W8  | Preference save            | Auth Preference write  | Persist an APP/ORG preference update through the explicit `save` operation.      | No                            | Auth APP/ORG non-GET preference endpoints |
| W10 | Cookie consent write       | Auth Preference write  | Persist consent flags and receipt, then issue the committed Preference snapshot. | No                            | Auth APP/ORG preference controls          |
| W11 | Theme write                | Auth Preference write  | Persist submitted theme and issue the committed Preference snapshot.             | No                            | Auth APP/ORG preference controls          |
| W16 | Visa protocol transaction  | OAuth/OIDC/DBSC write  | Commit authorization, token, revocation, logout, or DBSC protocol state.         | No                            | Visa APP/ORG protocol write endpoints     |
| W17 | Auth provider callback     | Credential callback    | Validate callback state and record admitted Auth ceremony evidence.              | No                            | Auth APP/ORG provider callbacks           |
| W18 | Maintenance or repair task | Explicit operator task | Repair, admin, or maintenance writes outside ordinary read-only requests.        | No                            | Explicitly invoked tasks only             |

The former Preference GET writes and authentication GET writes were removed after the request
lifecycle became read-only for GET/HEAD. `set_preferences_cookie` uses read-only Preference loading;
`transparent_refresh_allowed?` rejects browser navigation; authenticated session activity tracking
defaults off for GET/HEAD. Preference state changes only at explicit write boundaries.

The former Preference reset/rebootstrap operation and the App/Org/COM login-time adoption writes are
not current allowlist entries. Auth APP/ORG owns `save`; Visa APP/ORG performs one-way sign-in
reflection and database-sourced sign-out rebuilding through `PreferenceWriteBoundary`. Visa OIDC
result GETs validate the browser binding and result reference, then render a same-origin
continuation form. The POST revalidates and finalizes the result before applying Preference
reflection. External RP callbacks and browser-session writes occur in each RP repository, not
Access.

## CI Direction

Future CI should subscribe to SQL and fail GET/HEAD request tests when INSERT, UPDATE, or DELETE
appears outside this allowlist. A new write path must update this document before the test allowlist
expands.

The allowlist is behavioral. It does not grant permission to move writes into generic controller
setup, repair broken JWTs from the database on normal reads, or introduce hidden state changes
behind read-only routes.
