# Access Compose Host Scope

- Revision: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- Uncommitted changes affect this observation. Existing host-port and network-name edits were
  retained; this change narrows aliases and tunnel connector definitions in `compose.yaml` and
  `.devcontainer/compose.yaml`.
- The core frontend network now lists eleven public hosts: Auth app/org, Visa app/org, and seven
  `*-access.umaxica.dev` operator hosts. Eleven corresponding internal origin aliases remain.
- Unowned frontend aliases, the legacy `global` outer-network alias, and the Edge and Workers VPC
  connector service definitions were removed. Infrastructure services and volume declarations
  remain.
- Python/PyYAML parsed both files successfully. A diagnostic check confirmed exactly eleven public
  aliases and eleven corresponding internal aliases, and only `cloudflare-tunnel` among tunnel
  connector service definitions. `git diff --check` passed for both Compose files.
- No containers were recreated, stopped or removed. Previously created connector containers may
  still be running; deleting their Compose definitions does not prove they have stopped.
- Runtime checks, Rails/security tests, RuboCop and Brakeman were not run for this
  configuration-only edit. Host Podman access was previously blocked by read-only runtime state.
  Live origin DNS, operator authentication and external reachability remain unverified after these
  edits.
- No Cloudflare resources, DNS, tokens, credentials, databases or volumes were changed. Remotely
  managed ingress remains separate; removing aliases does not prove old public hosts are refused
  when an ingress targets a generic service name or IP. Rails still draws the unowned surfaces.
- Existing multi-surface examples in `docs/operations/cloudflare-private-origin.md` and related
  request-path documentation require reconciliation during the tunnel split; they do not establish
  the narrowed Access topology.
