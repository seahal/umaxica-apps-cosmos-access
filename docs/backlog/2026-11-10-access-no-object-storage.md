# Access: No Object Storage, Active Storage or File Uploads (2026-11-10)

Owner: Access. Status: decided (owner), queued; run with or after the OP-only cleanup.

## Decision (owner, 2026-11-10)

Access stores no files. It uses no S3 or other object storage, no Active Storage and no upload
library. Sign-in, sign-up, sign-out and step-up need none, and Access is an OpenID Provider only
(`adr/access-is-a-pure-openid-provider.md`). Images such as avatars belong to Governance or the
relying party that shows them.

Scope: Access only. Governance, Sphere and Press keep Shrine, S3 and the object-storage settings as
they are; this decision does not apply to them. In those repositories
`OBJECT_STORAGE_SECRET_ACCESS_KEY` still moves to credentials as planned in
`docs/backlog/2026-11-10-secrets-from-credentials-only.md`.

## Observed on 2026-11-10

- Active Storage is loaded: `config/application.rb` requires `active_storage/engine` (routes are not
  drawn); `config/storage.yml` exists; a `storage` database is configured.
- Shrine and S3: `gem "shrine"`, `gem "aws-sdk-s3"`, `config/initializers/shrine.rb`,
  `app/uploaders/application_uploader.rb`, `lib/object_storage_shrine_configuration.rb`,
  `lib/object_storage_environment.rb`, `lib/object_storage_boundary.rb`,
  `lib/tasks/object_storage.rake`; the only model user is `app/models/publishing/media_file.rb`
  (Press data, foreign to Access).
- Environment: `OBJECT_STORAGE_*` variables, including `OBJECT_STORAGE_SECRET_ACCESS_KEY`, which
  `docs/backlog/2026-11-10-secrets-from-credentials-only.md` planned to move into credentials. For
  Access it is removed instead of moved.

## Work order (Codex, this repository)

```
Remove object storage from Access. Destructive removal is approved; no compatibility layer; no
commit. Read AGENTS.md and the rules it requires for config/**, Gemfile, app/**, lib/**, db/** and
test/** (generic/no-compatibility-layer.mdc, project/no-environment-tests.mdc).

- Stop loading active_storage/engine; delete config/storage.yml, the storage database entry and
  its migrations/schema, and any Active Storage tables in other schemas.
- Remove Shrine and S3: the gems shrine and aws-sdk-s3 (keep aws-sdk-sns if telephone delivery uses
  it), the Shrine initializer, uploaders, lib/object_storage_*.rb, lib/tasks/object_storage.rake,
  and any model, job or test that uses them (publishing media is foreign to Access and goes with the
  publishing cleanup).
- Remove OBJECT_STORAGE_* from .env.container.devcontainer, .env templates, compose and CI, and
  update this repository's docs/backlog/2026-11-10-secrets-from-credentials-only.md: for Access the
  object-storage key is deleted, not migrated. Do not change other repositories.
- Add a static guard test: Access loads no active_storage engine and depends on no shrine or
  aws-sdk-s3 gem.
- Run bin/rails zeitwerk:check, bin/rubocop and the affected tests. Record evidence/.
```
