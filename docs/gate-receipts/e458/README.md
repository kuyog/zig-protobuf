# Completed Dependency Gates

Tested source: `e4584b43c99ddb2047153c2697b8d49f75b75930`.
Shipping baseline: `81959a3f735e853dbb73caeec42b4084e4b0fc72`.
This evidence-only branch does not move the repair branch or its Draft PR.

| Gate | Tests | Steps | Elapsed seconds | Exit |
| --- | --- | --- | --- | --- |
| Focused Debug | 18/18 | direct test | 2.163486625 | 0 |
| Focused ReleaseSafe | 18/18 | direct test | 6.425417125 | 0 |
| Focused ReleaseFast | 18/18 | direct test | 6.775899542 | 0 |
| Full Debug | 166/166 | 26/26 | 34.493764791 | 0 |
| Full ReleaseSafe | 166/166 | 26/26 | 88.186048250 | 0 |

The focused total includes 16 named ownership tests and two import tests. Every
run completed inside its 180-second bound, with `forced=false` and
`interrupted=false`. Exact commands, PIDs and Unix bounds are in the adjacent
unmodified `*.run.json`; named results and full build summaries are in `*.log`.
Working directory was `/Users/dallindyer/Dev/flutter_source/zig-protobuf-decode-errors`.
Compiler was `/opt/homebrew/Cellar/zig/0.16.0_1/bin/zig`.

## Evidence Boundary

Execution was paused on lead request after these five gates. The repair worktree
was clean, remote repair head remained exact e458, and no compiler/test/protoc
process remained at handback. No mutation worktree or arm was started. No corpus
build or replay was started. Full ReleaseFast, held-total mutations, retained
real-frame adverse replay, consumer gates/repins, formatting gate and independent
review remain pending. No cache/vendor edits or model rerouting occurred.

The original focused RED at 340078b and exact-baseline positive-control RED are
preserved in [PR comment](https://github.com/kuyog/zig-protobuf/pull/1#issuecomment-5643415308).
The distinct unmatched-oneof descriptor-order defect remains
[open issue 2](https://github.com/kuyog/zig-protobuf/issues/2). Current e458 only
reorders the ownership fixture to isolate that defect; runtime repair bytes are
unchanged from 340078b. These passing dependency gates do not establish that the
private truncated real corpus is fixed. No private corpus bytes are published.

## SHA256

```text
42862162aa04c5021c40d818cdeb2144cce59bec60287dc166af6cf062923937  e458-focused-debug.log
cc745fd4b0996a1808605e8737ec7534fecce0964463191b9e10b7ab946827cc  e458-focused-debug.run.json
42862162aa04c5021c40d818cdeb2144cce59bec60287dc166af6cf062923937  e458-focused-safe.log
bf039a0b835df6cf6295ef380be52d4d88dc1fa02c3827eacb20344d4fbecc95  e458-focused-safe.run.json
42862162aa04c5021c40d818cdeb2144cce59bec60287dc166af6cf062923937  e458-focused-fast.log
ccfcc5bf0b4dfd43349a10d99f0acbea50c1555e8b0b03153ece3d4a037b0640  e458-focused-fast.run.json
b59614d68f9888e3d0be5c659ee662f83f34544c4ce81bd6993a76292faaac70  e458-full-debug.log
d2a434b9730236b102f9de183435890b51a09394b0e6f180e8f1641d0ed1eb8b  e458-full-debug.run.json
dc1a319e1e84c8cfcc02f57017949aac31c0e4a4ac87c47ccc24f55c1995a4e0  e458-full-safe.log
8001ed6a0d5dbd71f9b9aa54b89e2b8e13ae672d11f570cd64b5b9ef896184c0  e458-full-safe.run.json
```

Lane: codex-avatar-gui
