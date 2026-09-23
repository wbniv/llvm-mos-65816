# Patch 0038: `llvm.returnaddress` / `llvm.frameaddress` on MOS

Found 2026‑09‑23 in the c-torture triage (order 3 in the
[triage table](../../upstream-pending-work.md#backend-failure-triage-gcc-c-torture-2026-09-23)):
neither intrinsic was legalized (15 compilations: `20010122-1`, `20030323-1`, `20030811-1`,
`pr17377`, `frame-address`). Design and semantics:
[plan](../../plans/2026-09-23-return-frame-address.md); submission text:
[PR draft](../../upstream-return-frame-address-pr.md).

- [x] Frame address (level 0): fixed frame object at offset 0 = incoming soft stack pointer,
  through the existing frame-index lowering; no frame pointer forced.
- [x] Return address (level 0): `G_RETURN_ADDRESS_BYTE` ×2 in place → `ReturnAddressByte`
  (`Ac` + `Xc` scratch) / `ReturnAddressByteSR` (65816) → expanded by the new
  `MOSLowerReturnAddress` pass (end of `addPreSched2`) with the hard-stack depth from a forward
  dataflow over the CFG; `+1` except on SPC700. Levels above 0 and interrupt handlers: `0`.
- [x] First cut (read pinned to the entry block, entry-block walk only) failed on `pr17377`:
  later lowering splits the entry block (`%ir-block.1` in several MBBs), so the pseudo landed
  outside it. Replaced by the per-block dataflow; the read stays where the intrinsic was.
- [x] Tests: `llvm/test/CodeGen/MOS/return-frame-address.ll` (mos6502 `-O0`/`-O2`,
  mosw65816 `-O2`), `llvm/test/CodeGen/MOS/return-address-spc700.ll`.
- [x] Patch `patches/llvm-mos/0038-mos-return-frame-address.patch`, generated in the
  upstream-shape tree; applied to `vendor/` with `-C1` (four registration hunks neighbour 0002's
  REP/SEP lines); `dev/toolchain.sh` and `dev/regen-patch.sh` carry the same flag.
- [x] Suites, corpus differential, project toolchain rebuilt, torture filter, emulator gate,
  torture execution runs (below).

## Results

Builds: `build/newton-postra-src` (pinned upstream `742d554` + 0011, 0030–0037 as a baseline
commit `ab63d45f`, then this change), assertion-enabled, built in the container as
`build/newton-postra-build` with the source mounted at its cached path
(`-v build/newton-postra-src:/work/build/register-exhaustion-src`; the copied build directory's
CMake cache had to be repointed at itself first, which forced a wide rebuild and left
`build/0029-cross-target-build`'s generated files regenerated against this source).
`build/0030-claude-review/llc-final` (sha256 `6b5cfbb41c42f201…`) is the last binary without the
change; `llc-0038` (`e849c7a80e79a815…`) the one with it. Project toolchain:
`build/llvm-mos-install/bin/clang-23` sha256 `3ec66f254488e9f1…`, rebuilt 18:53 (mtime advanced
from 12:26).

| Check | Result |
|---|---|
| Both tests on `llc-final` | FAIL: `unable to legalize instruction: %0:_(p0) = G_INTRINSIC intrinsic(@llvm.returnaddress), 0` |
| Both tests on `llc-0038`, every RUN line, `-verify-machineinstrs` | PASS (3 + 1 RUN lines) |
| The 5 torture files at `-O0/-O2/-Os` as IR through `llc-0038` with the verifier | 15/15 clean (including `pr17377`, the split-entry-block case) |
| c-torture, 1,390 accepted files × `-O0/-O2/-Os`, `llc-final` vs `llc-0038` (`diff9`) | 15 repaired (the five files, all levels); 0 newly failing; 36 fail on both sides; 4,119 ok/ok pairs, all byte-identical |
| MOS CodeGen + MC lit suites, `llc-0038` | 143 pass, 1 unsupported, 0 fail |
| Project `mos-clang` on the 5 files: mos6502 (3 levels), mosw65816 with and without `+mos-a16` (3 levels each), `-verify-machineinstrs` | 45/45 |
| `dev/regen-patch.sh` round trip | PASS; `grep -c ReturnAddress 0002` = 0 (0038 stays standalone). The regenerated 0002 also picked up another worker's in-progress `MOSRegisterInfo.cpp` liveness hunks and `scavenger-p-undef.mir`, so 0002 was restored to its pre-regen state and is not part of this commit |
| `tools/torture_filter.py` (host build, `-Os`) | `20010122-1`, `frame-address`, `pr17377` move from `link-other` into scope. The scope file dated from 2026‑06‑26, so the rerun also reflects the patches since: the six `builtin-prefetch` files (0034/0035) and `20031012-1` move in; `20021120-1` (ROM overflow), `multi-ix` (now "Stack pointer decrement too large", the known cleanly reported limit) and `ashrdi-1` move out |
| `ashrdi-1` | greedy RA segfault (`SplitEditor::enterIntvAfter`) on `constant_shift`, `mosw65816 -Os`, project toolchain only; the same IR is clean through `llc-final` and `llc-0038` at `-O0`/`-O2`. Vendor-state defect, tracked in `TODO.md` (T4); a vendor build without 0038 was not made |
| SPC700 | `-O2` on a function that loads an immediate into an imaginary register crashes in `MOSLateOptimization::combineLdImm` on `llc-final` and `llc-0038` alike (null `Load`). That is the defect patch 0003 fixes (open PR [#584](https://github.com/llvm-mos/llvm-mos/pull/584)); the isolated validation stack omits 0003, the project toolchain carries it and compiles the shape. The SPC700 test does not need to avoid it; its comment was corrected on 2026‑09‑24 and the patch file regenerated (test comment only) |
| Emulator gate `dev/run.sh corpus-a16` (started 19:31, the laptop suspended 19:43–01:45 in the middle of it, finished 01:57) | 79 of 79 programs pass (host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg), 0 xfail |
| Torture execution, the 5 files, `dev/run.sh torture --tests …` (`-Os`, host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg) | `20010122-1`, `20030323-1`, `20030811-1`: PASS, all variants (0x600D). `pr17377`, `frame-address`: SKIP, the default build self-checks FAIL (0xDEAD) — target-inappropriate, see below |

**Why the two skips are the tests' premises, not the values** (instrumented copies in
`build/0030-claude-review/probe-0038/`, run on MAME through the same shim by `probe.py`):

- `pr17377`: the failing check is `y(0) != v`; the two return addresses read inside `f` are
  `0x80A3` and `0x80CA`. The SNES build is whole-program optimized: the global `x` has no
  readers, so `y`'s `x++` dies and `y` becomes a 3-byte tail jump (`y: jmp f`), which is exactly
  the sibling call the test says must not happen (its `__noclone__` is unknown to clang). `f` is
  therefore entered from `main`'s five `jsr y` sites, and the two values are precisely the return
  addresses of the `jsr y` at `0x80A0` and `0x80C7` (`+3`). The read itself is `lda 1,s` /
  `lda 2,s` plus one, at depth 0, in the linked ROM.
- `frame-address`: `check_fa_work` returns 0 because the locals it compares are zero-page
  statics (`c` at `0x0020`, `d` at `0x0021`; the constant-size `alloca` in `main` became static
  as well), while `__builtin_frame_address(0)` is the incoming soft stack pointer, `0x2000`, which
  nothing had moved. The test assumes locals live on the same stack as the frame address; on MOS
  with the static stack they do not.

The generated code (mos6502): `tsx ; lda 257,x` / `tsx ; lda 258,x` for the two bytes, then the
16-bit increment; after a callee-saved push the offsets become 258/259. 65816: `lda 1,s` /
`lda 2,s` (2/3 after a push). SPC700: `mov x,s ; mov a,257+x`, no increment. Frame address:
`ld? __rc0 / __rc1`, or `lda __rc0 ; adc #16` with a 16-byte frame.

Artifacts under `build/0030-claude-review/`: `diff9.py` / `diff9-results.json` / `diff9/`,
`suite-0038.out`, `build-0038*.log`, `cmake-0038.log`, `toolchain-0038.log`,
`torture-filter-0038.log`, `inscope-before-0038.tsv`, `unsupported-before-0038.tsv`,
`regen-0038*.log`, `0002-before-regen-0038.patch`, `corpus-a16-0038.log`.
