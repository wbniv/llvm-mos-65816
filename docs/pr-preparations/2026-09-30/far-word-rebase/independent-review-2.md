# Second independent review of the carried #320 split and the far-word packet

October 1, 2026. **Do not file 0069/0070 yet, even once #594 is decided.** The carried repairs for B1, B2, B3 and B6 are sound, the N3/N4 changes are behaviour-neutral, the hand-resolved far-word patch 12 carries exactly the reviewed semantic change, and the 0070 per-level table matches the recorded evidence. Two new blocking defects remain in the prerequisites. **B8:** the B4 repair covers only the runtime-index fold. Three other far fold sites (#320‑2 absolute long, #320‑4 displacement window, far-word patch 5 absolute indexed) still leave dangling `DBG_VALUE`s. The simplest `-g` far struct-field access (`base + 1`) therefore fails `-verify-machineinstrs` at every optimization level on #320‑4 and on the packet tip. **B9:** #320 does not stand alone. Imag32 quad spill support arrives only in far-word patch 10, so every #320 commit from #320‑2 on asserts when four far pointers are live across a call. B5 and B7 were not re-reviewed. On October 1 the user chose to build on #594 (option 1 in [the #594 coordination draft](../../2026-10-01/594-comment.md)), but that change is not yet in the series.

## Exact scope

| Item | Identity |
|---|---|
| Split source (read only) | `build/split-320-321/source`, branch `split-320-321-carry` |
| #320 commits | #320‑1 `abfb29168fca`, #320‑2 `3576ad627b5b`, #320‑3 `eab4edb9dc32`, #320‑4 `59d98c37ab77` on `25c40909b44a`; pre-carry `42785c3bef21`..`1a616f08ea67` (branch `split-320-321`) |
| Far-word packet | patches 5–14 = `0615a683bee7`..`a5515aab9219` (branch `pkt-c-far-word`); exported as `patches-split/0019`–`0032` |
| Destination | upstream `llvm-mos/llvm-mos` main is still `06bc967d2668` (public API, October 1, 2026) |

Frozen tools used, all from `build/split-320-321/llc/` (assertion builds):

```text
2f5c17683f93825767f9d4888ab6a15c929e9508ef2817c3267f9199e14d39a7  p-321-00  (upstream base 06bc967d2668)
053193836fc67412772a1511a15f21ab2190050e5f84f1a1c61fcb9d62de778c  p-320-02  (pre-carry #320-2)
9176eb386b7a66274b55ef51de469791474654ad7f5f33c0ed1e9f03fd94b896  p-320-03  (pre-carry #320-3)
5b7d45e7da478195c8e597867b0b0a8ae53126227e3265787ac6fe199549825f  p-320-04  (pre-carry #320-4)
d5022893511ee122a51bccd6b908a0055ecf61b3eb54c57fecb82fd8efd5314d  c-320-01
58540bdeab7b6ef59ff4180b8008873864cb3cb8af1c0adf95b35c71f9010095  c-320-02
f4ee31914e40af9fb223d6ab150f73987a8b78e67ab72b29472a3036554b0537  c-320-03
bbc982dd14d476d37e192518830ec67cf80b02c14da6e94527a5af97dcb2912e  c-320-04
3626b2ca18d2fd22432a7d1ebcef2b3be633febbe3f49c6c3f4e7d16d439bf06  c-fw-11   (pre-0070, patch 11)
cce5eb24ccd6141172138b662e83cc4beefd7d1aa1f6c6ff71f409ae229bb5c7  c-fw-14   (candidate, patch 14)
```

These match `evidence/carry/stages.tsv`, and each run commit's tree equals its final commit's tree. FileCheck, `not`, `split-file` and `llvm-size` came from `build/split-320-321/build/bin`, and `clang-format` from `build/llvm-mos-install/bin` (built from llvm-mos `8be0546128a5`). No LLVM build was performed. Every `llc` ran under `ulimit -c 0; ulimit -v 2000000` and `timeout`, with at most three in parallel; `coredumpctl` shows `COREFILE none` for every abort. Probes ran from this session's scratch directory. The reproducers that matter are quoted below.

I formed the judgments below from the code, the tests and my own probes before reading [the carry plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md). The plan does not mention B8 or B9.

## Coordinator results verified

| Claim | Independent result |
|---|---|
| `patches-320/` applied to `25c40909b44a` reproduce each #320 tree | Confirmed with `git apply --cached` into a scratch index: trees `4ac7df1b`, `881f4cc1`, `08b702fa`, `c80a2ee1`. Patch 2 adds a blank line at the end of `far-ptr-arg-exhaustion.ll` (`git apply` whitespace warning, N15). |
| The packet's `0019`–`0022` are the #320 patches | Confirmed: the diff bodies are identical to `patches-320/0001`–`0004`. |
| Per-commit suites: #320‑2 166 pass + 1 unsupported; #320‑4 170 + 1; packet tip 179 + 1 | Confirmed with my own RUN-line runner on each commit's own `llvm/test/{CodeGen,MC}/MOS`. The single non-pass is `getchar-regression.ll`, which lit marks unsupported (my runner does not evaluate `REQUIRES`). |
| Pre-0070 `llc` fails exactly four packet tests | Confirmed: `far-word-policy.mir`, `far-word-index-integration.ll`, `far-word-index-boundaries.mir` and RUN 3 (the word half) of `far-index-fold-debug.ll`. |
| Red/green for each carried test | Reproduced one red per B item on the unrepaired commit and green on the carried commit (see "What I re-verified"). |
| B2 changes `.text` only for the eight unprovable lengths: 111→160 bytes (O0) and 92→141 bytes (O2) | Reproduced exactly with `llvm-size` on `far-memop-length.ll`, `p-320-03` vs `c-320-03`, A16. |
| 0070 table: Os/Oz identical, O2/O3 faster | Recomputed from `split-carry-runtime-results.json`. Farblit A16: O2 +9 bytes and 7.25% faster, O3 −21 bytes and 7.07% faster. XY16: O2 +23 bytes and 9.70% faster, O3 −19 bytes and 7.33% faster. Os/Oz objects are byte-identical, and all 58 rows agree across expected, MAME and bsnes, with equal repeats. I rebuilt two recorded objects from the frozen post-LTO IR (default A16 O2 with `c-fw-14`, baseline XY16 O3 with `c-fw-11`), and both sha256s match the record. |
| N3 applied to #320 | `clang-format-diff.py` over each #320 commit's own C++ hunks: 0 lines for each of the four commits. The same run over the pre-carry range `25c40909b44a..1a616f08ea67` reports 172 lines. |

## Contracts checked (the brief's focus items)

1. **B2 known-bits test.** The rule at `MOSLegalizerInfo.cpp:3248-3256` keeps the 16-bit entry when the length type is at most 16 bits, when it is a constant `ule 0xFFFF`, or when `countMinLeadingZeros() >= LenBits - 16`. Each of those implies a value ≤ 0xFFFF, so no length above 65535 reaches a 16-bit entry through this function. A provable length that known bits cannot see (beyond the depth limit, or an opaque call result) only costs a `…_far32` call; that is sound. I probed `urem %n, 1000`, `umin(%n, 65535)` and `lshr %n, 16`, which stay 16-bit, and `zext(i16) + 1` (maximum 65536), which goes to 32-bit. All were correct at O0 and O2. The "narrow wider than 32 bits" branch is unreachable from IR: the generic IRTranslator already `ZExtOrTrunc`s the length to the smallest pointer width in the call (`IRTranslator.cpp:2528-2542`). So the real narrowing happens there, and it also covers mixed address spaces. See N10.
2. **B3 replace-then-diagnose.** A diagnosed load becomes `IMPLICIT_DEF` of its destination, and a store or memop is erased. None of the 15 shapes I tried on `mos6502` at O0/O2 left invalid MIR, and each either got the diagnostic or failed loudly. The shapes covered a volatile i16 load, i32 loads and stores, atomic load and store, `<2 x i8>`, far global, far global indexed, `memcpy.inline`, `memset.inline`, near←far memcpy, two accesses, `-g`, `atomicrmw` and `cmpxchg`; the carried test already covers byte, zext and sext accesses. `atomicrmw` and `cmpxchg` on `addrspace(2)` and `memset.inline` at O0 do not reach the hook; they fail with "unable to legalize", which is loud. `memset.inline` fails the same way for a near pointer on the upstream base. Accesses that are split before the custom hook are diagnosed once per piece (N13). No path selected `[dp]` opcodes on a non-65816 CPU.
3. **B4 dead-address walk.** The walk at `MOSLegalizerInfo.cpp:2886-2898` is correct for the path it guards. It starts at the runtime add (`Addr` is `V`'s result after the constant adds are peeled). It follows only `G_PTR_ADD`s based on the current register, and returns as soon as any other non-debug user remains, so it never drops a location that is still live. It uses `use_instructions`, so `DBG_VALUE_LIST` users are also cleared. It cannot skip a debug user of an add on the chain. **The defect is elsewhere:** three other fold sites erase the access and leave a dead constant-offset add that the walk never sees (B8).
4. **B6 pattern.** `MOSInstrLogical.td:1043-1044` is under `HasAccum16`, and the only `G_TRUNC {s16, s32}` legality rule is also A16-only (`MOSLegalizerInfo.cpp:120-124`), so the pattern cannot fire elsewhere. Before the carry, every such trunc asserted in `selectTrunc`, so no better selection is shadowed. In my probes, non-far `trunc i32→i16` (argument, load, volatile load, mul, lshr) is removed by the artifact combiner before selection. The pattern fired only for far-derived values (`ptrtoint` of a far pointer, far→near cast through a PHI). All of them compile verifier-clean in A16 and XY16 at O0 and O2, and the emitted code is correct.
5. **B1 stack slot.** `CCAssignToStack<4, 1>` matches `p2:32:8`. Caller and callee agree in every shape I tried. Five far arguments put the fourth at `fixed-stack` offset 0 and the fifth at offset 4, and the caller stores them at `stack` and `stack + 4`. I also tried a trailing near pointer (takes the free RS1), three near pointers first (RL1 blocked, the third far pointer is stacked), a trailing `i32`, and a far pointer passed variadically through `CC_MOS_VarArgs`. All were verifier-clean in A16 and XY16 at O0 and O2.
6. **N3 neutrality.** After stripping comments and whitespace (and joining adjacent string literals), 8 of the 11 changed library files are token-identical to the pre-carry tip. The other three are the B-fix files. I read the remaining `MOSLegalizerInfo.cpp` hunks: the `legalizePtrAdd` condition reflow, the `mayBecomeCall` case list (same set) and the `createFarMemLibcall` switch restructure are equivalent. The carry's default-mode comparisons (`c-320-03`, `c-320-04`: 90/90 identical) agree.
7. **Standalone commits.**
   - Tests land with their code, and every commit's own suite passes with its own frozen binary.
   - **#320 as a whole depends on far-word patch 10** for quad spills (B9).
   - Inside #320, #320‑2 silently routes far memops to the near runtime until #320‑3 fixes it (N12).
   - Commit message accuracy: #320‑3 says "no length is truncated", which is not true of mixed-address-space lengths (N10). It correctly says the runtime must provide all six `__mem*_far*` entries, but upstream `llvm-mos-sdk` main (`3f6968bbc156`, fetched October 1, 2026) defines **none** of them, not even the three 16-bit ones, and no SDK companion is queued (N11). #320‑2 says a far pointer can be stored as a value on every CPU, which is not true without `+mos-a16` (N14).
8. **Far-word patch 12 (`0030`).** The token-level edits it makes to `MOSLegalizerInfo.cpp` (15 edit hunks) are identical to the pre-carry patch 12 (`9bfc1cc5104f` in `build/far-word-rebase/source`). The hand resolution dropped only formatting, and `far-word-policy.mir` is byte-identical. The word fold goes through the same `tryFarRuntimeIndexFold` walk, so B4's word half is fixed. B8's window path also affects word accesses at O0, where the word fold is not admitted.

**#594 area (B5/B7), for the user's decision.** Nothing new is broken there. The carry does widen the surface that assumes allocatable quads: B1's stack fallback sits behind the RL rule for every MOS CPU, and B6 constrains far-derived trunc sources to Imag32. A #594-style non-allocatable RL would have to revisit #320‑2's calling-convention rule, B1's fallback and the B6 pattern together.

## Findings

| # | Severity | Summary | Location |
|---|---|---|---|
| B8 | Blocking | Dangling `DBG_VALUE` after the other far fold sites: the B4 repair covers only the runtime-index fold | `MOSLegalizerInfo.cpp:2673` (#320‑2), `:2954` (#320‑4), far-word patch 5 absolute-indexed fold |
| B9 | Blocking | #320 is not standalone: spilling an Imag32 quad asserts until far-word patch 10 | `MOSRegisterInfo.cpp:931` `expandLDSTStkImpl`; fix in `cf2e7a5df7fb` (packet `0028`) |
| N10 | Nonblocking | Mixed-address-space memop lengths are still narrowed by the IRTranslator; sound only by LangRef's allocated-object bound, and the #320‑3 message overstates | `IRTranslator.cpp:2528-2542`; #320‑3 message |
| N11 | Nonblocking (process) | Upstream `llvm-mos-sdk` has none of the six far runtime entries; no companion SDK PR is queued | `docs/upstream-contribution-status.md` |
| N12 | Nonblocking | Bisect hazard: at #320‑2 a far memop that is not inlined calls the near `__memset`/`__memcpy` (bank dropped) | #320‑2 `legalizeMemOp` |
| N13 | Nonblocking | The B3 diagnostic repeats once per legalized piece (i32: 4 times, i16 and `<2 x i8>`: twice) | `rejectFarAccessWithoutLong`, `MOSLegalizerInfo.cpp:587` |
| N14 | Nonblocking | "Storing a far pointer as a value stays legal on every CPU" is false without `+mos-a16` | #320‑2 message; comment at `MOSLegalizerInfo.cpp:581-586` |
| N15 | Nonblocking | Residual history tags in #320 test comments; trailing blank line in a #320‑2 test | `far-addressing.ll`, `far-indir-indexed.ll`, `far-ptr-arg-exhaustion.ll` |
| N16 | Nonblocking | Far `atomicrmw`/`cmpxchg` fail "unable to legalize" on every CPU, including 65816 | add to the PR's N7 list |

### B8 — the dangling debug-value defect has more sites than the one B4 repaired (blocking)

Reproducer `field.ll`, with the debug metadata of `far-index-fold-debug.ll`'s `byte.ll` plus a local variable `!17` named `q`:

```llvm
define i8 @walk(ptr addrspace(2) %base) !dbg !10 {
  %q = getelementptr i8, ptr addrspace(2) %base, i32 1
  call void @llvm.dbg.value(metadata ptr addrspace(2) %q, metadata !17, metadata !DIExpression()), !dbg !20
  %b = load i8, ptr addrspace(2) %q, !dbg !20
  ret i8 %b, !dbg !20
}
```

`llc -mtriple=mos -mcpu=mosw65816 [-mattr=+mos-a16[,+mos-xy16]] -O{0,2} -verify-machineinstrs` gives `*** Bad machine code: Generic virtual register use cannot be undef ***` on `DBG_VALUE undef %2:any, $noreg, !"q"`. The emitted code (`ldy #1; lda [__rc4],y`) is correct. The cause: the displacement-window fold (`MOSLegalizerInfo.cpp:2936-2955`) erases the access and leaves `%q = G_PTR_ADD %base, 1` with only a debug use. The legalizer's dead-code sweep then erases it. The generic `salvageDebugInfoForDbgValue` cannot salvage `G_PTR_ADD`, handling only `COPY`, `G_TRUNC` and `G_MERGE_VALUES` (`CodeGenCommonISel.cpp:266-277`), so it leaves the `DBG_VALUE` on the erased vreg. This is the same mechanism as B4, but the carried walk runs only after the runtime-index fold.

| Probe (A16 unless noted) | `c-320-03` | `c-320-04` | `c-fw-14` | Site |
|---|---|---|---|---|
| `field.ll`: runtime base + 1, dbg on `q` (also plain `mosw65816`, and XY16) | pass | **fail O0, O2** | **fail O0, O2** | #320‑4 window |
| `store1.ll`: store through base + 3 | pass | **fail O0, O2** | **fail O0, O2** | #320‑4 window |
| `argoff.ll`: `base + zext(i8 %n) + 1`, dbg on `q` | pass | **fail** (A16; XY16 passes) | **fail** (A16) | runtime fold declined, then window |
| `chain.ll`: loop, accesses at `p` and `p + 1`, dbg on both | — | **fail** (A16 O0/O2, XY16 O2) | **fail O2** (A16, XY16) | runtime fold declined, then window |
| `gfield.ll`: far global + 1 | **fail O0** (also `c-320-02`) | **fail O0** | **fail O0** | #320‑2 absolute long (at O2 the offset folds into the global first) |
| `gidx.ll`: far global `[zext(i8 %i)]` | pass | pass | **fail O0, O2** | far-word patch 5 absolute indexed |
| `word.ll`: word at `p + 2` plus byte at `p` | — | fail | **fail O0** (word fold not admitted at O0) | window |
| B4's own `byte.ll` | — | pass | pass | runtime fold (repaired) |

The near equivalents fail on the upstream base binary `p-321-00` too: `nidx.ll` (`ptr %base` + `zext(i8)`) at `mos6502` O0/O2, and `ngfield.ll` (near global + 1) at O0. So this is a pre-existing upstream llvm-mos defect class. #320 and the packet add new far instances of it, and the displacement-window instance hits the most common `-g` far access at every level. **Fix:** do not patch fold sites one by one. Either (a) make the generic salvage set an unsalvageable debug operand to `$noreg` instead of orphaning it, and salvage `G_PTR_ADD` with a constant offset as `DW_OP_plus_uconst`. That is an llvm-project-level change that also repairs the near shapes and needs its own upstream path. Or (b) add one MOS helper, called after every addressing-mode fold that erases an access, that walks the peeled pointer chain and salvages or drops the locations of adds left with only debug uses. It would replace the B4-specific walk. Add `field.ll`, `store1.ll`, `gfield.ll` (O0) and `gidx.ll` as `-g -verify-machineinstrs` regressions in the commits that introduce each site. `mos-far-index-fold-dangling-dbg.json` stays correct for its own site; B8 needs its own record (or an extension naming these sites) under the defect workflow. Whether the near upstream shapes are reported separately is a separate call.

### B9 — #320 is not standalone: Imag32 spills assert until far-word patch 10 (blocking)

```llvm
declare void @ext()
define i8 @f(ptr addrspace(2) %p0, ptr addrspace(2) %p1, ptr addrspace(2) %p2, ptr addrspace(2) %p3) {
  call void @ext()
  %v0 = load volatile i8, ptr addrspace(2) %p0
  %v1 = load volatile i8, ptr addrspace(2) %p1
  %v2 = load volatile i8, ptr addrspace(2) %p2
  %v3 = load volatile i8, ptr addrspace(2) %p3
  ret i8 %v0
}
```

With `-mcpu=mosw65816 -mattr=+mos-a16 -O{0,2} -verify-machineinstrs`, `c-320-02` and `c-320-04` abort with `MOSRegisterInfo.cpp:931 expandLDSTStkImpl: Assertion 'Loc == MOS::C || Loc == MOS::V || MOS::Anyi8RegClass.contains(Loc)' failed`. So does the pre-carry `p-320-04`. `c-fw-11` and `c-fw-14` compile it cleanly. With three far pointers it passes, because only three callee-saved quads exist (`__rc20`–`__rc31`). A three-pointer loop with three calls (`spill.ll`) and a recursive rotation of three far pointers also abort on `c-320-04`. The spill expansion is far-word patch 10, "Preserve all four bytes when spilling far-pointer quads" (`cf2e7a5df7fb`). Its own message calls it a prerequisite omitted by the first extraction. The split plan ordered #321's spill commit before its first selection commit for exactly this reason, but #320 did not get the same treatment. In a release build the assertion is compiled out, and behaviour was not observed. **Fix:** move patch 10 into #320, in or before #320‑2, the first commit that produces far values. Add a four-live-across-a-call test there. Then re-gate each later commit.

### Nonblocking findings

- **N10 (B2 residual: mixed address spaces).** For `memcpy`/`memmove` with one far and one near (or direct-page) operand, the IRTranslator narrows the length to the smaller pointer width before the legalizer runs. `memcpy.p2.p0(…, i32 70000)` still calls `__memcpy_far` with 4464, `memmove.p2.p0(…, 65536)` is still deleted, and `memcpy.p2.p1(…, 300)` passes 44 (`c-320-04`, A16, O0 and O2). Each is sound only because LangRef bounds an allocated object by the largest signed value of its index type: 32767 bytes for a near object and 127 for a direct-page object. So any length that overflows the narrow type is already undefined behaviour. The code comment says this, but the #320‑3 message says "no length is truncated", and `far-memop-length.ll` has no mixed-address-space case. State the LangRef argument in the message and the PR, and add a mixed-space case (40000 kept, 70000 narrowed) to pin the behaviour.
- **N11 (runtime dependency).** #320‑3 emits calls to `__memset_far`, `__memcpy_far`, `__memmove_far` and their `…_far32` forms. Upstream `llvm-mos-sdk` main `3f6968bbc156` defines none of them; they exist only in this repository's `platforms/snes/mem-far.c`. Any far memop that is not inlined fails to link against the upstream SDK. That failure is loud, but the PR must name an SDK companion, and `docs/upstream-contribution-status.md` does not queue one.
- **N12 (intermediate commit).** At #320‑2 (`c-320-02`), `memset.p2.i16(%d, 7, %n)` becomes `jmp __memset` with the far pointer's low word, a silent wrong-bank write that #320‑3 repairs. Either diagnose far memops in #320‑2 (the B3 hook already exists there) or say in #320‑2's message that far memory intrinsics are unsupported until #320‑3.
- **N13 (diagnostic count).** A far `i32` load on `mos6502` reports the same error four times, and an `i16` load or `<2 x i8>` load twice, because the access is narrowed before the custom hook. This is cosmetic; clang would show duplicate errors at one line.
- **N14 (claim accuracy).** `store ptr addrspace(2) %p, ptr @slot` fails with `unable to legalize … G_UNMERGE_VALUES %2:_(s32)` on `mos6502` and on plain `mosw65816`, and compiles only with `+mos-a16`. That failure is loud, but the #320‑2 message and the `rejectFarAccessWithoutLong` comment say that storing a far pointer as a value "stays legal on every CPU". Say "passing".
- **N15 (N4/N3 residue in tests).** `far-addressing.ll` has "#320 far addressing", and `far-indir-indexed.ll` has "increment 2's" and "increment 1's" (`patches-320/0002` line 909; `0004` lines 742 and 938). `patches-320/0002` also adds a trailing blank line to `far-ptr-arg-exhaustion.ll`.
- **N16 (loud limitation).** `atomicrmw add` and `cmpxchg` on `addrspace(2)` fail with "unable to legalize" in A8 and A16 on `mosw65816`. Atomic `load`/`store` compile to `lda/sta [dp]`. Add the two to the PR's list of unsupported far shapes (N7).

## What I re-verified

`R` is my RUN-line runner. It executes each file's RUN lines with the named frozen `llc` and the split build's tools. Every command ran under `ulimit -c 0; ulimit -v 2000000` with `timeout`.

| B item | Command (test from `split-320-321-carry`) | Unrepaired | Carried |
|---|---|---|---|
| B1 | `R p-320-02 far-ptr-arg-exhaustion.ll` / `R c-320-02 …` | FAIL RUN 1: `Copy Instruction is illegal with mismatching sizes` | PASS |
| B3 | `R p-320-02 far-access-non-65816.ll`; `R p-320-03 …` | FAIL RUN 2: `'<stdin>' is empty` (`llc` accepts the input and prints no diagnostic) | PASS on `c-320-04` |
| B6 | `R p-320-02 far-ptr-trunc.ll` | FAIL RUN 1: `selectTrunc` assertion `getType(From) == LLT::scalar(16)` | PASS on `c-320-04` |
| B2 | `R p-320-03 far-memop-length.ll`; `R c-320-02 …` | FAIL RUN 1: `CHECK: expected string not found` | PASS on `c-320-03`, `c-320-04` |
| B4 | `llc -mattr=+mos-a16[,+mos-xy16] -O2 -verify-machineinstrs byte.ll` | `p-320-04`: rc 134, `Generic virtual register use cannot be undef` in both modes | `c-320-04`: rc 0 in both modes |

Other runs:

- Suites: `R c-320-02` over the 167 test files of `3576ad627b5b`: 166 PASS, plus `getchar-regression.ll` (lit: unsupported). `R c-320-04` over 171 files of `59d98c37ab77`: 170 + 1. `R c-fw-14` over 180 files of `a5515aab9219`: 179 + 1. `R c-fw-11` over the same files: the four expected failures + 1.
- Round trip: `git read-tree 25c40909b44a; git apply --cached patches-320/000{1..4}*; git write-tree` gives `4ac7df1b…`, `881f4cc1…`, `08b702fa…`, `c80a2ee1…`, equal to the recorded trees.
- B2: `llvm-size -A` `.text` on `far-memop-length.ll`, A16: `p-320-03` 111 bytes (O0) and 92 bytes (O2); `c-320-03` 160 and 141 bytes. The callee lists match `b2-levels-callees.tsv`.
- 0070: `c-fw-14 … -O2 -filetype=obj baseline-farblit-a16-O2.sfc.0.5.precodegen.bc` gives sha256 `5283ea31…4633`. `c-fw-11 … +mos-xy16 -O3 … baseline-farblit-xy16-O3…` gives `41b1482b…6641`. Both equal `split-carry-runtime-results.json`. The replay's `runtime-carry/{candidate,pre0070}/llc` are capped wrapper scripts around `c-fw-14`/`c-fw-11`, as `split-carry-replay.json` records.
- `clang-format-diff.py -p1 -binary build/llvm-mos-install/bin/clang-format` per #320 commit: 0, 0, 0, 0 lines; pre-carry range: 172 lines.
- B8 and B9: the probe tables above. Each row is one `llc … -verify-machineinstrs` invocation per binary, mode and level; rc 134 is recorded as fail.

## Status of the first review's findings

The first review numbered its blocking findings B1–B7; there were no B8 or B9 there. B8 and B9 above are new.

| # | First review | Status after the carry |
|---|---|---|
| B1 | Far-pointer arg exhaustion takes an RS pair | **Fixed** in #320‑2. Red/green reproduced; extra shapes clean (five far args, trailing near/i32, varargs). |
| B2 | Far memop lengths > 65535 truncated or deleted | **Fixed** for far-only calls (sound known-bits rule). Mixed-space narrowing remains, justified by LangRef (N10); runtime dependency N11. |
| B3 | Far access on non-65816 CPUs silently emits `[dp]` opcodes | **Fixed** in #320‑2/‑3. No silent path found in 15 shapes; N12–N14 are follow-ups. |
| B4 | Runtime-index fold leaves a dangling `DBG_VALUE` | **Fixed for that site** (byte and word folds). The same defect class remains at three other sites: **B8**. |
| B5 | Malformed far-quad DWARF | **Open**; the user chose #594's numbering on October 1 (option 1), not yet implemented; not re-reviewed. |
| B6 | s32→s16 `G_TRUNC` asserts in `selectTrunc` | **Fixed** in #320‑2; correctly predicated, reached only by far-derived truncs. |
| B7 | Imag32 definitions collide with #594 | **Open**: the user chose option 1 on October 1 (carry #594 as #320‑1a, add allocation as #320‑1b); the coordination comment is drafted, not posted. #594 is unchanged (draft, head `7b80f7e1`, updated August 19). |
| N1 | X16↔Y16 and A16 copies are neither lowered nor costed | Open (far-word patch 9 unchanged). |
| N2 | Patch 11 diff size; one characterization test | Open (patch 11 unchanged). |
| N3 | clang-format | **Fixed for #320** (0 lines per commit); open for #321 and far-word patches 5, 6 and 10. |
| N4 | History tags in comments | **Fixed in #320 library code**; three tags remain in #320 tests (N15); #321 open. |
| N5 | Hidden options; `all` bypasses optnone | Open. |
| N6 | Suite records named container aliases | **Fixed**: `suite-provenance.json` and the carry scripts map the mounts to host paths and hashes. |
| N7 | Loud unsupported far shapes | Open, and still reproduces on `c-fw-14` (far `null` compare O0/O2, far `select` at O0); extend with N16. |
| N8 | Sensitivity runner skips the boundary tests | Open (not rechecked). |
| N9 | Overlap with #593, #601, #585 | Open. Heads unchanged: #593 `06aad6b5`, #601 `76e62666`, #585 `c2fd5d7e`, #603 `fa651f3d`; #605 merged. |

## Verdict for 0069/0070

The optimizations themselves still hold. Patch 8's loop proof is unchanged, patch 12 is semantically identical to the reviewed version, and the size/speed table is reproduced from the evidence. Deciding #594 is not enough to file them, though. Before filing, the prerequisite series also needs:

1. B8 closed across all fold sites, with `-g` regressions.
2. B9 closed by moving the quad-spill patch into #320.
3. The decided #594 alignment (B7) and its numbering (B5), implemented in the series.
4. N11's SDK companion named.

N10 and N12–N16 are text, test or cosmetic fixes that can ride along.

## Limits

- All binaries are assertion builds. For B9 in particular, release behaviour is unknown.
- B8 was not replayed on the downstream release toolchain (`0002`). Whether its near upstream shapes are already reported upstream was not checked, because `gh` is unauthenticated.
- No emulator run was made. The 0070 check re-derived two of the 58 objects and trusted the recorded MAME/bsnes results for the rest.
- My runner does not evaluate `REQUIRES`/`UNSUPPORTED`. I compared counts, not per-test lit statuses, with the recorded lit logs.
- Patches 5–11 and 13–14 of the packet were not re-reviewed line by line. Only their suite results and B8's patch 5 site were checked.
- Nothing was modified under `build/split-320-321/source`, `vendor/` or `patches/`. The round trip used a `--shared --no-checkout` scratch clone.

## Attribution

Second independent review, probes and this record: **Claude Code 2.1.285**, agent type `t4-opus-high` (agent `a86560004d12c0518`), model **`claude-opus-5-5` (Claude Opus 5.5)**, **high** reasoning effort. These were read from this subagent's transcript metadata. The review ran as a subagent of session `310aee67-a99e-4b78-ba48-c560322fe80d` ([session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F)). The carry under review was made by a different subagent (`a7633adfeee82a4f5`) of the same parent session. This reviewer inherited none of its conversation context. The first review, the carry and the original implementation keep the credits recorded in their own documents and commit messages.
