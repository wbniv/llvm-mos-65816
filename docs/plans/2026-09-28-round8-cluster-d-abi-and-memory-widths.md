# Round 8 Cluster D (#156–#160) — ABI shapes and extending loads

This cluster builds the five remaining Round 8 tests. It keeps publication out of scope and requires
host/target result agreement, both emulator runs, and machine verification for every tested target mode.

## Paths and gates

| Demo | Contract under test | Gate |
|---|---|---|
| #156 `vawidth` | Variadic retrieval of promoted 8-bit, native 16-bit, 32-bit, 64-bit, and pointer values | Every slot is consumed in order; the folded value agrees with the host. |
| #157 `sretrec` | Recursive return of a record larger than the direct-return threshold | Each recursive frame produces and folds a record result; IR keeps the hidden sret result and self-call. |
| #158 `arityfan` | Runtime indirect calls through correctly typed function pointers with one through four arguments | Every signature is called; the object contains indirect-call dispatch. |
| #159 `extload` | Signed and unsigned loads extended across every wider width pair | Both `G_SEXTLOAD` and `G_ZEXTLOAD` reach legalization; volatile source values keep loads observable. |
| #160 `ascast` | Repeated near-to-far address-space casts followed by a runtime dereference | The far path is checked in `+mos-a16`, which can represent its 32-bit pointer; the host and both emulators agree. |

The first four use the normal corpus differential in default, `+mos-a16`, and `+mos-xy16` modes. #160
uses a dedicated `+mos-a16` gate because the far pointer is a 32-bit target value and is not valid in
the default mode. Each demo also has an SNES ROM and a structure check so the test reaches its named
compiler path.

## Prior-work reconciliation

The #154 mixed-width pointer and call register-allocation failure has a canonical investigation at
[`2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md`](../investigations/2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md).
Its recorded original failure was repaired by patch 0029 and validated against the same input; the
September 16 open-status text is retained as historical evidence. #159's extending-load worklist
failure has a separate canonical record at
[`mos-farblit-byte-load-legalization.json`](../defects/mos-farblit-byte-load-legalization.json) and
was repaired locally by patch 0066. These are prior fixes to keep in mind if a new cluster input
fails; neither is treated as a new finding without matching-input evidence and causal reconciliation.

Before any defect claim, preserve the exact new source and preprocessed input, compiler identity,
command, diagnostics, and relevant IR/MIR. Search the responsible ABI or legalizer operation and
reconcile structured defects, earlier reports, plans, patches, Git history, and live source. Keep a
failure as not reproduced or unresolved unless the same input proves the cause and repair.

## Verification

Each named runner builds its ROM and runs the dedicated host differential, default/A16/XY16 checks
for #156–#159, `+mos-a16` for #160, machine verification, MAME, and bsnes-jg. This keeps verification
focused on all five new inputs; `dev/title-charset.sh` checks the added title strings.

**PASS — 2026-09-28:** all five named gates, machine-verifier checks, emulator checks, and title
character checks passed. Detailed values and structural counts are recorded below.

## Results (2026-09-28)

| Demo | Host value | Structural gate | Result |
|---|---:|---|---|
| #156 `vawidth` | `0x3D17` | `G_VASTART=1`, 7 argument loads; verifier clean in default/A16/XY16 | host/default/A16/XY16 match; MAME and bsnes-jg pass |
| #157 `sretrec` | `0x01AB` | three sret results and three recursive calls; verifier clean in default/A16/XY16 | host/default/A16/XY16 match; MAME and bsnes-jg pass |
| #158 `arityfan` | `0xA09E` | eight typed indirect calls; verifier clean in default/A16/XY16 | host/default/A16/XY16 match; MAME and bsnes-jg pass |
| #159 `extload` | `0xF97F` | six `G_SEXTLOAD` and six `G_ZEXTLOAD`; verifier clean in default/A16/XY16 | host/default/A16/XY16 match; MAME and bsnes-jg pass |
| #160 `ascast` | `0xF1BD` | two `G_ADDRSPACE_CAST`; verifier clean in A16 | host/A16 match; MAME and bsnes-jg pass |

Every runner also built its named SNES ROM. MAME reached the result at the 1,000-tick settle limit;
bsnes-jg reached it at frame 600. The first `vawidth` attempt used the MAME default 60-tick limit
and read zero; the gate was rerun with the corpus 1,000-tick budget and passed. The full unrelated
83-entry `corpus-a16` sweep was stopped after three existing entries passed; the five new corpus
inputs were each checked by their own differential runner. The full example build sweep was not run.

`dev/title-charset.sh`: 147 title call sites checked; all title characters have glyphs. The five
demo sources and gates are published on the compiler repository's `main` branch; the open-source
dashboard was refreshed separately from that published compiler revision.
