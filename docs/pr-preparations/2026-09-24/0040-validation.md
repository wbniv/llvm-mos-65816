# Patch 0040: `InlineSpiller::coalesceStackAccess` must not erase a scratch-vreg access

Found 2026‑09‑23 when `tools/torture_filter.py` was re-run for patch 0038: `ashrdi-1` dropped
out of scope with a greedy-RA segfault in `SplitEditor::enterIntvAfter` on `constant_shift`
(`mosw65816 -Os`). Root cause, hypotheses and the rejected alternative:
[plan](../../plans/2026-09-24-ashrdi1-greedy-ra-segfault.md); submission text:
[PR draft](../../upstream-inline-spiller-coalesce-scratch-vregs-pr.md).

- [x] Reduced the crash with `llvm-reduce` from the 446-line `-Os` module to a 96-line
  `@constant_shift` (48-case switch → jump table, seven `ashr i64` arms).
- [x] Established the blast radius: **not** `+mos-a16`-specific and not 65816-specific.
  `mos65c02` reproduces on the reduced case; `mos6502` escapes by pressure, not by design.
  Requires the jump table (`-min-jump-table-entries=1000` → clean) and greedy
  (`-regalloc=basic` → clean).
- [x] Assertion `llc` built from the **live vendor state** into a new `build/0040-ra-build`
  (Release + `LLVM_ENABLE_ASSERTIONS=ON`, `LLVM_TARGETS_TO_BUILD=X86`,
  `LLVM_EXPERIMENTAL_TARGETS_TO_BUILD=MOS`), source `build/0040-ra-src` = detached worktree of
  `vendor/llvm-mos` at `8be0546128a5` + the working-tree `llvm/lib/Target/MOS/` + the 29
  modified non-MOS files. Deliberately not `build/newton-postra-build` (in use by another agent).
- [x] Root cause: MOS's reload hook mints an `Imag16` scratch pointer as an extra virtual def;
  `coalesceStackAccess` then erases that reload, orphaning the already-assigned scratch register
  and leaving a phantom interference over a `SlotIndex` with no instruction.
- [x] Fix: decline to coalesce an access carrying virtual defs other than the spilled register.
  Patch `patches/llvm-mos/0040-llvm-inline-spiller-coalesce-scratch-vregs.patch`, registered in
  `dev/toolchain.sh` after 0037. **No** `dev/regen-patch.sh` entry needed (`STANDALONE_MOSDIR`
  covers only `llvm/lib/Target/MOS/`; `TESTRELS` is an explicit allow-list; neither of the two
  files qualifies, so a 0002 regen cannot absorb it).
- [x] Test `llvm/test/CodeGen/MOS/inline-spiller-coalesce-scratch-vreg.ll`
  (`mos65c02` + `mosw65816`, `-verify-machineinstrs`).
- [x] Project toolchain rebuilt, lit suites, c-torture codegen differential, corpus differential,
  torture filter, emulator gate (below).

## Builds

| Binary | sha256 (first 24) | What it is |
|---|---|---|
| `build/0040-ra-build/llc-before-0040` | `60968c143e75c4fe918d82ea` | full vendor state, **0040 hunk removed** |
| `build/0040-ra-build/llc-0040` | `a1e807cb50a3b26af78545ed` | same source **with** 0040 |
| `build/llvm-mos-install/bin/clang-23` | `e41a1d72d04d13c3028629ea` | project toolchain, rebuilt 03:22 (mtime advanced from 2026‑09‑23 18:53) |

Host build dirs: source `/home/will/llvm-mos-65816/build/0040-ra-src`, build
`/home/will/llvm-mos-65816/build/0040-ra-build`, mounted in the container at
`/work/build/0040-ra-src` and `/work/build/0040-ra-build` (no aliasing; `dev/container.sh`
mounts the repo root only).

## Results

| Check | Result |
|---|---|
| Attribution bisection (MOS dir reset to pristine, subsets rebuilt in `build/0040-ra-build`) | `0001` only: rc=0 on all three CPUs. `0001` + **HEAD-committed** `0002`: rc=134 on `mos65c02`/`mosw65816`. Full live MOS dir: identical. So the other worker's in-progress `MOSRegisterInfo.cpp` hunks and every standalone patch (0003, 0010, 0018–0038) are **excluded**; 0002 is the pressure trigger, not the cause |
| Reduced test on `llc-before-0040` | **FAIL** — `mos6502` rc=0, `mos65c02` rc=134, `mosw65816` rc=134, `SplitKit.cpp:746: Assertion 'MI && "enterIntvAfter called with invalid index"'` |
| Reduced test on `llc-0040`, `-verify-machineinstrs` | PASS — `mos6502`/`mos65c02`/`mosw65816` all rc=0 |
| Pre-greedy MIR replay (`-start-before=greedy`) on `llc-0040` | PASS (rc=0) |
| `ashrdi-1.c` through the project `mos-clang`, `-mllvm -verify-machineinstrs`: `mosw65816` × {`-O0`,`-O1`,`-O2`,`-Os`} × {default, `+mos-a16`} + `mos6502` × 4 + `mos65c02` × 4 | **16/16 rc=0** (was 1 segfault at `mosw65816 -Os` default) |
| MOS CodeGen + MC lit suites, project `build/llvm-mos` | 152 discovered; **13 fail → 9 fail**. The 4 repaired are the new test plus `inline-asm-indirect-output.ll`, `return-address-spc700.ll`, `return-frame-address.ll`, which only failed because `build/llvm-mos/bin/llc` was stale (2026‑09‑23 07:37 — `dev/run.sh toolchain` builds and installs the clang targets, not `llc`); rebuilt to 03:26. The remaining 9 fail identically before and after and are the known vendor-vs-upstream CHECK divergences (`indexiv`, `indvar-simplify-20230930`, `leaf-20231021`, `legalizer.mir`, `nonreentrant{,-nointerrupts}`, `scavenger-p-undef-6502`, `shift-rotate`, `addressing-modes-65816.s`) |
| c-torture codegen differential, all 1,656 `execute/*.c` → IR with the project frontend at `-Os`, then `llc -O2 -mcpu=mosw65816` on both binaries (`build/0040-ra-build/diff0040/results.txt`) | **1,364 byte-identical**, **1 repaired** (`ashrdi-1`, rc=134 → rc=0), **1 changed**, **0 newly broken**, 24 fail on both sides, 266 rejected by the frontend |
| The one changed file, `960215-1` | Stack-slot permutation only — `ldy #46/dey/dey` → `ldy #45/iny/ldy #44` and the mirrored reload. Assembled `.text`: **2,541 → 2,542 bytes (+1)**. No extra load or store; the guard did not fire here, the slot numbering shifted |
| The 24 both-side failures | 5 assert (`multi-register tied operands not supported in GlobalISel inline asm` ×2, `invalid extend/trunc`, `vectors should be built with G_CONCAT_VECTOR…`, `multi-ix`), 19 exit 1. All pre-existing and unrelated |
| `dev/run.sh corpus-a16` (79 programs, default == `+mos-a16` == `+mos-xy16`, MAME + bsnes-jg) | **79/79 passed, 0 xfail** (`build/fuzz-work`, `build/fuzz-triage` cleared first) |
| `tools/torture_filter.py` (host build, `-Os`) | `ashrdi-1.c` **back in scope**. The diff is exactly one line per file and nothing else: `inscope.tsv` 1,298 → 1,299 lines, sole change `+ashrdi-1.c`; `unsupported.tsv` 486 → 485, sole change the removal of `ashrdi-1.c  link-other  "PLEASE submit a bug report…"`. No other file moved in either direction, so there is nothing further to explain |
| `dev/run.sh torture --tests ashrdi-1.c` (`-Os`, explicit, default == `+mos-a16` == `+mos-xy16`, MAME + bsnes-jg) | **PASS** — `ashrdi-1.c  PASS  all variants PASS (0x600D)`; 1 PASS, 0 FAIL, 0 SKIP, 0 XFAIL |
| Patch order-independence | `git apply --check` of 0040 onto pristine + 0033 succeeds, and 0033 still applies cleanly after 0040 |

## Files this change touches outside the worktree

Running `tools/torture_filter.py` from the main checkout regenerated two tracked files in place:
`examples/65816/torture/inscope.tsv` and `examples/65816/torture/unsupported.tsv` (both clean at
session start). The same content is committed on the branch; the main checkout's copies are the
regenerated artefact of the fixed toolchain and were deliberately not reverted.

## Residual risk

- The regression test is a reduced `.ll` whose value depends on greedy still reaching a specific
  spill-then-split sequence; a future codegen change could stop exercising the path without the
  test failing. A `.mir` test pinned at `-start-before=greedy` would be more targeted but is
  1,300 lines and brittle in a different way. The guard is also covered indirectly by the
  c-torture differential.
- `coalesceStackAccess` is the only unguarded erase site today (see the plan's table of all four).
  The narrower question — whether `LIS.removeInterval` on an *already assigned* register can leave
  a stale `LiveRegMatrix` entry on the dead-def path — applies equally to upstream and was not
  provoked by 1,656 c-torture files, 79 corpus programs or the lit suites. Confirming it would
  need a targeted MIR probe.
- `mos6502` never reproduced, before or after. It escapes on register pressure, not by any
  structural difference, so the 6502 leg is not evidence that the path is unreachable there.
