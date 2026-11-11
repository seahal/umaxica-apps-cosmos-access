# Logout And Session Management

## Ownership

Visa APP and ORG own the local OpenID Provider, its sessions, and authority-stop decisions. Auth APP
and ORG own credential ceremonies; they do not own Visa OP session state. Access has no local RP
callback, RP session, or RP logout-completion surface. External RP registrations remain available
through Visa, while each external RP owner controls its own cookies, sessions, callbacks, and return
routes. A browser cookie on one host never authorizes mutation of another surface's session.

`OpAuthorityStopCommitter` is the realm-specific writer that stops OP roots and grants. The durable
stop has root, grant, cutoff and BCL participant children. Sign-out is not a persisted sign-out-flow
lifecycle. Visa uses a one-use presentation notice for its own completion page; it creates no
browser receipt. A separate session marker distinguishes a repeat of a completed confirmation from
an unrelated stale submission and cannot authorize a stop.

## Current-device logout

The current OP session is the browser's Visa device session and its root-token rotation lineage.
Visa verifies an ID Token hint, when supplied, and binds its grant and client to that current device
before staging. A verified hint without an OP session or naming a grant from another device is
refused. An expired otherwise valid hint is accepted. Invalid HTML requests show localized generic
text; JSON responses retain protocol error details. An RP-cell request can omit the hint and supply
its registered client and exact return URI. Without a usable OP session this makes no authority
change; Visa returns to that URI with the request state, or reports already signed out when there is
no valid return. With a usable OP session, the normal device confirmation remains independent of RP
local sign-out.

The separate CSRF-protected confirmation rechecks the device and stops each root in its lineage, all
grants under it and the device itself. Each root stop records cause `rp_initiated_logout`, scope
`root` and no epoch cutoff. Other devices and realms stay independent. Sign-out-all and
revoke-other-sessions use their own explicit operations.

A failed pre-commit stop retains the Visa credentials and pending request. An unknown commit retains
them and returns 503 so retry can re-read the same device. After a confirmed commit, the browser is
cleared and the result remains signed out even if later notice storage or redirect construction
fails. Solid Queue and the recurring sweep deliver BCL after commit; delivery cannot undo the stop.

## External RP logout contract

An external RP client may implement local-session-first sign-out: revoke the RP-local session and
its cookies, then ask Visa to revoke only the matching Refresh Token. A failed remote revoke does
not restore the external RP session; any remaining token is bounded by its original expiry. The RP's
completion route and one-use state handling belong to that RP and are not implemented by Access. If
the user leaves Visa without confirming OP-wide logout, the external RP may remain signed out
locally while the OP device and unrelated grants remain active.

Visa's APP and ORG `/oauth/revoke` leaves are protocol endpoints that inherit directly from
`ActionController::API`. They authenticate the registered client from the request body and bind the
submitted token to that client's own RP grant; browser cookies, Rails sessions, Origin and Fetch
Metadata do not authorize revocation. Visa authenticates each client according to its retained
registration. The endpoint retains a 20-per-minute source-IP limit before client authentication and
adds a 600-per-minute limit for an authenticated client. RP servers send sign-outs for many users
from a shared source IP, so the client limit allows short bursts of up to ten requests per second
while limiting a faulty or misused client; the source-IP limit remains the unauthenticated guard.
The ORG `/oauth/token` leaf remains on its existing browser-forgery-protected base and is a separate
unresolved protocol-boundary residual.

External RP logout controllers are outside this repository. The preceding RP behavior is a protocol
integration contract, not a description of current Access controllers.

## Back-Channel Logout receiver

Each registered external RP receiver is bound to its registered issuer and client. It validates the
Logout Token, then commits replay receipt, absorbing `sid` tombstone and matching local grant
revocation before returning success. A request cannot choose another receiver's issuer, audience or
surface. The Visa OP's durable participant is retried by Solid Queue and a recurring sweep after the
stop commits. HTTP 200 and 204 acknowledge delivery; other responses follow the retry or refusal
policy. Discovery advertises session-aware back-channel logout, and the ID Token and Logout Token
use the grant public ID as `sid`.

## Related contracts

- [Logout request and confirmation sequence](logout-sequence.md)
- [Visa OP and external client ownership boundary](../../adr/visa-op-host.md)
- [Separated-store OP commit and BCL](../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md)
- [Current sign-out acceptance requirements](../checklists/sign-out.md)
