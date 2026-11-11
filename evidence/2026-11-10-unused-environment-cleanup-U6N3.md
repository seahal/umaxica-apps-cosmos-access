# Unused environment candidate cleanup

Date: 2026-11-10 UTC. Full HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. Scope: this repository,
current dirty worktree. No commit, credential edit, destructive command or external service
connection was performed by this cleanup.

## Decisions and changes

| Candidate                    | Runtime reader | Writable occurrences removed                                                                                      | Remaining blocked definitions |
| ---------------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------: |
| `PUBLIC_PERFORMANCE_URL`     | None found     | Documentation listings                                                                                            |                          2 CI |
| `PRIVATE_PERFORMANCE_URL`    | None found     | Documentation listings                                                                                            |                          2 CI |
| `RAILS_PERFORMANCE_ENABLED`  | None found     | Documentation listing                                                                                             |                          2 CI |
| `RAILS_PERFORMANCE_USERNAME` | None found     | Documentation listings                                                                                            |                          2 CI |
| `PUBLIC_STATUS_URL`          | None found     | One assignment each in `.env.container.devcontainer`, local `.env`, and local `.env.local`; documentation listing |                          2 CI |

All five are verified-unused deletion candidates. **Kept with a runtime reader: none.** Remaining CI
entries are blocked writes, not evidence of runtime use. The `.github` ZFS mount is read-only;
attempting the authorized ten-line removal from `.github/workflows/ci.yml` failed with errno 30. No
restriction was bypassed. CI lines remaining at query time: 296, 337, 338, 343, 349, 580, 621, 622,
627 and 633. Removal is incomplete until that file is writable.

Edited only candidate assignment lines in the environment files and candidate name-list lines in
`docs/backlog/2026-11-10-reduce-environment-variables.md`,
`docs/backlog/2026-11-10-remove-rails-performance.md`, and `docs/reference/ui-view-inventory.md`.
Preserved unrelated listed variables such as `RAILS_PERFORMANCE_PASSWORD`, `PERFORMANCE_REDIS_URL`
and `PUBLIC_ASSET_URL`. Pre-existing staged, unstaged and untracked work was preserved. No Compose
file needed a candidate-line edit. Environment values were neither displayed nor recorded; name-only
matching selected deletions. Credentials paths were excluded from the candidate scan and were not
edited by this cleanup.

## Runtime and dynamic-reader verification

Searched `app/`, `lib/`, `config/`, `bin/`, `script/` when present, `db/`, `src/`, `Rakefile`,
`Gemfile`/lock, `package.json`, `vite.config.*`, `Procfile*`, `Containerfile*`, `podman/**` when
present, `.devcontainer/**`, `.github/**`, `config/ci.rb`, and tests. Also checked root Compose,
README, documentation and environment template/example names. Exact-name tests/assertions had no
candidate matches. A final scan found only the ten CI definitions above.

Independent name-only review confirmed the dynamic paths:

- `lib/config_values_host_family_values.rb:110-162` uses finite host families without Performance or
  Status; generated host keys append fixed service/corporate/staff suffixes.
- `config/environments/development.rb:249-320` has a finite host allowlist without these candidates.
- `app/values/fqdn_availability_registry.rb:23-86` lists only current diagnostic surface slots.
- `config/routes/visa.rb:13` generates only Visa realm keys.
- `app/resolvers/redirects_external_target_resolver.rb:59-61` validates a frozen registry before its
  variable-key lookup at line 94; it cannot accept an arbitrary candidate ENV name.
- `app/controllers/concerns/common_redirect.rb:131-137`, `authentication_client.rb:71-74`,
  `authentication_operator.rb:71-74`, and `social_callback_guard.rb:113-125` use literal finite
  Auth/Base or generic surface key lists, excluding all five.
- `app/values/jump_rt_surface.rb:11-34` validates a finite Auth/Base/Visa/Core/Warp/Palm namespace;
  `client_secret_lifetimes_value.rb:9-27` has only four explicit secret-lifetime configuration
  callers. Neither can resolve a candidate.
- Generic JWT/object-storage/provider/diagnostic/realm-encryption key readers use constrained
  registries or key suffixes. ENV key enumeration selects private-key suffixes; whole-ENV
  snapshots/loaders transport or cache configuration without a semantic consumer for these names.
- Current Bundler dependencies and explicit diagnostic loading no longer include rails_performance.
  Vite has its default `VITE_` exposure namespace and no custom envPrefix matching these candidates.
  Test URL interpolation is limited to existing finite surface families.

The explicitly protected enforcement HMAC keys, workload user/group, sandbox flag, Vite tooling keys
and planned object-storage bucket names were not removed or changed.

## Checks and limits

- Final runtime/docs/environment name-only scan: no candidate occurrences outside blocked CI.
- `git diff --check` for this cleanup: passed.
- No Ruby or test files were changed by this cleanup, so no new Ruby/test run was required. The
  concurrent authorized HMAC execution's separate style/runtime results have their own record.
- Requested `docker compose -f .devcontainer/compose.yaml config -q`: attempted, exit 127 because
  `docker` is unavailable. `podman` is also unavailable; no package or external download was used.
- Supplementary `ruby -ryaml -e 'YAML.parse_file(ARGV.fetch(0)); ...' .devcontainer/compose.yaml`:
  passed YAML syntax parsing. This does not verify Docker Compose interpolation/includes/schema.

Unexpected limitations are the read-only CI mount and absent Docker tooling. No kept-with-reader
candidate was found. Prior HMAC execution completed separately, including two current retained email
digests and a running development server; see
[its record](2026-11-10-access-hmac-approved-execution-K4V8.md).
