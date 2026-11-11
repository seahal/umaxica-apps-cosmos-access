# Remove rails_performance (2026-11-10)

Owner: this repository (same change in all four Cosmos repositories). Status: decided (owner,
2026-11-10). Not urgent: unlike rails_db, the dashboard is already confined.

## Why

The gem's defaults are unsafe (it self-mounts on every host with no switch, Basic auth is off with
literal default credentials, `verify_access_proc` allows all). This application contains it with
several layers: the gem's routes file is dropped in `config/application.rb`, the engine is mounted
only on the operator hosts in `config/routes/performance.rb`, `Rack::Auth::Basic` fails closed
without credentials, Cloudflare Access (`dev` policy) fronts the host, records are sanitized before
Valkey, and the gem loads in development only. Those layers depend on copying gem internals (routes,
patches) that must be re-checked on every upgrade, the gem has eight templates Herb rejects, and
request performance belongs to OpenTelemetry, which stays the basis for APM
(`config/initializers/opentelemetry.rb`, FIXME). Removing it costs less than maintaining it.

## Work order (Codex)

```
Remove the rails_performance gem and its surface from this repository:
- Delete the gem from the Gemfile and update Gemfile.lock with `bundle install --local` (only the gem
  and dependencies nothing else uses may disappear).
- Delete config/initializers/rails_performance.rb, config/routes/performance.rb and its `draw`,
  the routing-path suppression in config/application.rb, lib/rails_performance_record_sanitizer.rb,
  lib/rails_performance_store_resilience.rb, and their tests, if nothing else uses them.
- Remove the variables only this surface used (RAILS_PERFORMANCE_PASSWORD
   and any other) from .env* templates, Compose
  aliases, CI and docs (docs/backlog/2026-11-10-reduce-environment-variables.md); never print values.
- Keep `/rails/performance` among the paths that must never be mounted, so it cannot return.
- Update docs that list the operator tools (seven become six; rails_db is removed separately).
- Confirm no performance route remains in development and the old host answers 404.
- Run bin/rubocop, test/security and the mounted-engine invariant; record results in evidence/.
- Do not touch other operator tools, authentication or databases. No commit.
```

## External follow-up (owner approval required)

Cloudflare still carries `performance-<repository>.umaxica.dev` tunnel routes, DNS records and
destinations in the `dashboard` Access application for all four repositories. Remove them after the
code change, one repository at a time.

Done 2026-11-10: the four `performance-<repository>.umaxica.dev` tunnel routes, DNS records and
`dashboard` Access destinations were removed (owner approval, Cloudflare API).
