# Local dependency corrections

`database-consistency-explicit-restrict.patch` contains the source and PostgreSQL regression
specification for recognizing an explicit `ON DELETE RESTRICT` as a database deletion contract.
It does not accept an absent delete action, skip models, disable a checker or change application
foreign keys.

The same patch also teaches the uniqueness checkers to match the exact JSONB keys, expression
index operators, and predicates declared by the JSONB uniqueness validator. Its PostgreSQL specs
exercise matching and mismatching indexes in both directions.

When a uniqueness validator skips nil and has an explicit condition, an index predicate that
adds only `validated_column IS NOT NULL` is equivalent on the validated domain. The patch
recognizes this case in both checker directions. PostgreSQL specs retain failure reports for a
different guard column, different status set, OR predicate, or a validator that checks nil.

For association presence, the patch also considers an unconditional presence validator on the
specific foreign-key column alongside the association validator. Conditional, create-only,
allow-nil and allow-blank column validations remain weak, and polymorphic foreign keys and types
are assessed separately. The PostgreSQL regression specs also check that a missing NOT NULL
constraint is still reported.

The same presence check reads missing scalar validator entries without invoking the Rails
validator hash's inserting default. Its PostgreSQL regression iterates that hash as the processor
does, verifies it is unchanged, and checks that the conditional association still produces the
appropriate finding.

The tested dependency is database_consistency 3.0.16 at fork commit
`d5d1781f3d642b428d6a9654099b0cd96ce52fd8`. `vendor/fork/database_consistency` is an ignored,
independent Git working tree. Its local edits are therefore delivered here too; an outer repository
diff alone does not carry that fork's files. The patch is already applied in the current workspace.

For a fresh checkout of that exact dependency revision, inspect and apply from the Access root:

```bash
git -C vendor/fork/database_consistency apply --check "$PWD/patches/database-consistency-explicit-restrict.patch"
git -C vendor/fork/database_consistency apply "$PWD/patches/database-consistency-explicit-restrict.patch"
RAILS_ENV=test bundle exec database_consistency
```

Do not reapply it to the current dirty fork or force it onto a different source revision. This
patch is not automatically installed, published or committed by this change. Publishing the fork
fix and updating dependency provenance require a separate external-write instruction. Current
application checker results depend on the patched local fork; they do not establish that a fresh
unpatched installation has the same results.
