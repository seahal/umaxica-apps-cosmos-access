# Front-end Coverage Below the 99% Threshold (2026-11-12)

Owner: Access. Status: open.

The pre-push hook (`frontend-check`, `bun run test:coverage`) failed after commit `fbc9d138a`
(cleanup round 2): lines 93.97%, functions 92.4%, statements 94.08%, branches 87.44%, against a
99% global threshold. The commit was pushed with `--no-verify` (owner, 2026-11-12) so the work could
continue on another machine. Likely cause: the round 2 removal of `src/pages/{base,core,palm,warp}`
and their tests changed the covered/uncovered ratio.

To do: list the uncovered files; remove code that no Access entry point uses any more, and add tests
for what stays; do not lower the threshold. Much of the Inertia front end will be deleted by
`plans/2026-11-12-access-inertia-removal-plan.md`, so prefer deletion over new tests for screens that
plan removes. Run `bun run test:coverage` until it passes.
