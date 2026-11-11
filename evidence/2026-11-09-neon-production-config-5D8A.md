# Neon Production Database Configuration Removal

Date: 2026-11-09

## Scope

Applied the 2026-11-09 amendment in `adr/staging-aurora-postgresql-topology.md`: removed the
production database entries and Neon environment-variable reads from `config/database.yml`, and made
production application boot fail explicitly until a database provider is selected. Replaced the
Neon-specific assertions in `test/unit/database_password_config_test.rb` with assertions that the
production configuration is empty and the boot guard is explicit.

No `.env*` contents were inspected or changed. The worktree has existing changes in
`.devcontainer/compose.yaml` and `compose.yaml`; this task did not modify them. No database create,
reset, or delete operation, external service write, container operation, or commit was performed.
The working tree's unrelated uncommitted changes were preserved.

## Verification

- `RAILS_ENV=test bin/rails runner ...`: booted successfully. The loaded test database configuration
  digest matched the pre-edit value.
- `RAILS_ENV=development bin/rails runner ...`: booted successfully. The loaded development database
  configuration digest matched the pre-edit value.
- `RAILS_ENV=production bin/rails runner ...`: application boot stopped at the early production
  database guard with
  `Production database is not configured; choose a provider before booting production.` before
  unrelated production prerequisites could mask the reason.
- `bin/rails test test/unit/database_password_config_test.rb`: 3 runs, 28 assertions, 0 failures, 0
  errors, 0 skips.
- `bin/rubocop config test`: 2,204 files inspected, no offenses.
- `git grep -iw neon -- config app lib test`: 0 matches.
- `rg -n 'NEON_|\bNeon\b|\bneon\b' config app lib test`: 0 matches.
- `git diff --check`: passed.

The `production` section of `config/database.yml` is empty. No credential or key value was printed
or changed.

## Repository State

- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`
- Uncommitted changes: yes, including prior authorized work and this change.
