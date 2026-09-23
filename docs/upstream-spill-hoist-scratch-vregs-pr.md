# [CodeGen] Do not hoist a spill whose re-emission needs new virtual registers; drop MOS's blanket `-disable-spill-hoist`

`llc -O2 -mtriple=mos` crashes on ordinary C (release: segmentation fault in
Machine Copy Propagation; assertions: `Remaining virtual register` in the
virtual-register rewriter) whenever greedy's global spill hoisting fires on a
function that uses the soft stack. `HoistSpillHelper::hoistAllSpills` runs after
the allocation queue has drained and re-emits merged spills through
`TargetInstrInfo::storeRegToStackSlot`. MOS's soft-stack spill is an `STStk`
pseudo whose frame address lives in a scratch `Imag16` *virtual* register that
frame-index elimination later materialises, so every hoisted spill mints a new
virtual register that nothing allocates any more.

The `mos-clang` driver has been hiding this since the beginning by passing
`-mllvm -disable-spill-hoist` on every compile (`CommonArgs.cpp`), which also
switches the optimization off for every function where it is safe, and does
nothing for `llc`, `opt`-driven pipelines, other frontends, or LTO links that do
not forward the flag. Nine of the twelve gcc C-torture files that hit this at
`-O2` crash the release compiler outright.

Make the hoister refuse a group whose re-emitted spill introduces virtual
registers other than the spilled one: the inserted instructions are removed,
their intervals dropped, and the original spills kept. Targets whose spill hook
emits plain stores are unaffected (no register is introduced, so nothing is
refused); MOS keeps hoisting for spills that need no scratch and falls back to
the unhoisted spills for those that do. With that, the driver's blanket flag
is removed.

The alternative the driver comment sketches, telling the target hook that it
may not create registers and scavenging instead, would need a scavenger at a
point where none runs; refusing the hoist is the minimal safe change and keeps
the decision inside the pass that made it.

Validated on llvm-mos `742d554bf08042b8df93d791c335260fadd16643` (identical to
`main` at the time of writing) with assertions enabled:

- The reduced test (`gcc.c-torture/execute/950714-1.c` through `llvm-reduce`
  to one 49-line function) aborts the unpatched `llc -O2` and passes with the
  change; it also passes with `-disable-spill-hoist`, so both paths are pinned.
- All twelve c-torture files that hit this (`950714-1`, `arith-rand`,
  `arith-rand-ll`, `ashrdi-1`, `bitops-1`, `minmaxcmp-1`, `pr110666-1`,
  `pr68250`, `shiftdi-2`, `stdarg-2` at `-O2`; `pr91450-1`, `pr91450-2` at
  `-O0`) compile with the verifier clean; on `950714-1` two hoist groups are
  refused and the others still hoist.
- MOS CodeGen and MC suites: 135 pass, 1 unsupported.
- The gcc `c-torture/execute` corpus (1,390 files compiled to IR by the pinned
  Clang) at `-O0`, `-O2` and `-Os` through the patched `llc`, hoisting enabled,
  compared with the same `llc` under `-disable-spill-hoist` (what the driver
  flag gave): no compilation newly fails or newly succeeds; 16 compilations
  change, and their `.text` shrinks by 4,510 bytes (290,375 to 285,865), none
  grows. Every function in that corpus is on the soft stack (Clang's IR carries
  no `nonreentrant` attribute there), so this is the pessimistic case for the
  guard.
- The complete `test/CodeGen/{X86,ARM,AArch64}` suites, since the change is in
  generic code: 11,459 tests, 11,361 pass and 23 expectedly fail, no
  failures (75 first-pass failures were unbuilt helper tools and pass once
  those are built), so no other target's behaviour changes.
- Downstream, the project's SNES corpus (each program's result compared across
  the host oracle, the default build and two accumulator-width modes on MAME
  and bsnes-jg) with the toolchain rebuilt without the driver flag:
  79 of 79 programs pass (host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg), 0 fail, 0 xfail.



Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the diagnosis, implementation, test, validation, and PR
drafting.
