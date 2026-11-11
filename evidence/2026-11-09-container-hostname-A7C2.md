# Development container hostname

- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- The worktree already contained unrelated changes, including `.devcontainer/compose.yaml`.
- Added only a comment and `hostname: cosmos-access-devcontainer-core` to that file.
- `git diff --check -- .devcontainer/compose.yaml` passed.
- `podman ps --format '{{.Names}}\t{{.Status}}'` failed because Podman could not change permissions
  on its read-only runtime directory. Container state and SSH prompt behavior remain unverified; no
  container was recreated.
- Read-only inspection found matching container names in Access, Press and Sphere, but no explicit
  core hostname. Governance still uses `global-devcontainer-core` and Tailscale hostname
  `umaxica-global-core`.
- The three sibling repositories are outside this session's writable roots. Their proposed core
  hostname changes and Governance core/Tailscale rename were prepared in
  `/tmp/cosmos-container-names.patch`, without modifying those repositories. Compose project names,
  volumes, users and home directories were preserved.
