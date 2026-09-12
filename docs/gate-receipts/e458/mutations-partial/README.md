# Partial Mutation Receipts

Exact repair head: `e4584b43c99ddb2047153c2697b8d49f75b75930`.
Execution paused by lead after m4 restoration. This is not a completed mutation
campaign or consumer acceptance. No consumer pin or corpus expectation changed.

All commands used Debug, Zig 0.16.0, the same unmodified ownership tests, an
isolated detached worktree, and a 180-second process-group bound. Actual argv,
PID, duration and status are in each `*.run.json`. No deadline or interrupt fired.
Every mutant has matching before/after source hashes and exact diff; all runtime
source was restored between different mutations. The two m3 executions exercise
the same ordinary-repeated length mutant separately, never stacked mutations.

| Arm | Baseline | Mutant | Named failure |
| --- | --- | --- | --- |
| m1 old capacity-based shrinkAndFree | 3/3 | 2 OK, third entered and ABRT | repeated child EOF preserves retained items with spare capacity |
| m2 packed negative-length guard removed | 3/3 | 2 OK, third entered and ABRT | negative packed length is refused before allocation |
| m3 ordinary negative-length guard removed, child | 3/3 | 2 OK, third entered and ABRT | negative repeated child length is refused before allocation |
| m3 same mutant, string | 3/3 | 2 OK, third entered and ABRT | negative repeated string length is refused before allocation |
| m4 top-level decode error deinit removed | 18/18 | 14 passed, 4 failed; 5 tests leaked | see below |

All named tests above have the `decode ownership: ` prefix. The two additional
tests in the narrow filters are the existing root/import tests. The panic arms
are compile-valid named aborts at held collection 3, not completed assertion
failures or full-suite results. m1 panicked at the old shrink precondition;
m2/m3 panicked at the signed-to-unsigned conversion. Each compiler command exited
1 after its test process received ABRT.

m4's four `FAIL (MemoryLeakDetected)` tests:

- complete message allocation failures release partial state
- truncated repeated child allocation failures release partial state
- malformed merged submessages and oneof release partial state
- repeated string EOF releases earlier strings

The additional leak-bearing test, `later scalar EOF releases all prior owned
fields`, completed its assertion with OK but emitted allocator leak errors.
These are overlapping sets: do not report five failed assertions or add five
leaks to four failures as nine failing tests. All 18 names executed, unchanged.

The first m1 baseline ran directly through the bounded wrapper before the
capture helper existed. Its log/argv/status are preserved; it has no retrospective
before/after receipt. The later exact-source baseline and final restoration
hashes are independent records, not invented m1 start observations.

At `2026-09-12T15:15:26.550Z`, all ten recorded gate PIDs were gone and the
compiler/test executable-name inventory was empty. `pause-process-source.json`
records the clean exact e458 mutation worktree and restored file hashes. The
repair worktree was also checked clean. No post-m4 test was run.

Pending, explicitly unexecuted:

- optional packed-list cleanup severance
- optional repeated-list cleanup severance
- failed appended-child cleanup severance
- additional rollback scalar/enum mutation targets from the source plan
- final restored focused replay after m4
- all 16 original consumer frames and unchanged eight adverse controls,
  especially the exact retained truncated input's typed refusal
- consumer repins and independent reviews

Previously completed five baseline gates remain in the parent receipt directory:
focused Debug/Safe/Fast 18/18 each; full Debug/Safe 166/166 each.

Lane: codex-avatar-gui
