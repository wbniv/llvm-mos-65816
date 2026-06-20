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

## Phase 1 — RESULT (2026-06-20, 10-agent workflow `wf_826f3a8e-bff`, ~760k tok) — root cause is NOT a static X-width bug

A multi-agent static analysis (6 angles, a16 as oracle: diff xy16-vs-a16 codegen; synthesize; **3 adversarial
verifiers**) reached a firm, surprising conclusion. The earlier "linear trace inconclusive" became a definite
**negative**, and the synthesized requiredXWidth fix was **refuted 3/3**.

**Verified findings:**
1. **Both seeds' static codegen is X-width-CORRECT and value-correct at every indexed op** (4 of 6 angles:
   "no defect"). transparent_crc, selectXY16's index materialization, the 16-bit-index high-byte handling, and
   the crc32_tab fill-loop lattice are all provably correct. Every 8-bit-indexed block in 247/445 is **X8-pinned
   by an adjacent classified op** (`ldy #imm`/`iny`/`tyx`/JSR-return) right before the first indexed access, so
   the lattice never flows X=16 into an unbracketed 8-bit op. The genuine X=16 region (the `crc32_tab[256]`
   `*4`-scaled CRC access) is correctly `XLow=1` `bf/9f long,X` (`R_MOS_ADDR24 .bss.crc32_tab @0x0218`, bank 0,
   index `i*4` ≤ 0x3FC, in range). Independently re-derived by all 3 verifiers.
2. **The `requiredXWidth` family gap is a REAL latent defect — but it does NOT fire in 247/445.** `requiredXWidth`
   (`MOSInsertREPSEP.cpp`) only enumerates LDAbs/LDImag8/LDImm/STAbs/INC/DEC/STImag8/CMP{Imm,Imag8,Abs}/
   LDXIdx/LDYIdx/TA/TX/PH/PL; the whole 8-bit indexed/indirect family (LDAAbsIdx, LDAZpIdx, ST{Abs,Zp,Z}Idx,
   LD/ST{Indir,IndirIdx}, the ADC/SBC/AND/ORA/EOR/ASL/LSR/ROL/ROR/CMP{Zp,Abs,Indir}Idx forms) falls to
   `XW_None` (X-passthrough). If the lattice ever left X=16 ambient at one, it would deref a 16-bit index with a
   garbage high byte. The genuinely-16-bit forms (`*Idx16`, `XLow=1`) are correctly `XW_X16`, so the gap can
   only ever *miss a forced-X8* — never widen a 16-bit value. **a16/default-safe** (HasIndex16-gated, line 304).
   But in 247/445 every such op is already X8-pinned (finding 1), so **closing the gap will not change their
   output** — verified by 3/3.
3. **The actual 247/445 cause was NOT isolated statically.** Static index-WIDTH is correct everywhere; the
   dissent (5/6 + all verifiers) is that the true cause is *runtime*: a value bug in the genuine-X16 `bf/9f
   long,X` crc32_tab path, or a **65816-core / MAME behavior of `long,X` under X=16** the static disasm can't
   reveal. A minimal `tab[1024]` 16-bit-index fill+sum repro also **passes** (0xFE00 all-agree) — generic X=16
   indexing is fine; the trigger is the specific Csmith CRC harness shape.

**The decisive cheap test the workflow surfaced:** the original differential ran `default@MAME`, `a16@MAME`,
`xy16@MAME`, `a16@bsnes-jg` — it **never ran `xy16@bsnes-jg`.** If `xy16@bsnes` *agrees* with the oracle while
`xy16@MAME` is wrong, this is a **MAME `long,X`-under-X16 emulation artifact, not a compiler bug** (a16@MAME
can't expose it — a16 keeps X=8). If `xy16@bsnes` *also* diverges, it's a real codegen/runtime bug. Run this
FIRST — it bisects the whole problem in one build.

---

## Phase 2 — TWO TRACKS (revised per the workflow)

### Track A — land the `requiredXWidth` family-gap fix (hardening; correct regardless of 247/445)

A genuine latent xy16 defect, low-risk, ready to implement. In `requiredXWidth`'s opcode switch (beside
`case MOS::LDXIdx: case MOS::LDYIdx: return XW_X8;`), add the 8-bit indexed/indirect family → `XW_X8`:
`LDAZpIdx`/`LDAAbsIdx`, `ST{Zp,Abs,Z}Idx`, `LD/ST{Indir,IndirIdx}`, and the
`ADC/SBC/AND/ORA/EOR/ASL/LSR/ROL/ROR/CMP{Zp,Abs,Indir}Idx` forms. **Verify each enum exists** against
`build/.../MOSGenInstrInfo.inc` + the `.td` records (`MOSInstrLogical.td`) before committing; drop any that
don't, add any indexed sibling that does. Do **not** add the `XLow=1` 16-bit forms (`*Idx16` — already
`XW_X16`). HasIndex16-gated ⇒ a16/default byte-identical. *(Robust long-term alternative: scan MI operands for
a physical `$x`/`$y` use marked index/address by the MCID and return `XW_X8` unless `XLow` — closes the gap
structurally instead of by enumeration.)* Regression guard: a micro-test that forces an 8-bit `(zp),Y`/`abs,X`
op reached on every edge from an X16 region with no intervening classified-X8 op (the workflow's `go()` recipe;
keep a genuinely-16-bit index alive so LTO can't narrow it). Land independently of Track B.

### Track B — the actual 247/445 bug (cause not yet found; runtime bisection)

1. **Disambiguate compiler-bug vs MAME-emulation-bug (do first):** run **`xy16@bsnes-jg`** on both seeds.
   - `xy16@bsnes` == oracle ⇒ **MAME `long,X`-under-X16 artifact.** Not a compiler bug: file a MAME note,
     close the seeds as emulator-caveat (and prefer bsnes-jg for the xy16 leg on `long,X` shapes). Done.
   - `xy16@bsnes` != oracle ⇒ **real codegen/runtime bug** → step 2.
2. **Runtime fill-vs-read bisection** (the genuine-X16 path is the only suspect left): build a variant where
   the `crc32_tab` FILL goes via the xy16 `9f long,X` store but the READBACK is forced through a known-good
   8-bit pointer path (isolates the store); and the converse — a host-initialized constant table read via the
   xy16 `bf long,X` path (isolates the load). Whichever side flips the value localizes store vs load. Then
   MIR/runtime-trace that op. (Reduction of the full seed is the fallback.)

---

## Phase 3 — verify (run each; paste raw output + PASS/FAIL)

0. **Disambiguation (Track B step 1):** `xy16@bsnes-jg` on seeds 247 + 445 — record whether it agrees with the
   oracle (⇒ MAME artifact) or diverges (⇒ real bug). This gates whether Track B is a compiler fix at all.
1. **Build:** `dev/run.sh toolchain`; fresh `clang-23` mtime.
2. **Track A non-regression (the key proof it's safe):** diff seeds 247/445 + the xy16 micro-tests disasm
   xy16 vs the pre-fix build — the ONLY change may be **added `sep #$10`** before previously-unbracketed 8-bit
   `(zp),Y`/`abs,X`/`abs,Y` ops; **a16 and default builds byte-identical** (proves HasIndex16 gating).
3. **Track A micro-test:** the forced-X16→8-bit-indexed-op gate PASSES 4-way.
4. **Track B (if a real bug):** seeds 247/445 → `0x80FE`/`0x0D1D` on `xy16@MAME` and `xy16@bsnes`.
5. **No xy16 regression:** `xy16basic`/`xy16ops`/`xy16indiry`/`xy16spill*` PASS; `k_isort` xy16 leg agrees.
6. **No a16/default regression:** a16 suite green; `dev/run.sh fuzz --gen csmith 200 101` + `… 200 301`
   0 mismatch (modulo any still-open seed); c-torture `dev/run.sh torture 60` clean.
7. **verify-machineinstrs** clean; `0002` round-trips, no foreign hunks.

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
