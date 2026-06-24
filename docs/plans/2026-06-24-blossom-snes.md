# Blossom (Hopalong attractor) on SNES — Phase 1: headless fixed-point math kernel

**Status:** Phase 1 DONE + VERIFIED 2026-06-24 (4-way differential PASS, both emulators). On-screen
interactive renderer (#3) deferred — see *Deferred*. Extends the standing project guide; generic
conventions in `~/SRC/CLAUDE.md` and the project `CLAUDE.md`.

## Context

`~/Downloads/blossom.html` is **Blossom 4.0**, a single-file web app that plots Barry Martin's
"Hopalong" strange attractor:

```
x' = y - sign(x) * sqrt(|b*x - c|)        y' = a - x        (iterate from (0,0))
```

The original 1989 Blossom (Lars Norpchen, Turbo Pascal shareware) ran on a 286 with **fixed-point
integer math + a precomputed square-root table** (`BLOSSOM.TBL`) — no FPU. That is exactly what a
65816 port needs, and this repo (`llvm-mos-65816`) is a compiler fork adding native 16-bit-accumulator
codegen (`+mos-a16`) *with a SNES platform to exercise it*. A Hopalong attractor is an ideal realistic
16-bit fixed-point workload: per iteration one multiply (`b*x`) plus several 16-bit add/sub, run in a
loop — precisely the kind of code `+mos-a16` targets.

**Scope (user, 2026-06-24):** ship the **headless math kernel first**. The full on-screen interactive
SNES port is the larger TODO (#3). The kernel is that port's natural first milestone, so nothing here
is throwaway. "Headless" = the attractor *computation* in portable fixed-point C (no float, no
graphics), folded to a 16-bit `corpus_result` in WRAM, run through the project's standard differential
gate: **host == default(8-bit)@MAME == `+mos-a16`@MAME == `+mos-a16`@bsnes-jg**, `-verify-machineinstrs`
clean, plus a disasm gate that native 16-bit is actually firing.

## What was built

| Path | What |
|------|------|
| `examples/65816/k_hopalong.c` | The kernel. Q8.8 (`short`) orbit state; `volatile` params `pa/pb/pc` (so the optimizer can't fold the loop to a literal); 512-byte `SQRT_LUT`; rotate-xor fold into `corpus_result`. `#ifdef HOST` builds an oracle `main` (prints the value + an orbit-range/clamp diagnostic); otherwise the SNES `main` stores `corpus_result` and spins. |
| `tools/gen-sqrt-lut.py` | Regenerates the Q8.8 `SQRT_LUT` array (256 entries, `round(sqrt(i)*256)`; index with `|b*x-c| >> 8`). Committed + regenerable. |
| `dev/k_hopalong.sh` | Micro-test driver (cloned from `dev/a16eqval.sh`): verify-clean + native-16-bit disasm gate → host oracle reproduces the golden → build default+a16 ROMs → MAME default==a16 → bsnes-jg a16. Run via `dev/run.sh k_hopalong`. |

### Design decisions (as built)

1. **Q8.8 signed (`short`)** state, matching `k_fxmul.c`. `a=7.17 → 0x072C`, `b=8.44 → 0x0871`,
   `c=2.56 → 0x028F` (classic Hopalong = Blossom's default). The host oracle confirms the orbit stays
   bounded at **maxabs 5857 (~22.9 world units)** — well inside `int16`, so every `short` op is
   value-preserving and the math is portable bit-for-bit (host == target).
2. **Multiply:** `b*x` is `((int32_t)b * (int32_t)x) >> 8` — needs bits above the low 16, so it lowers
   to the shared `__mulsi3` libcall (the toolchain's shift-add; the 65816 has no multiply instruction —
   the backend's `MUL` opcode is gated to the 65EL02). `sign(x)*sqrt` is a **conditional negate, not a
   multiply** — written as a branch, which removed a spurious per-iteration `__mulhi3` that the naive
   `sgn*s` form emitted (and shrank the a16 build from +46 B to +14 B vs default).
3. **sqrt via 256-entry Q8.8 LUT** indexed by the integer part of `|b*x-c|` (`aarg >> 8`), 512 B
   `.rodata` — the 1989 `BLOSSOM.TBL` approach, deterministic and host/target-identical. (The libc
   Newton `fixed_point::sqrt` was considered and rejected for Phase 1: a static LUT is simpler and
   exactly authentic.) A defensive `idx>255` clamp never fires for the bounded classic params.
4. **N = 1024 iterations.** Codegen is identical for any N≥1; N only sets runtime + checksum mixing.
   1024 finishes well inside the MAME settle window (the dev script raises `SMOKE_SETTLE` to 120 for
   headroom; still < the 3 s backstop).
5. **Fold:** rotate-left-1 then `xor` in the new point (`x`, and `y<<1`) — the `k_isort.c` rotate-xor
   idiom, no extra multiplies, sensitive to any single-bit divergence. Golden = **`0x1BBC`**.

## Verification (steps as specified in the approved plan; raw evidence + PASS/FAIL)

**1. Host oracle is bounded & deterministic** — `cc -DHOST`, run; orbit never clamps, value stable.

```
host oracle: maxabs=5857 (Q8.8 ~ 22.88 world units), clamps=0
0x1BBC          (identical across 3 runs)
```
**PASS** — fixed golden `0x1BBC`, 0 clamps, orbit bounded ~22.9 world units (inside int16).

**2. `-verify-machineinstrs` clean** under `+mos-a16` (and default).

```
default: OK
a16: OK
(no verifier errors)
```
**PASS** — both builds verify clean.

**3. Disasm gate** — native 16-bit arithmetic fires on the orbit under `+mos-a16`.

```
PASS: native 16-bit active (12 rep / 13 sep brackets on the orbit arithmetic)
```
**PASS** — rep/sep brackets present (≥4 each); orbit goes native 16-bit, not byte-wise.

**4. 4-way differential** — `dev/run.sh k_hopalong`.

```
==> 2) host oracle reproduces the golden (0x1BBC)
  PASS: host oracle corpus_result=0x1BBC == golden 0x1BBC
==> 4) MAME: host == default == +mos-a16 (corpus_result == 0x1BBC)
  default:   SMOKE: PASS addr=0x7E0200 len=2 got=0x1BBC (ran 120 ticks)
  +mos-a16:  SMOKE: PASS addr=0x7E0200 len=2 got=0x1BBC (ran 120 ticks)
==> 5) bsnes-jg: +mos-a16 corpus_result == 0x1BBC (independent confirmation)
  SMOKE: PASS off=0x200 len=2 got=0x1BBC (ran 180 frames, bsnes-jg)
RESULT: PASS — Hopalong (Blossom) Q8.8 attractor runs native 16-bit and folds to 0x1BBC, host == default == +mos-a16 (both emulators)
```
**PASS** — host == default@MAME == `+mos-a16`@MAME == `+mos-a16`@bsnes-jg, all `0x1BBC`.
(The `ld.lld` data-layout warning during the a16 link is the project's known-benign far-pointer
`p2/p3` layout mismatch between the far-enabled toolchain and the crt0 archive — both ROMs read
`0x1BBC`.)

**5. Size delta recorded** — `.text.main`, `+mos-a16` vs default.

```
default .text.main = 389 B ; a16 .text.main = 403 B ; delta = +14 B
```
**PASS (number captured; documented regression).** The Hopalong inner loop is an **8/16-interleave**
shape — a 32-bit multiply libcall and sign/clamp branches woven through 16-bit arithmetic — so the
rep/sep brackets that enter/leave 16-bit mode cost a little more than the native ops save. This is the
same regression class the project already documents for `k_crc16`/`k_fxmul`/`k_satadd`, and is exactly
*why* `+mos-a16` is opt-in/per-op-gated. It is a measurement, not a defect; the differential is the bar
and it passes.

## Deferred — Phase 2/3: on-screen interactive SNES Blossom (TODO #3)

Out of scope here; tracked as the M2 TODO item. Render the attractor natively:
- **Graphics layer (currently greenfield** — the repo's only on-screen code today is `hello.c`'s green
  backdrop): Mode 7 chunky 8bpp framebuffer (identity tilemap; per-pixel = high-byte VRAM write), a
  64 KB hit-count **shadow buffer in WRAM bank `$7E`** addressed via runtime far pointer (the
  `+mos-a16` far-pointer path, cf. `examples/65816/far_indir.c`), VBlank DMA of recolored bands
  shadow→VRAM, 256-color CGRAM palette + palette-cycling. This pulls forward the deferred "Phase-2"
  graphics infrastructure — add VRAM (`$2115–$2119`), Mode-7 matrix (`$211A–$2120`), and DMA
  (`$420B`, `$4300–$430A`) registers to `platforms/snes/snes.h` plus a small reusable gfx helper.
- **Interactivity:** joypad controls — random a/b/c, switch palette/formula/color-mode, auto-scale.
- **Optional perf path:** the SNES hardware multiplier (`$4202/$4203 → $4216`) for the hot `b*x`.
