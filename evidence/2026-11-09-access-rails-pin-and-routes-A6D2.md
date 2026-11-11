# Access Rails pin and route ownership

- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- The worktree contains uncommitted and untracked changes from the ongoing Access separation; no
  commit was created.
- Updated `Gemfile` to pin Rails to `9ba8b1edeeacccb1ff5d2497432242eeddf48aed`, pending
  `omniauth-rails_csrf_protection` support for `config_delegate`.
- `Gemfile.lock` changes only the Rails source locator from `branch: main` to
  `ref: 9ba8b1edeeacccb1ff5d2497432242eeddf48aed`; its locked revision is unchanged. No
  `bundle update` or install was run.
- `RAILS_ENV=test bin/rails runner 'abort unless Rails.env.test?; puts "RAILS_ENV=test booted"'`
  completed successfully and printed `RAILS_ENV=test booted`.
- `config/routes.rb` has no `draw :guid`; the dedicated GUID controllers, view, surface test and
  route test are removed in the current worktree. Identifier processing remains outside that retired
  surface. Shared retired-host route coverage still checks that retired hosts have no route.
- The seven operator tool host settings and `.devcontainer/compose.yaml` aliases already use the
  Access hostnames: `mission-access`, `flipper-access`, `blazer-access`, `pghero-access`,
  `swagger-access`, `performance-access`, and `coverband-access` under `umaxica.dev`. Updated each
  route file's canonical-host comment to match its configured hostname. Existing private development
  aliases remain in place.
- `git diff --check` passed. No full test suite was run for this pin/host documentation change.
