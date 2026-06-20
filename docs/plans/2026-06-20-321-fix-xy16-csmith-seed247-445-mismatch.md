# #321 fix: `+mos-xy16` Csmith runtime miscompiles (seeds 247 + 445)

**Worktree:** execute on **`wt/321-xy16`** (`/home/will/SRC/llvm-mos-65816-xy16`) — xy16 index-register codegen
is that branch's domain; `main`/a16 is untouched. Plan lives in the shared `docs/plans/`. Supersedes the
handoff note [`2026-06-20-321-xy16-csmith-seed247-mismatch-handoff.md`].

## Symptom (two seeds, one signature)

Csmith differential, `+mos-xy16`-only runtime value divergence — a16, DEFAULT, and a16@bsnes-jg **all agree**;
only `xy16@MAME` is wrong:

| seed | default=a16=bsnes | xy16@MAME | repro |
|---|---|---|---|
| 247 | `0x80FE` | `0x7C73` | `dev/run.sh fuzz --gen csmith 1 247` |
| 445 | `0x0D1D` | `0x35E7` | `dev/run.sh fuzz --gen csmith 1 445` |

Two independent seeds with the same shape ⇒ almost certainly **one** bug. a16 is the trusted oracle here
(matches default + bsnes), so it's purely the 16-bit **index-register** path.

## Grounding (measured 2026-06-20, seed 445, the smaller repro at 254 lines)

Built seed 445 `+mos-a16` and `+mos-xy16` (`-Os`, `--save-temps`) and read the LTO `main` disasm. `main` is
where `corpus_result` is computed; the xy16 build brackets it with **X-width** `rep/sep` (`c2 10`/`e2 30`/…)
around a cluster of **index ops**: `cpx #$e8`, `cpy #$20`, `cpy $zp`, `dex; cpx #$ff`, `inx`, and
`lda/sta/ldx abs,x` / `lda/ldx abs,y` (loop counters + array indexing). a16 has none of this (X stays 8-bit),
so it can't diverge. ⇒ the bug is an **index op executing in the wrong X width** — the `requiredXWidth`
lattice / `MOSInsertREPSEP` X-flag placement, the same family as the landed `55ec505`
(`requiredXWidth` CPX/CPY/INC/DEC index-width fix) and `f2d65c2`.

Likely shapes (to confirm in Phase 1): a `cpx`/`cpy` reading a 2-byte immediate while the counter is 8-bit
(uninitialised high byte → wrong bound), or an `abs,x`/`abs,y` indexed access where X/Y holds a 16-bit value
but the addressing was emitted for 8-bit (or vice versa). The `55ec505` fix classified the *value* index ops
(`CMPImm`/`CMPImag8`/`CMPAbs`, `INC`/`DEC`) as `XW_X8`; a residual op or a width-merge across a block edge is
the prime suspect.

## The bar (correctness = the differential)

`host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg`, `-verify-machineinstrs` clean.
After the fix, seeds 247 **and** 445 must agree 4-way, and no other csmith/c-torture seed may regress.

## Phase 0 — reproduce + isolate (both seeds)

1. `dev/run.sh fuzz --gen csmith 1 247` and `… 1 445` → confirm the mismatch values; save the triage `.c`.
2. Confirm both are xy16-only (a16 == default == bsnes) — already true; re-verify post-checkout on the worktree.
3. Diff the two triage programs for the common construct (loop with an indexed array access + a counter
   compare is the likely shared idiom) — the smaller seed 445 is the lead.

## Phase 1 — root-cause via MIR (mirror the 55ec505 method)

For seed 445 (and cross-check 247), dump **MIR after `mos-insert-rep-sep`** under `+mos-xy16` and find the
index op whose ambient X width is wrong:
```
mos-clang --config … -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-xy16 -Os \
  -mllvm -stop-after=mos-insert-rep-sep -o - <prog>   # (or -print-after=mos-insert-rep-sep)
```
Look for: an index op (`CPX/CPY`, `INX/INY/DEX/DEY`, `LDA/STA/LDX/LDY abs,X/abs,Y` or `(zp),Y`) preceded by a
`rep`/`sep` that leaves X at the wrong width — i.e. a gap in `requiredXWidth(MI)` (`MOSInsertREPSEP.cpp`) that
lets the op fall through to `XW_None` (X-agnostic) and run in a stray X=16/X=8 ambient. Compare against the
a16 MIR (no X-16) to confirm the op is correct under 8-bit X.

Hypotheses to walk (cap at 3, per the debugging guide):
- **H1 — `requiredXWidth` gap:** an index op class not yet classified `XW_X8`/`XW_X16` (e.g. an indexed
  load/store variant, or `(zp),Y` with a 16-bit Y). Fix = classify it (additive, `HasIndex16`-gated).
- **H2 — cross-block X-width merge:** the X lattice picks the wrong width at a block boundary / critical edge
  (cf. the reverted-then-relanded REP/SEP critical-edge work). Fix in the lattice meet/placement.
- **H3 — a 16-bit index value narrowed/widened incorrectly** by `selectXY16` (the `abs,X16`/`(zp),Y16`
  selection) so the addressing width disagrees with the index reg's actual width.

## Phase 1 — RESULT (partial, 2026-06-20) — root-cause NOT yet isolated

Method works; root cause not yet pinned (this is genuine `55ec505`-class difficulty). Findings:

- **Got `main`'s MIR after `mos-insert-rep-sep` from the REAL LTO link** (not the whole-module replay, which
  crashes on `__adddf3` s64 under `+mos-xy16` — the same runtime-fn over-trigger seen in the s32 work):
  `mos-clang --config … +mos-xy16 -Os <prog> -Wl,-mllvm,-print-after=mos-insert-rep-sep` → grep `main`.
- **Linear X-width trace of seed 445's `main` is inconclusive.** The only genuine 16-bit indexing is the
  `crc32_tab` fill loop (`STAbsXIdx $a, @crc32_tab(+0..3), $x16` at X=16, a >256-entry / 4-byte-stride table —
  `CMPImm16 $a16, 256` loop bound). All the 8-bit-index ops (`LDXIdx`/`LDAAbsIdx $y`, `LDAAbsIdx $x`,
  `CMPImag8 $y`) sit at X=8 (set by a `SEP #$30`, never re-widened on the straight-line path). No obviously
  mis-bracketed op on linear inspection ⇒ the bug is likely a **CFG/loop-edge X-width subtlety** (H2) or a
  16-bit index whose **high byte isn't zeroed** (the value, not the bracket), not a flat `requiredXWidth` gap (H1).
- **Negative result — a minimal 16-bit-table-index repro does NOT reproduce.** Built `tab[1024]` filled +
  summed via a 16-bit loop index (forces real X=16 through LTO): `default == a16 == xy16 = 0xFE00`, all agree.
  So **plain 16-bit table indexing is correct** — the bug needs the *specific* seed-445 shape (4-byte-stride
  `crc32_tab` build + the `transparent_crc` readback, or a control-flow/loop interaction), not generic X=16.

**Next step (handed back / for a focused follow-up):** delta-reduce seed 445 itself (the reliable path — the
generic-shape guesses missed), OR do CFG-aware X-lattice analysis across the `crc32_tab` loop edges + the
`transparent_crc` call boundary. The `transparent_crc` helper (CRC byte-walk over the struct) is the next
suspect to disasm under xy16 vs a16. Cap hit (3 hypotheses) → checkpointed here per the debugging-limit rule.

## Phase 2 — fix + regression-guard (same change)

- Fix in `MOSInsertREPSEP.cpp` (`requiredXWidth` / X-lattice) or `selectXY16` per Phase 1; **`HasIndex16`-gated**
  so a16 + default are untouched by construction (the pass early-returns unless `hasAccum16()`; X-lattice is
  `HasIndex16`).
- Regenerate `patches/llvm-mos/0002-321-accum16.patch`.
- **Regression guard:** both seeds become passing csmith cases. Because the csmith gate can't XFAIL a runtime
  mismatch by seed, also add a **deterministic micro-test** if the idiom minimizes (mirror `xy16ops`/the
  c-torture rows) — but note the LTO-narrows-small-index gotcha (`agent-handoff.md`): a minimal global-array
  index narrows to X8 under LTO, so the test must keep a genuinely-16-bit index (computed/double-indirect
  chase, like `pr49419`) or assert at the MIR level.

## Phase 3 — verify (run each; paste raw output + PASS/FAIL)

1. **Build:** `dev/run.sh toolchain` (on the worktree; see `howto-feature-worktree.md` for the `cp -al` of `build/`).
2. **Both seeds fixed:** `dev/run.sh fuzz --gen csmith 1 247` and `… 1 445` → 4-way agree.
3. **No xy16 regression:** `xy16basic`/`xy16ops`/`xy16indiry`/`xy16spill*` all PASS; `k_isort` xy16 leg agrees.
4. **No a16/default regression:** a16 suite green; `dev/run.sh fuzz --gen csmith 200 101` and `… 200 301` →
   0 mismatch (was the 2 xy16 seeds); c-torture `dev/run.sh torture 60` clean.
5. **verify-machineinstrs** clean; `0002` round-trips, no foreign hunks.

## Notes / coordination

- a16 worker (this session) did **not** touch xy16 codegen; the s32 merge fix (`031cc6a`) and the
  load-fold-across-call fix (`86c2602`) are a16-only and independent.
- If the fix lands, remove the open xy16 TODO item + retire the handoff note; update the `agent-handoff.md`
  worktrees table.

## References

- Handoff [`2026-06-20-321-xy16-csmith-seed247-mismatch-handoff.md`]; the landed X-flag-lattice fix
  [`2026-06-19-321-xy16-xflag-lattice-fix.md`] (`55ec505`, the `requiredXWidth` CPX/CPY/INC/DEC fix — the
  closest prior art) and the frame-index cluster fix [`2026-06-19-321-cmpbrabsimm16-frameindex-elimination-scramble.md`]
  (`f2d65c2`). Code: `MOSInsertREPSEP.cpp` `requiredXWidth`; `selectXY16` `MOSInstructionSelector.cpp`. The
  LTO-narrows-small-index gotcha + the QUIET-box rule: `docs/agent-handoff.md`.
