# Finding — a DEFAULT-8bit (non-`+mos-a16`) 65816 codegen miscompile of a 4-element array fold loop

**Status:** real miscompile, **reproduced** (in context), **MINIMIZED** (2026-06-25) — cvise reduced the
full `mandel-zoom.c` to a 43-line repro and the post-LTO asm confirms the X-indexed-`m[]`-load lead;
root-cause + fix are next. Independent of the #321 `+mos-a16` work (it's in the *default* 8-bit path).
Surfaced by the (now shelved) Mandelbrot zoom demo; the durable record is here. **Reduction result +
artifacts:** [`../plans/2026-06-25-default8-loopfold-miscompile-reduce-and-fix.md`](../plans/2026-06-25-default8-loopfold-miscompile-reduce-and-fix.md)
(RESULT) · minimal `.c` [`../plans/spikes/2026-06-25-loopfold-min.c`](../plans/spikes/2026-06-25-loopfold-min.c)
· harness `dev/reduce-loopfold.sh`.

## Symptom

A CRC fold over a 4-element `int16_t` array `m[4]`, written as the natural loop

```c
for (int i = 0; i < 4; i++) {
  crc = crcb(crc, (uint8_t)m[i]);
  crc = crcb(crc, (uint8_t)((uint16_t)m[i] >> 8));
}
```

computes a **different result** from the byte-identical **unrolled** form (`m[0]…m[3]` written out),
when compiled for the 65816 in the **default 8-bit** mode (`-mcpu=mosw65816 -Os`, *no* `+mos-a16`).
Observed in the demo's `zoom_fold`: over a fixed `R`-held input the loop form folded `0x456E` while
the host oracle, the `+mos-a16` build, and the *unrolled* default build all agreed on `0xB115`. The
two C forms are semantically identical (no UB; `i ∈ [0,4)`, `m` has 4 elements), so a differing
runtime result is a genuine miscompile, not a source bug. The `(uint16_t)x >> 8` is promotion-safe
(uint16_t promotes to *unsigned* int on the 16-bit-int target — logical shift — so that's not it).

## Reproduced (in context) — the recipe

Reproduces **only inside the full demo's register pressure**, via the host-vs-target differential:

1. Branch `wt/321-mandel-zoom` (the shelved demo; the source is preserved there).
2. In `examples/snes/zoom.h`, revert `zoom_fold`'s matrix fold from the shipped *unrolled* form back
   to the `for (i<4) m[i]` **loop** form.
3. `dev/run.sh mandel-zoom` → the `ZOOM` differential FAILS for the **default** build (host replay
   `0xB115` ≠ ROM `0x456E`) while the `+mos-a16` build PASSES. (The shipped demo unrolls the loop as
   the workaround, so the committed demo is green.)

How it was localized: a ~10 s host-side bisect loop (jgxcheck runs host-side) folding `zoom_fold`'s
components one at a time isolated it to the matrix-fold *loop*; swapping loop→unrolled fixed it.

## NOT minimized — three standalone attempts all FAILED to reproduce

The bug is highly context-sensitive. Standalone/minimal versions compile **correctly** (host ==
default == `+mos-a16`), so the trigger needs the surrounding SNES I/O / register pressure, not just
the compute:

| attempt | shape | result |
|---|---|---|
| `looprepro` | the bare loop vs unrolled over a fixed `m[]` | got 0 (no repro) |
| self-check | two zoom state machines, loop-fold vs unroll-fold in one build | got 0 (no repro) |
| minimal compute | `zoom_step`+`zoom_matrix`+loop-`zoom_fold` → CRC, host-vs-target | host==default==a16==0x1300 (no repro) |

The last (closest) attempt is preserved at
[`../plans/spikes/2026-06-25-default8-loopfold-miscompile-attempt.c`](../plans/spikes/2026-06-25-default8-loopfold-miscompile-attempt.c).
So a clean standalone repro could **not** be extracted within the debugging budget — the trigger
appears to need the full `mandel-zoom.c` `main()` (the Mode 7 MMIO writes in `apply_zoom`, the DMA,
the boot-`img_hash16`, and the volatile WRAM channels all live around the fold).

## Next step (follow-up, separate task)

cvise-reduce **from the full `mandel-zoom.c`** (default-8bit, the failing `ZOOM` differential as the
interestingness test) down to a minimal `.c`/`.ll`, then root-cause + fix in the backend. **DONE for the
reduce step (2026-06-25):** cvise (predicate = loop-build ZOOM FAIL ∧ unroll-build ZOOM PASS, `zoom.h`
held fixed) gave the 43-line repro above; the `--lto-emit-asm` diff confirms the loop form sources `m[i]`
via X-indexed `.Lmain_zp_stk,x` loads the unroll form never emits, then reuses `X` as the inner CRC
counter. **Remaining:** a self-contained `mos6502`-retargetable repro for upstream-vs-fork classification,
then root-cause the wrong-`X` + fix. Until then the loop→unrolled rewrite is a safe, faithful source-level
workaround (a 4-way unroll of a fixed-size fold), and the differential gate catches the class. Tracked in
`TODO.md`.

## Caveat

This is the *default* 8-bit code path (no `+mos-a16`), i.e. baseline 65816 codegen — so depending on
where it reduces, it may be an upstream `llvm-mos` issue rather than a #321/65816-fork one. Determine
that during the reduction (does it reproduce on `mos6502`, or only `mosw65816`?).

**Provisional answer (2026-06-25):** likely **upstream**. The bug is **8-bit-accumulator (default) only**
— `+mos-a16` (16-bit) is clean on the minimal repro (target-only on bsnes: default loop `0xE60E` ≠ unroll
`0xF56C`; a16 loop `==` unroll `== 0xD351`). The loop form uniquely materializes `m[]` into a 16-byte ZP
soft-stack frame and folds via X-indexed `mos8(.Lmain_zp_stk{,+1}),x` loads (unroll keeps `m[]` in
registers, 2-byte frame) — default-8bit soft-stack/regalloc/indexed machinery that is **upstream**. The
fork's `0002` only touches the spill path under `+mos-a16` gates (and a16 is clean). A `-mcpu=mos6502`
build on the **SNES** platform is *not* a valid 6502 test (65816 crt0/ABI). Definitive confirmation
deferred to a **pristine no-`0002`** reproduce. Full record: the plan's RESULT.
