# Software Requirements Specification

> **Partially superseded by Identity Authority inversion:** Identity requirements in this document
> must be read through `docs/identity/authority-boundary.md`. `acme/www` owns session, token,
> account, preference, authorization, and downstream-token authority. `sign/id` is ceremony-only. Do
> not use this document to reintroduce sign-side token lifecycle, sessions, preference, dashboard,
> account lifecycle, logout, or step-up freshness.
>
> **Surface scope update:** Access serves only the local `app` and `org` surfaces. The local `com`
> user-facing surface was retired by `specs/access-surface-hard-reset/spec.md`. Retained legacy
> `Com` data models do not authorize a `com` route, controller, or UI.

## 1. Purpose

This specification defines the target Rails architecture for the global application. The system is a
single Rails app with surface and repository boundaries, not Rails Engine boundaries.

## 2. Scope

- `app` owns end-user product and account flows.
- `org` owns staff and organization workflows.
- The former local public/corporate `com` surface is retired; external OIDC client registrations
  remain configuration for other repositories and are not local surfaces.
- Identity provider and relying-party behavior are implemented inside this Rails app.
- Regional content delivery belongs to the separate regional repository.
- Models stay centralized in `app/models`.
- Shared concerns, services, helpers, and layouts remain in the root Rails app through explicit
  local abstractions.

## 3. External Surfaces

| Surface | Main purpose                       |
| ------- | ---------------------------------- |
| `app`   | End-user product and account flows |
| `org`   | Staff and organization workflows   |

## 4. Functional Requirements

- Each surface must enforce host constraints at the route layer.
- Sign flows must support registration, authentication, passkeys, and token lifecycle.
- Surface flows must support preferences and safe cross-surface navigation where explicitly allowed.
- Staff and organization flows must enforce the established authorization pipeline.
- Database ownership must match the accepted `surface_role` connection model.
- Security-sensitive writes must continue to use encryption, audit logging, and structured errors.

## 5. Data and Boundary Rules

| Boundary           | Rule                                                             |
| ------------------ | ---------------------------------------------------------------- |
| Surface-owned data | Use the `surface_role` database naming model                     |
| Cross-cutting data | Keep independent base records and connections                    |
| Regional content   | Keep outside this repository unless a current ADR says otherwise |
| Infrastructure     | Keep queue, cache, storage, and similar infrastructure explicit  |

## 6. Non-Functional Requirements

- Keep host mismatch behavior strict.
- Keep security and audit behavior explicit.
- Keep health endpoints fast.
- Keep docs and plans synchronized with the current boundary model.
- Keep shared model definitions stable unless a current ADR or plan requires relocation.

## 7. Verification

- Route tests must confirm that each surface resolves only its intended hosts.
- Model and database tests must confirm that base records use the assigned database group.
- Security tests must confirm that auth, redirect, CSRF, verification, and audit rules still hold.
- Integration tests must confirm that Auth and Visa `app` and `org` behavior remains separated.
- Model tests for retained legacy identity data describe persistence only, not a served `com`
  surface.
