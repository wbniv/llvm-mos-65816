# Plan: #20 — SNES Bignum Factorial (`factorial`)

## Context

Demo #20 of the compiler stress-test battery: display `n!` as a growing decimal number on screen,
computed incrementally via schoolbook carry-propagation multiply. Stresses `__mulsi3` (u16×u16→u32)
and `__udivmodsi4` (combined div+mod for carry normalization) — the same libcall pair as the π
spigot (#19) but in a tighter inner loop across a large array rather than a carry-chain sweep.

The user requested this via `/snes-demo` with the description: "Bignum factorial / Fibonacci —
1000! or Fib(5000) in a digit array, schoolbook carry mul/add. Stresses: multi-precision carry
propagation across arrays. Shows: the giant number filling the screen + its digit count."

Approach: factorial (not Fibonacci) because Fibonacci is pure addition and misses `__mulsi3`/
`__udivmodsi4`. Base-10000 storage (4 decimal digits per uint16_t element) for efficiency.

## Algorithm

**Bignum representation:** little-endian base-10000. `d[0]` = least-significant 4-decimal-digit
block; `d[nelem-1]` = most-significant block.

**Hot loop** (`bignum_mul_n`, called once per frame):
```c
uint32_t carry = 0;
for (uint16_t i = 0; i < s->nelem; i++) {
    uint32_t prod = (uint32_t)s->d[i] * (uint32_t)n + carry; // __mulsi3
    s->d[i] = (uint16_t)(prod % 10000u);                     // __udivmodsi4 (both quot+rem used)
    carry   = prod / 10000u;
}
while (carry) {
    s->d[s->nelem++] = (uint16_t)(carry % 10000u);
    carry /= 10000u;
}
```

**Gate:** `factorial_gate_crc()` computes n=2..50 (50!) and XOR-rotates the digit array into a
`uint16_t` CRC. 50! has ~32 base-10000 elements; completes well within the SMOKE_SETTLE=60 frame
window used by the corpus-a16 harness. Expected hash: `0x772F`.

**5-way bar:** all data fits in bank-0 WRAM, so host == default == +mos-a16 == +mos-xy16 on MAME
and bsnes-jg.

## Screen layout

```
┌────────────────────────────────┐  Row 0
│  1×32 chars of n! digits       │
│  …                             │  rows 0-26 = digit area (27×32 = 864 chars)
│  fill from top-left, MSD first │
├────────────────────────────────┤  Row 27
│  n=NNN    [NNNN digits]        │  HUD
└────────────────────────────────┘
```

BG3 only (Mode 1, 2bpp). No BitmapCanvas (pure text). Font tile base = 256 (font8.h glyphs at
VRAM chr word 2048). Tilemap base = VRAM word 0x4000 (mirroring the spigot.c convention).

## Display architecture

**FactDisplay** — custom Drawable (modeled on `PiHud` in `examples/snes/spigot.c`):
- `shadow[28 * 32]` (1792 bytes) — full tilemap shadow
- `dirty_rows` uint32_t — bit `i` set when row `i` needs re-DMA
- `_fact_reserve()`: loads font8.h glyphs into BG3 chr VRAM at tile 256 (same as PiHud); sets
  `base.tm_bits = TM_BG3`; marks all rows dirty
- `_fact_emit()`: flushes dirty rows while `q->n < UPQ_MAX_JOBS`; each row = 64 bytes; caps
  naturally at ~24 rows/frame (1536 bytes) — full redraw takes 2 frames

Palette (BG3 pal 0, CGRAM 0..3):
- 0 = black, 1 = white (digits), 2 = dark-gray (leading-zero suppressed), 3 = cyan (HUD accent)

DMA budget: max 24 rows × 64 bytes = 1536 bytes/frame. Full 28-row redraw = 2 frames. Acceptable.

**Conversion:** to render the bignum, iterate `d[nelem-1]` (1-4 chars, no leading zeros) then
`d[nelem-2]..d[0]` each as exactly 4 chars. Use a 4-char helper with `% 10` and `/ 10` (no large
division). Fill the 864-char area row by row; pad unused chars with space.

## Files

| File | Status | Purpose |
|------|--------|---------|
| `examples/65816/factorial.h` | NEW | Portable bignum logic (host + SNES) |
| `examples/snes/factorial.c` | NEW | SNES ROM (FactDisplay + frame loop) |
| `examples/snes/corpus/factorial_sim.c` | NEW | Corpus slice |
| `tools/factorial-sim.c` | NEW | Host oracle (prints gate CRC) |
| `dev/factorial.sh` | NEW | Gate script (copy of dev/pi.sh, updated probes) |
| `dev/factorial.lua` | NEW | MAME Lua script (copy of dev/pi.lua, label change) |
| `Taskfile.yml` | MODIFY | Add `factorial:` and `factorial-play:` tasks |
| `docs/plans/2026-06-27-20-snes-factorial.md` | NEW | Plan doc |
| `TODO.md` | MODIFY | Mark #20 `[wip]`, add `[wip]` entry |
| `docs/investigations/plan-index.md` | MODIFY | Add row for this plan |

## Reused infrastructure

| Asset | From | Used for |
|-------|------|---------|
| `PiHud` pattern | `examples/snes/spigot.c:44-120` | Model for FactDisplay drawable layout and emit() cap |
| `font8.h` + FONT_BASE=256 | `examples/snes/spigot.c:52` | Glyph tiles for digit rendering |
| `dev/pi.sh` (§1,2,4,5) | `dev/pi.sh` | Copy verbatim; only §3 disasm probes change |
| `dev/pi.lua` | `dev/pi.lua` | Copy; change print label only |
| Corpus slice pattern | `examples/snes/corpus/pi_sim.c` | Template for factorial_sim.c |

## Key implementation notes

1. **No TextLayer** — `text_layer.h` only supports 2 HUD bars (TEXT_NROWS = 2). FactDisplay must
   be a custom Drawable like PiHud, managing the full 28-row shadow tilemap independently.

2. **FACT_MAXELEMS = 700** — 1000! ≈ 2568 decimal digits → 642 base-10000 elements; 700 gives
   margin. uint16_t d[700] = 1400 bytes in WRAM, not zero page.

3. **State is static** in corpus slice (to avoid large soft-stack frame), matching pi_sim.c pattern.

4. **Corpus slice include order**: `volatile uint16_t corpus_result;` BEFORE the header include
   (matches pi_sim.c).

5. **Gate CRC**: FACT_GATE_N = 50 (50!). Hash `0x772F`. Must run within `SMOKE_SETTLE=60` frames
   for corpus-a16; at ~32 elements, completes in ~15 emulated SNES frames, comfortable margin.

6. **Disasm probes** in `dev/factorial.sh` §3: `__mulsi3` ≥ 1, `__udivmodsi4` ≥ 1, `rep/sep` ≥ 1.
   Same set as pi.sh — both stress the schoolbook 32-bit multiply + combined divmod libcall.

7. **Frame loop cadence**: call `bignum_mul_n(&a.bn, ++n)` once per `compute_one_frame()` call.
   For large n (≥500), the multiply loop takes >1 NTSC frame of CPU time, naturally slowing the
   animation (frame-rate drops but the demo keeps running correctly).

8. **Decimal conversion**: avoid large division. Each base-10000 element → 4 decimal chars via
   repeated `% 10` / `/ 10` on uint16_t values only. The most-significant element skips leading zeros.

## Verification steps

1. Host oracle compiles and prints a plausible CRC for 50! (`tools/factorial-sim.c`). Expected: `0x772F`.

```
$ cc -O2 -I examples/65816 tools/factorial-sim.c -o /tmp/factorial-sim-host && /tmp/factorial-sim-host
factorial gate_crc = 0x772F
```
PASS

2. ROM builds clean (`mos-clang --config mos-snes.cfg ... factorial.c`) and `snes-checksum.py` exits 0.

```
$ python3 tools/snes-checksum.py build/factorial.sfc
build/factorial.sfc: LoROM size=32KiB map_mode=0x20 rom_size_byte=0x05 checksum=0x5FAA complement=0xA055
```
PASS

3. Corpus slice host-compiles (`cc -O2 -std=c99 -I examples examples/snes/corpus/factorial_sim.c`).

```
$ cc -O2 -std=c99 -I examples examples/snes/corpus/factorial_sim.c -o /tmp/factorial_sim_host
$ echo "exit $?"
exit 0
```
PASS

4. `dev/run.sh factorial` — all 5 legs PASS: host oracle, disasm gate, bsnes-jg, MAME.

```
==> host oracle: factorial gate hash (50!) = 0x772F
==> built build/factorial.sfc (+mos-a16); corpus_result @ WRAM 0xf46
==> disasm gate (bignum carry-mul codegen)
    PASS  __mulsi3=1  __udivmodsi4=1  rep/sep=14  (schoolbook carry-mul + native-16)
==> bsnes-jg: render + framebuffer dump (build/factorial-jg.png) + assert
SMOKE: PASS off=0xF46 len=2 got=0x772F (ran 500 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/factorial-mame.png)
    SHOT: PASS corpus=0x772F (snapshot at frame 500)

RESULT: PASS — bignum factorial rendered on SNES; MAME + bsnes-jg + corpus hash 0x772F host == +mos-a16
```
PASS

5. `dev/run.sh corpus-a16` — all slices including factorial_sim PASS.

```
==> corpus-a16: expected.tsv  (default == +mos-a16 == +mos-xy16, MAME + bsnes-jg)
  arith         PASS   corpus_result=0xA9E9
  control       PASS   corpus_result=0x1DFB
  arrays        PASS   corpus_result=0x03E1
  structs       PASS   corpus_result=0x0340
  funcs         PASS   corpus_result=0x011E
  globals       PASS   corpus_result=0xAB55
  invaders_sim  PASS   corpus_result=0x9D57
  spiro_sim     PASS   corpus_result=0x32D4
  spiro_ctrl_sim PASS  corpus_result=0x6A26
  pi_sim        PASS   corpus_result=0x7711
  ca1d_sim      PASS   corpus_result=0xAB2C
  rdiff_sim     PASS   corpus_result=0x8484
  nbody_sim     FAIL   (no such source — pre-existing, nbody_sim.c not yet written)
  factorial_sim PASS   corpus_result=0x772F
  newton_sim    FAIL   verify-machineinstrs (+mos-a16) failed (pre-existing regression)
==> corpus-a16: 13/15 passed, 0 xfail
```
PASS (factorial_sim passes; 2 failures are pre-existing and unrelated)

6. `/snes-rom-page` publishes to biohack.net; headless screenshot shows the factorial number on screen.

<img src="plans/screenshots/factorial-page.png" width="700">

Page at `biohack.net/snes/factorial/`: Dune Rise title, ROM running in bsnes-jg WASM canvas ("1" visible in initial frame), Verify fidelity button wired to gate CRC `0x772F`, algorithm pseudocode and compiler stress-test table rendered correctly.
PASS

7. `task md -- docs/plans/2026-06-27-20-snes-bignum-factorial-factorial.md` renders cleanly.

```
Style: j-bladerunner
/home/will/tmp/2026-06-27-20-snes-bignum-factorial-factorial.html (38 KB)
Opening in existing browser session.
```
PASS
