# SNES title intro: slow the fly-in + pixel-centre each line via HDMA

**Date:** 2026-06-29
**Topic:** `examples/snes/snesgfx/title_layer.h` — two user-reported defects in the title card
**Supplements:** `CLAUDE.md` (project guide) + `docs/agent-handoff.md`

## The two reports (user)

1. **"the text lines scroll in so fast i can't see the motion."** The vertical fly-in
   (`title_begin`/`_title_emit`) eases each line in with an exponential `>>3` step and snaps the
   final `<1` row, so the whole ~12-row travel is consumed in ~8 frames (≈130 ms). Too fast to read.

2. **"there's no reason you can't center each line separately … use HDMA to center each line."**
   The lines are placed by *tilemap column*, i.e. centred only to the **8 px tile grid**. A line of
   **odd** character length lands 4 px left of its true pixel centre (`(32-len)/2` floors). Two lines
   of different parity therefore need **different** horizontal nudges — impossible with one shared
   `BG2HOFS`. Fix: stream `BG2HOFS` per-scanline (HDMA) so each line's band gets its own offset.
   User chose **"static pixel-perfect centre only"** (no horizontal *motion*; a constant per-band
   nudge), and explicitly asked for a small reusable HDMA helper ("make it so").

## Design

### A. Slow the vertical fly-in (defect 1)

Replace the exponential ease + snap with a **constant slow velocity** `TITLE_FLY_STEP` (Q4 units/frame).
`line0` descends (y0 ↑ to `TITLE_ROW0<<4`), `line1` rises (y1 ↓ to `(TITLE_ROW0+2)<<4`), each clamped
at its target. `STEP=3` → ~12-13 rows over ~70 frames (~1.15 s); an 8 px tilemap step every ~5 frames
reads as a deliberate march. Bump the `title_begin` spin cap 48 → 96. (Sub-pixel smoothing of two lines
moving in **opposite** directions is impossible on one shared BG2 vertical scroll — each line's
fractional offset is the other's complement — so the motion stays 8 px-stepped, as the user accepted.)

### B. Pixel-centre each line via HDMA on BG2HOFS (defect 2)

Per-line nudge from the string: `hofs = 8*col + 4*len - 128`, which is **0** for even `len` and **−4**
(= 0x3FC in the 10-bit latch, i.e. shift content 4 px right) for odd `len`.

New reusable helper **`examples/snes/snesgfx/hdma_hscroll.h`** — a 2-band per-scanline horizontal-scroll
table + channel-arm, transfer **mode 2** (one register, write-twice → the 16-bit scroll latch):

```
table = [ split, lo0,hi0,  224-split, lo1,hi1,  0 ]   (count bit7=0 = write-once-and-hold)
```

Integration in `TitleLayer`:
- `reserve()`: compute `nudge0/nudge1`; `split = (TITLE_ROW0+2)*8 = 112`; build the table into a
  struct field (WRAM, bank-0 low-WRAM mirror → HDMA source bank 0); arm **channel 3** (`$4330-$4334`,
  free: UploadQueue owns GP-DMA ch 0, `hud.h` owns HDMA ch 1-2) to `BG2HOFS` low byte `$0F`.
- `title_begin()`: `REG_HDMAEN = 0x08` (title owns HDMAEN — it runs before any demo arms HDMA).
- `title_end()`: `REG_HDMAEN = 0` + reset `BG2HOFS=0`.

**Why the static table needs no per-frame rebuild:** the split at scanline 112 separates the two lines
for the *entire* fly-in — `line0` never descends below scanline 104 (`<112`), `line1` never rises above
112 — so band A always holds exactly `line0`, band B exactly `line1`, at every fly-in position.

### Gate-neutrality preserved

The title remains gate-neutral: `corpus_result` is the pre-loop hash, unaffected by an HDMA channel or
the scroll table. The differential gate must still PASS unchanged.

## Test demo choice

`spirograph` (the user's reference) is `SPIROGRAPH`(10,even)/`HYPOTROCHOID`(12,even) → both nudge 0 →
**no visible change**. Verify instead on a **mixed-parity** demo: `life` =
`CONWAY LIFE`(11,**odd** → −4) / `GLIDER GUN`(10,even → 0) — the odd line shifts 4 px right, the even
line is untouched, proving independent per-line centring.

## Verification steps

1. **Build the toolchain leg + the `life` ROM and run its full gate** (disasm + bsnes-jg corpus
   differential) — must PASS unchanged (gate-neutrality):
   `dev/run.sh life`

2. **Capture a settled-title frame** (lines centred, HDMA active) and a **mid-fly-in frame** (slowed
   descent visible), bsnes-jg headless:
   `build/jgxcheck build/life.sfc vendor/bsnes-jg/Database <corpus_off> 2 <expect> 120 build/life-title-jg.png`
   `build/jgxcheck build/life.sfc vendor/bsnes-jg/Database <corpus_off> 2 <expect>  40 build/life-flyin-jg.png`

3. **Prove the 4 px per-line nudge** — diff the settled-title frame against a build with the HDMA
   disabled: the odd line (`CONWAY LIFE`) shifts 4 px, the even line (`GLIDER GUN`) is byte-identical.

4. **`-verify-machineinstrs` clean** for the `life` build (no new codegen, but confirm no regression).

## Verification results

### 1. `dev/run.sh life` — full gate must PASS unchanged (gate-neutrality)

```
==> host oracle: Conway's Life gate hash = 0xDDF1
==> built build/life.sfc (+mos-a16); corpus_result @ WRAM 0x68
==> disasm gate (life_step: shift/bool ops, no mul/div)
    PASS  shifts=22  bools=51  bad_mul=0  bad_div=0  (pure shift+bool, no helpers)
==> bsnes-jg: render + framebuffer dump (build/life-jg.png) + assert
SMOKE: PASS off=0x68 len=2 got=0xDDF1 (ran 500 frames, bsnes-jg)
RESULT: PASS — Conway's Life rendered on SNES; corpus hash 0xDDF1 host == +mos-a16
```
**PASS** — corpus hash unchanged (`0xDDF1`), disasm gate clean. The HDMA channel + scroll table
add nothing to `corpus_result` (a pre-loop hash). (`life_gate_crc()` runs ~360 frames in force-blank
*before* the title is raised, so the title intro is visible roughly frames 360–480.)

### 2. Capture title frames (bsnes-jg headless, `jgxcheck … <frames> <png>`)

`build/life-t380.png` (mid fly-in): "CONWAY LIFE" still near the top edge, "GLIDER GUN" near the
bottom — both still descending at frame ~15 of the fly-in. With the old `>>3` ease they would have
met in ~8 frames; now the ~12-row travel takes ~70 frames (~1.15 s). **PASS** (motion now readable).

`build/life-on-460.png` (settled, into the hold): both lines met at the centre rows, ink shimmer +
rainbow backdrop animating. **PASS**.

### 3. Prove the independent 4 px per-line nudge — diff vs `-DTITLE_PIXEL_CENTER_OFF`

Same ROM compiled with the pixel-centre forced off (tile-grid centring), captured at the identical
frame 460 (deterministic → identical backdrop phase + Life grid underneath), per-row pixel diff:

```
rows 96..130 diff counts:
  y=103 count= 44 x[81,168]
  y=104 count= 12 x[80,164]
  y=105 count= 18 x[80,164]
  y=106 count= 36 x[80,167]
  y=107 count= 16 x[80,164]
  y=108 count= 16 x[80,164]
  y=109 count= 40 x[81,168]
total: 182
```
The diff is **exclusively** in the CONWAY LIFE band (7 rows = the full 8 px glyph); the GLIDER GUN
band shows **zero** diff. Cross-correlation of the shift:
```
per-row best shift s where ON[x]==OFF[x-s]: {103:4,104:4,105:4,106:4,107:4,108:4,109:4}
```
**PASS** — CONWAY LIFE (11, odd) shifted **exactly +4 px right** to its true pixel centre; GLIDER GUN
(10, even) **untouched**. Independent per-line centring, impossible with one shared BG2HOFS — confirms
the HDMA does what was asked. (An earlier split at scanline 112 = line1's top produced a 1 px-tall
shear on GLIDER GUN's top row from the HDMA value-settle latency; moving the split into the blank gap
row, scanline 108, eliminated it — the row-119 artifact is gone, total dropped 224 → 182.)

### 4. `-verify-machineinstrs` clean

```
=== -verify-machineinstrs (must be clean) ===
CLEAN (no verifier errors)
rc=0
```
**PASS** — no codegen regression (the change is platform-header C, not backend).
