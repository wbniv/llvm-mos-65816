# Plan — reduce + root-cause + fix the DEFAULT-8bit 65816 matrix-fold-LOOP miscompile

## Context

A real **default-8bit** (no `+mos-a16`) 65816 codegen miscompile: a CRC fold over a 4-element
`int16_t m[4]`, written as the natural loop, computes a **different** runtime result than the byte-identical
**unrolled** form. The two C forms are semantically identical (no UB; `i ∈ [0,4)`, `m` has 4 elements), so a
differing runtime result is a genuine miscompile. Surfaced by the (shelved) Mandelbrot zoom demo; first
recorded in [docs/investigations/2026-06-25-default8-65816-loopfold-miscompile.md](../investigations/2026-06-25-default8-65816-loopfold-miscompile.md).
Tracked by the `TODO.md` "DEFAULT-8bit … matrix-fold-LOOP miscompile" item.

The fold (in `examples/snes/zoom.h`'s `zoom_fold`):
```c
for (int i = 0; i < 4; i++) {
  crc = zoom_crc16_byte(crc, (uint8_t)m[i]);
  crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[i] >> 8));
}
```
The shipped demo unrolls this as a source-level workaround, so `main` is green; the loop form is the repro.

### What changed (2026-06-25): a FAST host-side repro
The prior record said it reproduces **only** inside the full **hd** multi-bank demo via `dev/run.sh
mandel-zoom` (Docker), and that 3 standalone-minimization attempts failed. New finding: **it also reproduces
in `sd` mode (the single-bank `snes` platform), entirely host-side, in ~10 s** — no container. That makes
cvise reduction tractable (a 10 s interestingness test instead of a container build).

Evidence (host-side, `mos-snes.cfg`, `-Os`, default-8bit):
```
[loop]   ZOOM: FAIL  frames=64 nonzero=64 swaps=3 host=0xF56C rom=0xE60E
[unroll] ZOOM: PASS  frames=64 nonzero=64 swaps=3 zoom_crc=0xF56C (host replay == ROM, bsnes-jg)
```
The `ZOOM` gate replays `zoom.h` host-side over the ROM's ground-truth pad log and compares its rolling CRC
to the ROM's `zoom_crc`; the loop ROM diverges (`0xE60E` ≠ host `0xF56C`), the unrolled ROM agrees.

Repro recipe (self-contained; preserved as `dev/loopfold-repro.sh`, see *Order of execution*): bake the sd
pyramid header, build the `-DJGX_ZOOM` harness + the ROM from a scratch copy of the sources (loop vs unrolled
`zoom_fold`), run the `ZOOM` differential. `loop` → FAIL, `unroll` → PASS. No tracked-tree edits.

## Findings so far

1. **Backend/LTO codegen bug, not the middle-end.** The SNES build is **LTO** (`-mlto-zp=224`), so `-S` emits
   LLVM IR (codegen is deferred to link). The IR is correct — the fold lowers to a real `i<4` loop
   (`icmp eq i16 …, 4`). The defect appears only in the post-LTO machine code (`-Wl,--lto-emit-asm`).
2. **Not loop-vs-straightline.** The optimizer **unrolls** the `i<4` byte loop in *both* forms (the post-LTO
   asm shows straight-line per-byte CRC steps `.LBB0_76/80/84/88/92…`, each with its own 8-iteration bit
   loop). So the source loop-vs-unrolled axis isn't the trigger — both end up unrolled.
3. **Lead — an X-indexed `m[]` load under pressure.** In the loop form's fold, (at least) one `m[]` byte is
   sourced via an **X-indexed stack load** — `eor mos8(.Lmain_zp_stk+7),x` — whereas the unrolled form uses
   only direct (constant-offset) accesses. A wrong/clobbered `X` at that point would fold the wrong `m[]`
   byte → wrong CRC, which matches the register-pressure sensitivity (standalone/minimal versions don't
   exhaust pressure, so the wrong-`X` window doesn't open → they compile correctly).
4. **Default-8bit / baseline.** No `+mos-a16` involved, so per the investigation's caveat this may be an
   **upstream llvm-mos** issue rather than a 65816-fork (#320/#321) one — determine during reduction (does it
   reproduce on `mos6502`, or only `mosw65816`?).

## Approach

1. **Preserve the repro.** Land `dev/loopfold-repro.sh` (the fast host-side sd repro) as the durable artifact;
   it is the cvise interestingness oracle and the regression-gate prototype.
2. **Reduce (cvise/creduce).** Preprocess the failing TU to a single `.c`, then `creduce` it with the
   interestingness test = "builds default-8bit **and** the `ZOOM` differential FAILs while the source-unrolled
   control PASSes" (the fast repro, ~10 s/iteration). Reduce to a minimal `.c` (and ideally a frozen `.ll`).
3. **Classify upstream vs fork.** Re-target the minimal repro at `mos6502` (and stock upstream llvm-mos if
   available). If it reproduces on `mos6502`, it's an **upstream** bug → file there; if `mosw65816`-only, it's
   in the 65816 patches → fix in `vendor/` + regen `0002`.
4. **Root-cause.** From the minimal repro, confirm the mechanism behind finding #3 (trace `X`'s definition into
   the indexed `m[]` load; is `X` clobbered between its set and use, or is the index/address computation
   wrong?). Pin the responsible pass (regalloc / a peephole / address-mode folding).
5. **Fix + regression test.** Land the minimal backend fix (with `-verify-machineinstrs` clean), add a
   hermetic regression (`examples/65816/loopfold.c` + a `.sh`, and/or a frozen `.ll` `llc` gate), and confirm
   the natural loop form now matches the unrolled/host result. Restore `zoom.h` to the loop form (remove the
   unroll workaround) once green, or keep the unroll with a comment pointing at the fixed bug.

**Worktree discipline.** The reduction + fix are exploratory → run on a `throwaway/<slug>` worktree off `main`
(this plan + `dev/loopfold-repro.sh` are the durable artifacts merged back). Reach the prebuilt toolchain via
the main checkout (`build/llvm-mos-install`, `build/install`) rather than rebuilding.

## Order of execution

1. Land `dev/loopfold-repro.sh` + this plan; update the `TODO.md` item with the fast-repro breakthrough.
2. On a throwaway worktree: preprocess the failing TU, write the creduce interestingness script (wraps
   `loopfold-repro.sh`), run `creduce` → minimal `.c`.
3. Classify `mosw65816` vs `mos6502` (upstream vs fork) on the minimal repro.
4. Root-cause the wrong-`X` (or address-fold) defect; identify the pass.
5. Implement the fix; add the regression test(s); `-verify-machineinstrs` clean; differential green.
6. Merge the durable artifacts back to `main`; (optional) drop the `zoom.h` unroll workaround.

## Verification

1. **Repro is live + fast.** `dev/loopfold-repro.sh loop` prints `ZOOM: FAIL … host=0xF56C rom=0xE60E`;
   `dev/loopfold-repro.sh unroll` prints `ZOOM: PASS … 0xF56C`. (~10 s each, host-side, no container.)
2. **Minimal repro.** `creduce` yields a small `.c` that, default-8bit on `mosw65816`, computes a fold result
   ≠ the host/unrolled value; the source-unrolled control matches. Paste the reduced `.c` + both results.
3. **Classification.** State whether the minimal repro reproduces on `mos6502` (→ upstream) or only
   `mosw65816` (→ fork); paste the per-target results.
4. **Fix.** With the fix, the natural loop form == unrolled == host on the minimal repro AND in the full
   `dev/run.sh mandel-zoom` (hd) and the fast sd repro; `-verify-machineinstrs` clean.
5. **Regression test.** The new hermetic test (`loopfold.c`/`.sh` and/or frozen `.ll` `llc` gate) FAILs before
   the fix and PASSes after; wired so the differential catches the class.
6. **No collateral.** `dev/run.sh corpus` + the a16/xy16 gates stay green (the fix is default-8bit codegen but
   must not regress anything); if the fix is in `vendor/`, regen `0002` and confirm it didn't absorb foreign
   hunks.

## Risks / open items

- **Reduction may collapse the trigger.** The bug is register-pressure-sensitive; creduce can delete the very
  pressure that opens the wrong-`X` window. Mitigation: the interestingness test requires the *differential*
  to FAIL (not just "compiles"), so creduce can only keep pressure-preserving reductions; if it stalls, fall
  back to a hand-guided reduction from the asm lead (the indexed `m[]` load).
- **Upstream vs fork.** If `mos6502` reproduces, the fix + filing move upstream (queue in
  `docs/upstream-contribution-status.md`); a fork-local workaround/gate may still be wanted meanwhile.
- **LTO interaction.** The defect is post-LTO; confirm it also reproduces in a non-LTO single-TU build (for a
  cleaner `llc`/`.ll` regression) or document that the regression gate must drive the LTO codegen path.
- The `sd`-mode constants (`host=0xF56C`, `rom=0xE60E`) are sd-specific; the **hd** full-demo numbers differ
  (`0xB115` vs `0x456E`) — same class, different image params. Either makes a valid interestingness oracle.
