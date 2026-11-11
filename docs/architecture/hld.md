# High-Level Design

## Purpose

This document describes the current high-level architecture for the global Rails application.

## Architecture Overview

The repository is a single Rails app with two user-facing surfaces:

| Surface | Responsibility                     |
| ------- | ---------------------------------- |
| `app`   | End-user product and account flows |
| `org`   | Staff and organization workflows   |

The local public/corporate `com` surface is retired. Retained legacy `Com` models and database state
do not define a served route or UI surface. External RP client registrations remain configuration
for other repositories.

The application also contains identity provider and relying-party behavior that historically lived
behind engine names. Those engine boundaries are retired; the active boundaries are surfaces,
controller lifecycle contracts, database connection groups, and the separate regional repository.

## Routing

- `config/routes.rb` draws route fragments for the app.
- Route fragments apply host constraints and surface-local modules.
- New work should use RESTful routes and path helpers.
- Do not introduce local Rails Engines, wrapper apps, or cross-engine routing proxies.

## Data Ownership

Surface-owned database names follow the `surface_role` model documented in
`docs/architecture/database-boundaries.md`.

Cross-cutting and infrastructure databases remain separate, including `occurrence`, `chronicle`,
`avatar`, `search`, and `queue`. The Access `storage` connection and migration path are no longer
configured. Its physical database, schema, and migration artifacts remain untouched pending the
separate database step. There is deliberately no `cache` database: application cache is
Valkey-backed (`CACHE_REDIS_URL`) and non-authoritative.

Application and library reads use primary connections. Automatic role switching and explicit
application `:reading` blocks are absent; retained replica connection definitions remain unchanged.

## Quality Goals

- Keep surface boundaries explicit.
- Keep authentication, authorization, verification, CSRF, and rate-limit order intact.
- Keep business logic out of controllers.
- Keep database ownership readable through base records and connection names.
- Keep regional content concerns out of this repository unless a current ADR says otherwise.
