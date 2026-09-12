# Decode Error Ownership WIP

Base: `81959a3f735e853dbb73caeec42b4084e4b0fc72`.

Status: bounded focused retry pending at this fixture-order checkpoint. Initial
340078b compiled and ran focused Debug: 16 passed, 2 failed, 18 collected (16
named plus two import tests). The valid-message control and its allocation sweep
failed at expected scalar 6, found 0. The identical positive fixture reproduced
that specific failure against untouched 81959a3f: 2 passed, 1 failed, 3 collected.
No blanket base attribution follows from this single controlled comparison.

The unmatched-oneof descriptor-order bug remains open and unfixed in
https://github.com/kuyog/zig-protobuf/issues/2 . This ownership fixture explicitly
places its ordinary scalar before its oneof in both declarations and descriptors.
Wire bytes and all assertions are unchanged; the known-RED fixture stays in
340078b. Runtime ownership/length code is unchanged by this checkpoint. No full
tests, other modes, formatter, mutations, corpus replay or consumer repins have
run. This is a tracked fork, not a modified dependency cache.

## Defect And Ownership

`wire.decodeRepeated` previously saved list capacity and passed it to
`shrinkAndFree` during error cleanup, after restoring the previous item length.
That API takes a new length. Spare capacity therefore violated its precondition
and could panic instead of returning the original decode error.

The repair retains capacity and rolls back only appended elements. The existing
repeated-child error cleanup still deinitializes the failed child before its
list entry is removed. Newly present optional lists release their retained
allocation before restoring null; previously present lists stay caller-owned.
The existing optional repeated caller now unwraps the list like the packed
caller, and optional scalar-list deinit mirrors non-optional scalar-list deinit.

Both repeated length-delimited branches reject negative lengths before unsigned
conversion. `protobuf.decode` owns its initialized result until success and now
deinitializes it on failure. Direct `wire.decodeMessage` callers still own their
value on both success and failure; this change does not free their retained
fields. No stronger failure-atomic guarantee is introduced for message merges.

## Planned Gates

Run only after the build owner releases the slot. Record the exact fork SHA,
compiler version, commands, exit status, test-name set, totals and allocation
failures. Use isolated output/cache paths and one gate at a time.

```sh
cd /absolute/path/to/zig-protobuf-decode-errors
zig fmt --check src/protobuf.zig src/wire.zig src/decode_error_test.zig
zig test src/protobuf.zig -O Debug --test-filter 'decode ownership:'
zig test src/protobuf.zig -O ReleaseSafe --test-filter 'decode ownership:'
zig test src/protobuf.zig -O ReleaseFast --test-filter 'decode ownership:'
zig build test -Doptimize=Debug -j2 --summary all
zig build test -Doptimize=ReleaseSafe -j2 --summary all
```

Sixteen named source tests are imported through the existing root test block:
owned-field positive control; later scalar EOF; successful-message allocation
failure sweep; repeated-child allocation failure sweep; merged inline/pointer/
oneof failure sweep; retained repeated-child rollback and subsequent successful
append; packed scalar EOF; repeated string EOF; packed scalar overrun; invalid
packed enum; three negative-length branches; two optional-list rollback sweeps;
and valid optional-list ownership. `checkAllAllocationFailures` must observe
OOM as OOM, not swallow it as the intended malformed-input error. Heap allocator
leak/double-free detection is required, not only fixed-arena decoding.

## Isolated Mutation Plan

Restore the complete exact source between arms and inspect the diff before and
after every run. Keep the same focused test collection; a panic is a failed arm,
never typed refusal. Record causal failing names rather than guessing counts.

1. Restore the old capacity-based `shrinkAndFree` errdefer. Spare-capacity child,
   scalar and enum rollback checks must fail at held collection.
2. Remove only the packed negative-length check. Its named negative packed
   test must fail; do not also remove the ordinary repeated check.
3. Remove only the ordinary repeated negative-length check. Named repeated
   child/string negative tests must fail.
4. Remove only top-level `decode` error deinit. Later-failure and allocation
   sweeps must expose leaked earlier owned fields.
5. Remove only the new optional packed-list storage cleanup, then restore and
   separately remove optional repeated-list storage cleanup. Each corresponding
   named rollback allocation sweep must report leaked storage.
6. Remove only failed repeated-child deinit. The truncated-child heap tests must
   expose leaked child content while retained content remains unchanged.

No mutation has been applied or run for this WIP checkpoint.

## Consumer Corpus Boundary

The motivating private consumer uses the shipping canonical world decoder in
ReleaseSafe. A 24,622-byte real frame decoded successfully. Its first 12,311
bytes, with length and digest metadata intentionally recomputed, crashed instead
of returning a typed decode error. At byte 12,290, field 2 declares a 23-byte
player submessage (player ID 497), but only 19 bytes remain. This is a malformed
canonical-input refusal test, not an authentication-bypass claim.

The original frame SHA256 is
`68e5cd35c9cfea09fc1b7b98075e82686fd98b87d584ba430596239513037597`.
The preserved truncated SHA256 is
`e0d8669d5d1f41eec1247b22a4960015738372b97387ca53c0a4a972a9610bbf`.
Private corpus bytes/metadata are not published in this public fork. The private
handoff records their absolute paths and exact consumer build/replay commands.

Later, in a separately authorized isolated consumer checkout, use the committed
fork through a normal immutable dependency pin, not a cache edit. Rebuild the
same shipping verifier in ReleaseSafe with its real module graph. Require all
16 originals to retain their VERIFIED metadata and final CORPUS_VERIFIED marker.
Require the preserved truncated input to exit 1 with InvalidPayloadLength and
no success marker, signal, panic, timeout, or partial-result substitution.
Replay the remaining seven adverse controls unchanged. Repeat the corpus refusal
in Debug and ReleaseFast after package ownership gates pass.

Consumer repins, corpus replay, independent cross-review, upstream submission,
and full consumer gates remain pending. No merge or deployment claim.
