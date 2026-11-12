# Zenith dedicated source retirement

Date: 2026-11-12. HEAD: f84c87b060876a25994e30e9274420d9067f1367. Uncommitted changes affected results.

The user explicitly approved removing the two Zenith model trees after their OP subject-snapshot prerequisite. This slice removed only the exact ancestry-derived dedicated files: 217 model files, 740 files under app_principals/app_zenith/org_principals/org_zenith migration directories, two schema snapshots, 71 physical-table fixtures and 119 dedicated model tests (1,149 files total). All candidates were clean before deletion; no dirty candidate required a scope decision.

The static Red inventory recorded every existing path and SHA256 before the path-only deletion patch. Green confirmed all 1,149 paths and the four now-empty migration directories were absent. All 389 remaining model Ruby files parsed successfully. Exact source ownership and ancestry were established by the earlier Ripper inventory, not filename guessing.

No actual database was dropped or changed by this slice. No retained OP or Chronicle model/schema was deleted. Existing audit rows and scalar identity history were not altered. Configuration, shared dependencies, global test helper and CI lists remain parent-owned.

The removed fixture map is recorded in temporary operational inventory; notably organizations.yml mapped to OperatorOrganization, so the parent must remove its now-invalid explicit fixture-class mapping. The current post-retirement reference inventory identifies retained/shared consumers for coordinated review; textual matches include legitimate historical strings/comments and are not automatic deletion candidates.

Rails tests, whole-application boot, coverage and DatabaseConsistency were not run by this slice while the receiver and endpoint agents owned the shared test slot. These static removal checks do not establish global runtime acceptance. Private test/development subject exports were captured before removal; their mappings are not included here.
