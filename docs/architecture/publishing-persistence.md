# Publishing Persistence History

Publishing tables, models, and their migration history remain in the repository while the
surface-hard-reset model/database report determines their remaining callers and ownership. This
document records persisted shape decisions only; it does not describe a current Access route,
controller, or writer.

The former Docs, Help, News, Info, and Edit management/read routes were removed from Access. No
Publishing HTTP read API or management interface is currently served here. External repositories own
any corresponding public pages and operator interfaces. Do not infer an active route from a
`Publishing::*` model or table.

The earlier Publishing decisions remain relevant to data history:

- Publishing content used explicit family tables instead of polymorphic associations, STI, or
  discriminator-based table selection.
- Revision and version fields used Active Record Encryption; `content_digest` represented a
  canonical plaintext hash, not a confidentiality control.
- Media usage records had explicit owner foreign keys.

See
[`adr/publishing-twelve-family-encrypted-persistence.md`](../../adr/publishing-twelve-family-encrypted-persistence.md)
for the accepted storage decision. The present route reset did not change schemas, migrations, or
database contents.
