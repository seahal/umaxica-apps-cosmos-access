# Access Database Consistency

Status: implementing

Authority: owner request of 2026-11-12; scope narrowed to Access in the same conversation.

This is the scoped continuation of [the earlier remediation](../database-consistency-remediation/spec.md).
The newer request replaces that work's all-database scope and compatibility requirement for this
Access-only cycle. Historical D1/D3/D5 contracts remain untouched in their excluded or unchanged
models. D6's absent-versus-negative evidence distinction remains required; replacing NULL with
false alone is not authorized by the current request to preserve authentication invariants.

## Purpose and scope

Make surviving Access PostgreSQL contracts consistent with Active Record and verify database
enforcement through real PostgreSQL tests. Preserve authentication, realm isolation, replay
protection, audit history and retention. No checker configuration, exclusions, disabled checks,
CI changes, shared database writes or production operations are authorized by this work.

## Database disposition before implementation

The current `config/database.yml` declares 25 writer bindings, including nine generated RP cells.
Replicas follow the disposition of their writer; separate test replica databases are verification
infrastructure, not additional domain owners.

| Binding | Classification | Basis |
| --- | --- | --- |
| `op_base_app`, `op_base_org` | KEEP | Accepted pure-OP ADR, decisions 2 and 17; current handoff explicitly retains both |
| `chronicle` | KEEP | Pure-OP ADR retains Access audit records; individual legacy preference families are not thereby approved for redesign |
| `queue` | EXCLUDED | Owner explicitly excludes Solid Queue |
| `app_zenith`, `org_zenith` | PENDING | Mixed identity/projection data; Governance owns identity, but physical split and destination implementation are unresolved |
| `app_setting`, `org_setting`, `com_setting`, `avatar` | PENDING | Access loses this responsibility; ADR open question leaves physical transfer versus deletion unresolved |
| `publishing` | PENDING | Historical sole content authority does not establish the post-split physical destination |
| `search`, `occurrence`, `app_signal`, `org_signal`, `primary` | PENDING | No current accepted physical disposition located; usage alone is not KEEP approval |
| `rp_base_app`, `rp_core_app`, `rp_warp_app`, `rp_palm_app`, `rp_base_org`, `rp_core_org`, `rp_warp_org`, `rp_edit_org`, `rp_tech_org` | PENDING | Access no longer owns RP services, but individual physical destination/drop decisions remain unconfirmed |

Historical physical `cache` is RETIRE under the accepted cache-removal ADR and is not configured.
The unconfigured physical `storage` database and retained schema/migration artifacts are PENDING;
connection removal did not authorize physical deletion (`docs/operations/db-workflow.md`).
Historical `activity`/`behavior` were consolidated into `chronicle`. Historical `*_principal`
bindings are absent; `*_principals_migrate` are active histories owned by the matching zenith DB,
not independent principal databases. Old `publisher` is not the current `publishing` binding.
The requested `plans/immutable-wibbling-jellyfish.md` is absent locally; historical remote material
does not override local accepted ownership. No PENDING database or Solid Queue file is edited.

Sources: `adr/access-is-a-pure-openid-provider.md` (including uncommitted owner amendments),
`plans/2026-11-12-handoff.md`, `adr/principal-zenith-physical-consolidation.md`,
`adr/publishing-db-content-authority.md`, `adr/chronicle-audit-db-consolidation.md`,
`adr/surface-database-connection-naming.md`, `adr/solid-cache-removal-and-valkey-cache-separation.md`,
`adr/cross-db-reference-policy.md`, `docs/architecture/database-authority-placement.md`, and
`docs/architecture/model-database-inventory.md`. The latter explicitly identifies itself as a
historical pre-reset snapshot; its linked usage audit is not a database-drop decision.

Governance, Sphere and Press are excluded by the owner's follow-up instruction. Their public
October snapshots were inspected read-only before the scope narrowed; they are not substitutes
for current working trees. The broader eight-repository program does not expand this task.

## Acceptance

- AC-1: Report every Access DB disposition before edits; edit only confirmed KEEP contracts.
- AC-2: Important changes have observed Red and Green tests, including database bypass paths and
  affected realm boundaries. Concurrent replay consumption remains once-only.
- AC-3: No constraints, validations or correct partial/expression indexes are weakened to satisfy
  the checker. Report unsupported checker contracts separately from confirmed defects.
- AC-4: Run the unconfigured checker and count KEEP findings separately from Solid Queue and
  PENDING findings. Zero is acceptance, not an assumed outcome.
- AC-5: Verify changed migrations, generated dumps, rollback, reconstruction from empty databases,
  related regression tests, lint and coverage. Keep unverified acceptance open.

## Execution

Inventory and baseline first, then coherent model/table slices ordered by security risk and
dependencies. Investigate checker semantics before changing a valid database contract. Use the
documented runtime and migration workflow. Record actual results in evidence; no historical
migration rewrite silently updates an already-applied environment.

Initial observed baseline: checker exits 1, no configuration; 165 grouped finding lines resolve
to the three KEEP bases through local model ancestry. This is a grouped-line count, not the
expanded count of grouped offenses. Full audit and final acceptance remain open.

### Context identifier contract

The existing identifier ADR's 2026-10-20 amendment requires exactly 21 characters. Its older
reference/checklist capacity-25 text conflicts with that amendment and is corrected in this change.
Before: `public_id varchar(21) NOT NULL UNIQUE`, with no length CHECK or model length validation.
After: the same column and unique index plus `CHECK (char_length(public_id) = 21)` and model
length `is: 21`. The existing `PublicId.generate` issuer remains authoritative; no identity is
derived or regenerated. Existing malformed rows cause validation to fail explicitly. New additive
migrations apply to already-built environments; historical migrations are not rewritten.
