# Handoff — low-level SNES rendering mechanics (for a higher-level rendering library)

**From:** the #321 beefy-demo work (fixed-point Mandelbrot rendered on the SNES, captured from MAME +
bsnes-jg). **To:** an agent building a higher-level SNES rendering library on llvm-mos.
**Worked example to read alongside this:** [`examples/snes/mandel-display.c`](../../examples/snes/mandel-display.c)
(compute → blit → display), the HAL in [`platforms/snes/snes.h`](../../platforms/snes/snes.h), and the capture
harness [`dev/mandel-shot.sh`](../../dev/mandel-shot.sh) + [`dev/jgxcheck.cpp`](../../dev/jgxcheck.cpp).

This is grounded in code that actually boots and displays on both emulators. Where something is **spec-correct
but not yet exercised in-repo**, it says so — don't take those on faith, verify them.

The four sections below are ordered by what bit us hardest / matters most for a two-emulator differential bar.

---

## 1. The init/boot sequence that actually displays (and the ordering that bit us)

The SNES PPU has **no linear framebuffer**. You upload tile/character data + a tilemap + a palette into the
PPU's private memories (VRAM, CGRAM, OAM) and the PPU composites them every scanline. The single rule that
governs *when* you may touch those memories:

> **VRAM, CGRAM and OAM are writable only during force-blank or v-blank.** Writes during active display are
> silently dropped (or land at the wrong address). This is the #1 "nothing shows / garbage shows" bug.

So the canonical bring-up is **force-blank for the whole setup, release it last**:

```c
int main(void) {
  snes_ppu_reset_blank();      // (1) INIDISP=$8F force-blank + ZERO the PPU control regs
  /* ... compute / prepare your tile + map + palette data ... */
  load_cgram();                // (2) CGADD=0; then CGDATA low,high per colour  (force-blanked)
  upload_tiles_to_vram();      // (3) snes_vram_addr(char_base); VMDATA writes   (force-blanked)
  upload_tilemap_to_vram();    // (4) snes_vram_addr(map_base);  VMDATA writes   (force-blanked)
  REG_BGMODE  = BGMODE_1;      // (5) configure the layer: mode,
  REG_BG12NBA = char_base>>12; //     char base ($1000-word units),
  REG_BG1SC   = SNES_BGSC(map_base,0); //  tilemap base ($400-word units) + size,
  REG_BG1HOFS = 0; REG_BG1HOFS = 0;    //  scroll = 0 (write TWICE — latched),
  REG_BG1VOFS = 0; REG_BG1VOFS = 0;
  REG_TM      = TM_BG1;        //     enable BG1 on the main screen.
  REG_INIDISP = INIDISP_ON;    // (6) release force-blank LAST: screen on, brightness 15 ($0F)
  for (;;) {}                  //     (for animation: wait NMI, then update in v-blank — see §5)
}
```

**Ordering gotchas that actually bit us (in rough order of pain):**

- **Initialise *all* the PPU control registers, not just the ones you "use".** SNES power-on leaves them
  indeterminate **and bsnes-jg randomises them**. A first cut that set only mode/bases/scroll rendered a
  *different* picture on every boot (random mosaic, a random window mask cutting the layer, random colour-math
  blending a random fixed colour). VRAM was byte-identical across runs — only the rendered frame varied. The
  fix is `snes_ppu_reset_blank()` (force-blank + zero `$2101–$2133`, **skipping the data/address ports**
  `$2104/$2116-$2119/$2121/$2122` because writing those pokes video memory). **This is the single biggest
  determinism trap; see §3.** This *is* the classic SNES boot register-clear — we just initially skipped it.
- **Release force-blank LAST.** Turn the screen on only after VRAM+CGRAM+registers are all set, or you flash
  garbage / a partial upload.
- **Brightness ≠ enable.** `INIDISP` low nibble is brightness 0–15; `$0F` (=15) is full. `$0F` not `$01`.
  Force-blank is bit 7 (`$8F` = blank+bright, a safe hold state).
- **Scroll registers are write-twice latches and power up garbage.** Even to set 0 you write the port twice
  (`BG1HOFS=0; BG1HOFS=0`). A nonzero leftover scroll shows unwritten tilemap rows wrapping in at the edges.
- **Colour 0 is transparent.** CGRAM entry 0 is the backdrop, and pixel value 0 in *any* tile is transparent
  (shows the backdrop through it). If your image looks like "backdrop everywhere", your tiles are all value 0.
- **VRAM is word-addressed.** `VMADD`/`$2116-7` is a **word** address; the data ports are bytes but the
  auto-increment is per word. Set `VMAIN` *before* the address, the address *before* the data.

---

## 2. DMA + VMAIN — the bits that silently no-op when wrong

The Mandelbrot demo uploads via **direct port writes** (`vram_w()` → `$2118`/`$2119` in a loop) because it's
only ~1280 words. **A real library must use DMA** for full-screen uploads (a 32 KiB VRAM fill is ~hundreds of
thousands of cycles by hand; DMA does it in ~one v-blank). The register recipe below is **verified working** by Track 3b's big upload
([`examples/snes/mandel-mode7.c`](../../examples/snes/mandel-mode7.c) / `dev/run.sh mandel-mode7`): a single
**32 KiB DMA** of an interleaved Mode 7 image from high WRAM (`$7E…`) to VRAM, confirmed on both emulators —
read `dma_vbuf_to_vram()` there for a copy-pasteable known-good call. (The Track 3a far-store gate
[`examples/65816/k_mandel_far.c`](../../examples/65816/k_mandel_far.c) / `dev/run.sh mandel-far` exercises the
far stores but uploads nothing, so it has no DMA.)

**VMAIN (`$2115`) — the VRAM address auto-increment. Get this wrong and the picture interleaves/skips:**

| bits | meaning |
|------|---------|
| 7 | **increment timing**: `1` = after a write to `$2119` (VMDATAH); `0` = after `$2118` (VMDATAL). |
| 3–2 | address remap (full-graphic modes); `00` = none — what you want for linear uploads. |
| 1–0 | **step**: `00`=+1, `01`=+32, `10`/`11`=+128 **words**. |

For sequential word upload via the 16-bit data port, `VMAIN = $80` (increment by 1 word after the high byte).
The classic silent bug: leaving bit 7 = 0 while writing *both* bytes — every write then increments on the low
byte, so your high bytes land a word late and the whole upload shears.

**General-purpose DMA, channel 0 (the others are identical at `$431x`, `$432x`, …):**

| reg | name | set to (VRAM upload) |
|-----|------|----------------------|
| `$4300` | DMAP0 — direction + transfer pattern | `$01`: bit7=0 (CPU→PPU), pattern 1 = "two registers, write B then B+1" (for `$2118`/`$2119`) |
| `$4301` | BBAD0 — B-bus dest (low byte of `$21xx`) | `$18` (→ `$2118`/`$2119`) |
| `$4302/$4303` | A1T0L/H — source address (16-bit) | address of your ROM/RAM source |
| `$4304` | A1B0 — source bank | source bank (e.g. `$00` for a `.rodata` table) |
| `$4305/$4306` | DAS0L/H — byte count (16-bit) | N **bytes** (so a 256-word tile block = 512) |
| `$420B` | MDMAEN — channel-enable **trigger** | `$01` (bit 0 = ch 0); CPU stalls until done |

**Before triggering a VRAM DMA**: set `VMAIN` then `VMADD` to the destination word address (the DMA streams to
`$2118/9`, which increment per `VMAIN`). For **CGRAM** instead: `DMAP=$00` (single register, pattern 0),
`BBAD=$22` (CGDATA), set `CGADD` first. For **OAM**: `BBAD=$04` (OAMDATA), set `OAMADD` first.

**Silent-no-op / half-works traps (each produces *something*, so they're hard to spot):**

- **DMA during active display** → dropped/corrupt. Do it in force-blank or v-blank, same rule as §1.
- **`DAS = 0` means 65536**, not "nothing". A miscomputed 0 count transfers 64 KiB and trashes VRAM.
- **Wrong transfer pattern** (DMAP bits 0–2): pattern 0 (one register) to a VRAM upload writes only `$2118`,
  so you get every *other* byte — image looks half-resolution or striped. VRAM wants pattern 1.
- **Wrong BBAD** (`$18` vs `$19` vs `$22`) sends data to the wrong port — no error, just wrong/no picture.
- **Forgot to set VMADD** → upload starts wherever the address pointer last was.
- **`MDMAEN` is the trigger** — setting `$43xx` does nothing until you write `$420B`. Easy to forget and then
  "the DMA didn't run" with no diagnostic.
- HDMA (`$420C`) is a *different* mechanism (per-scanline register writes for gradients/windows); irrelevant to
  static uploads — don't confuse the two enable registers.

---

## 3. Emulator divergence (MAME vs bsnes-jg) — what we actually saw

Honest scope: **we did not observe a pixel-content divergence.** Once the ROM was correct and the PPU fully
initialised, MAME and bsnes-jg rendered the **same** Mandelbrot (both assert the same on-screen CRC, and the
frames match visually). The divergences we hit are about **determinism, capture, and timing** — and one of
them *will* break a differential bar if you ignore it:

1. **bsnes-jg randomises power-on PPU state; MAME (in our runs) did not.** An under-initialised ROM is
   **nondeterministic on bsnes** — identical VRAM, different rendered frame each boot (random
   mosaic/window/colour-math). MAME's power-on was stable (our fill-timing measurement was repeatable). ⇒ **For
   a two-emulator differential, fully reset the PPU (`snes_ppu_reset_blank`) or bsnes will flap.** Verify with:
   capture the same ROM 3× and diff the PNG SHAs (we did exactly this).
2. **Headless capture works oppositely on the two cores** (this is the practical "renders on one but not the
   other"):
   - **bsnes-jg** renders in **software** into a caller buffer every frame — `dev/jgxcheck.cpp` just reads it.
     No X, no GPU, always works.
   - **MAME**'s `video:snapshot()` writes an **all-black** PNG under `-video none` / SDL `offscreen` / `soft` /
     `accel` — its renderer needs a real surface. Fix: run MAME **under Xvfb** (baked into the dev image).
     This was a multi-attempt dead-end before Xvfb; don't repeat it.
3. **Frame-count to completion is not guaranteed identical across cores.** The compute finished at frame 893 on
   MAME (measured); WRAM converged identically on bsnes but we sample at frame ~1800 to be safe. **Sample/snap
   well after the program is done, never at the edge** — a capture that races the force-blank→screen-on
   transition gives a frame that differs run-to-run and core-to-core.
4. **Output pixel format differs (a capture detail, not a render divergence):** bsnes's framebuffer is
   `0x00RRGGBB` — and the R/B order is the *opposite* of a naïve read of its `lightTable` source (the table is
   indexed RGB555 while SNES CGRAM is BGR555, so the red intensity lands in the high byte). A solid-green test
   can't catch a R/B swap — test with red or a known ramp. MAME's snapshot is a normal PNG (512×225, 2×-wide).

**Untested — flag for real hardware (we ran emulators only):** emulators are often lax about the access-window
rule. Hardware **drops** VRAM/CGRAM/OAM writes outside force-blank/v-blank, is stricter about mid-frame
register changes, and exposes open-bus on bad reads. A lib that passes both emulators can still fail on a real
SNES if it writes VRAM during active display. **Keep every VRAM/CGRAM/OAM write strictly inside force-blank or
v-blank** and you stay portable; lean on emulator leniency and you won't. (Full how-to + the capture pipeline:
[`docs/investigations/snes-emulator-screenshots.md`](../investigations/snes-emulator-screenshots.md).)

---

## 4. Toolchain / linker invocation, VRAM-upload layout, and the llvm-mos quirks we see

**Build (host-side, against the from-source toolchain + SDK):**

```sh
TOOL=build/llvm-mos-install/bin            # mos-clang / lld / llvm-objdump
CFG=build/install/bin/mos-snes.cfg         # the snes platform config
$TOOL/mos-clang --config $CFG -mcpu=mosw65816 \
    [-Xclang -target-feature -Xclang +mos-a16] \   # opt-in 16-bit accumulator
    -Os -Wl,-Map=out.map -o out.sfc src.c
python3 tools/snes-checksum.py out.sfc     # fix the cart header checksum in place
```

`mos-snes.cfg` adds `-mcpu=mosw65816`, **`-mlto-zp=224`** (zero-page/imaginary-register budget — relevant to
the pressure crash below), `-D__SNES__`, and pulls in `@mos-common.cfg`. The linker script
[`platforms/snes/link.ld`](../../platforms/snes/link.ld) places `.text`/`.rodata`/`.data`-init-image in the
32 KiB LoROM bank `$00` (`$8000–$FFAF`), low-WRAM `.bss`/stack at `$0200–$1FFF`. **VRAM layout is *not* a
linker concern** — VRAM is written at runtime through the data ports. Your tile/tilemap *data* either:
- (a) is **computed at runtime** and streamed to VRAM (the Mandelbrot approach), or
- (b) lives as a `const` array in `.rodata` (ROM, bank `$00`) and is **DMA'd** to VRAM — DMA source bank `$00`,
  source address = the array's link address. (b) is the normal path for a sprite/tile lib.

**llvm-mos / 65816 quirks you will hit (these are the ones we see):**

- **`int` is 16-bit** on this target (32-bit on the host). Use explicit `int16_t`/`int32_t`/`uint8_t`
  everywhere or host↔target results diverge. Every narrowing needs an explicit width cast.
- **Data-layout link *warning* is expected and benign:** `ld.lld: warning: Linking two modules of different
  data layouts: … 'e-…-p1:8:8-i16:8…' whereas 'ld-temp.o' is '…-p2:32:8-p3:24:8-…'`. The #320 far-pointer
  patches add address-space `p2` (32-bit far) and `p3` (24-bit packed) to the main module's datalayout; libc
  was built without them. The shared spaces match, so it's noise — but it will scroll past on every link.
- **A far pointer (`__attribute__((address_space(2)))`) is a 32-bit value ⇒ needs `+mos-a16`.** A *runtime*
  far deref/store lowers to indirect-long `lda [dp]` / `sta [dp]`; a link-time-constant far address folds to
  absolute-long `lda $xxxxxx`. Default-8bit legitimately **cannot** compile a runtime far pointer (a clean
  Legalizer rejection, not a crash). So if your lib puts data in another bank and far-reads it, that path is
  a16-only. Patterns: [`examples/65816/far_store.c`](../../examples/65816/far_store.c),
  [`far_indir.c`](../../examples/65816/far_indir.c). High-WRAM framebuffers (`$7E2000+`) are the motivating
  case — see Track 3.
- **`+mos-a16` register-pressure failures at -O1/-Os.** A function holding many live 16-bit values can crash
  the register allocator ("ran out of registers") or emit an *undefined-physreg* COPY caught only by
  `-verify-machineinstrs` (a worse, miscompile-class symptom). Mitigation that works: factor hot code into a
  **`noinline`** callee so the 16-bit state crosses the call boundary and pressure is bounded (the
  `k_prng.c`/`mandel_cell` idiom). Always build with `-mllvm -verify-machineinstrs` while developing.
- **A two-inner-loop VRAM upload miscompiled on us** (an off-by-8 in the tile bytes) where a single flat loop
  computing each word from its index was correct. If your blit's VRAM hex looks shifted, **simplify the loop
  structure and re-diff the bytes** before blaming the PPU — dump VRAM (`JGX_VRAM=1` in `jgxcheck`) and
  compare against what you wrote.
- **Don't trust the byte order of a 16-bit volatile store to an MMIO port pair.** When order matters (the
  `$2119` write is what triggers the VRAM increment), write `VMDATAL` then `VMDATAH` as two explicit byte
  stores rather than one `*(uint16_t*)0x2118 = w`.

---

## Reference — the rest of the PPU model (supporting detail for the library)

### Backgrounds, tilemaps, tiles
- **BG mode** (`BGMODE` `$2105` low 3 bits) picks the per-layer bit depth: mode 0 = four 2bpp BGs; mode 1 =
  BG1/BG2 4bpp + BG3 2bpp (the common one); mode 3 = BG1 8bpp + BG2 4bpp; mode 7 = one 8bpp rotation/scale
  layer (see below). bpp = colours/tile (2bpp=4, 4bpp=16, 8bpp=256).
- **Tilemap entry** is 16-bit: bits 0–9 tile number, 10–12 palette group, 13 priority, 14 H-flip, 15 V-flip.
  A tilemap is 32×32 entries per screen (`BG?SC` size bits select 32×32/64×32/32×64/64×64).
- **`BG?SC`** = tilemap base in **$400-word** units (bits 7–2) + size (1–0). **`BG12NBA`/`BG34NBA`** = each
  BG's character base in **$1000-word** units (a nibble each). Helper: `SNES_BGSC(word_base, size)`.
- **Tile (character) bitplane layout — the fiddly part.** A tile is 8×8 pixels. Planes are **interleaved by
  row in pairs**:
  - **2bpp** (16 B): bytes `[row0 plane0][row0 plane1][row1 plane0]…` — one bit/pixel/plane, bit 7 = leftmost.
  - **4bpp** (32 B): the 2bpp layout (planes 0&1) for 8 rows, **then** planes 2&3 for 8 rows.
  - **8bpp** (64 B): planes 0&1, then 2&3, then 4&5, then 6&7.
  A *solid-colour* tile `c` is trivial (each plane all-`$FF` or all-`$00` by the bits of `c`) — that's how the
  Mandelbrot "fat-pixel" tiles work. A *photographic* tile needs real bit-twiddling per pixel; **Mode 7 avoids
  it** (its character data is **linear 1 byte/pixel**, no bitplanes) at the cost of VRAM interleaving
  (even bytes = tilemap, odd bytes = chr) and a 256-tile cap (so a 128×128 unique-pixel image = 16×16 tiles
  fills it exactly).

### Mode 7 — verified per-pixel image path (Track 3b, `examples/snes/mandel-mode7.c`)
Mode 7 is the path that worked for a per-pixel image. Confirmed details, end to end:
- **VRAM is interleaved**: word `n` = `(chr[n] << 8) | tilemap[n]`. Build the whole interleaved image (32 KiB =
  16384 words) in a staging buffer, then upload it as one DMA to `$2118` with **VMAIN=$80** (inc-after-`$2119`)
  and **DMAP pattern 1** (writes `$2118` then `$2119` per word). One 32 KiB DMA from high WRAM did the job.
- **De-linearise**: a raster `W×H` buffer → tiles. `tilemap[n]` indexes by screen position `(n&127, n>>7)`;
  `chr[n]` indexes by tile `(n>>6)` then in-tile `(row (n>>3)&7, col n&7)`. The two mappings of `n` differ — get
  them right or the image scrambles (validate with a recognisable test pattern *before* the slow real compute).
- **256-tile cap** ⇒ 128×128 (16×16 tiles) is the sweet spot; it fills the chr space exactly.
- **Matrix** (`M7A..M7D`, 8.8 fixed point, **write-twice** low-then-high): identity = A=D=`$0100`, B=C=`$0000`;
  **2× zoom** (so a 128×128 image fills the 256-wide screen) = A=D=`$0080` (screen steps the source by 0.5).
  `M7SEL=$00` (wrap), `M7X/M7Y` centre = 0 (write-twice), Mode 7 scroll via `BG1HOFS/BG1VOFS` = 0.
- **Cost reality**: 128×128 = 16384 cells of software 32-bit fixed-point is heavy (~14k frames of emulated time
  even at maxiter 12). Per-pixel compute *on the SNES* is slow — for anything interactive, precompute to ROM and
  DMA, or compute coarse + scale with the Mode 7 matrix.

### Colour (CGRAM)
- 256 entries, **BGR555**: bit layout `0bbbbbgggggrrrrr` (red low). Pack with
  `SNES_RGB(r,g,b)` (5-bit channels). Write: `CGADD` = index, then `CGDATA` low byte, `CGDATA` high byte.
- In 4bpp the tilemap's palette field (×16) selects which 16-colour group; in 8bpp the pixel indexes all 256
  directly. Entry 0 = backdrop/transparent (see §1).

### Sprites (OAM) — *not yet built in this repo; spec sketch for the lib*
- `OBSEL` `$2101`: sprite size pair + name (character) base. OAM is 544 bytes: a 512-byte low table (4 bytes
  per sprite ×128: X, Y, tile, attr) + a 32-byte high table (2 bits/sprite: X bit 8 + size select).
- Write via `OAMADD` `$2102/3` then `OAMDATA` `$2104` (or DMA with `BBAD=$04`). Enable with `TM` bit 4
  (`TM_OBJ`). None of this is implemented yet — it's the obvious second milestone for the library after BG.

### Timing & animation (the demo is static; a lib won't be)
- One NTSC frame ≈ **224 visible scanlines + ~38 v-blank**, ~1/60 s. The **v-blank window** is your safe
  VRAM/CGRAM/OAM write budget per frame (~a few thousand bytes by hand, much more via DMA).
- Enable NMI (`NMITIMEN` `$4200` bit 7); the NMI fires at v-blank start. Pattern: compute into a RAM
  shadow during active display, then in the NMI handler DMA the changed parts to VRAM/CGRAM/OAM. Double-buffer
  OAM in RAM and DMA the whole 544 B each v-blank.
- The demo sidesteps all this: force-blank, build everything once, release blank, spin. That's fine for a
  static image and is the simplest thing that displays.

### HAL surface already available ([`platforms/snes/snes.h`](../../platforms/snes/snes.h))
`REG_INIDISP/BGMODE/BG1SC/BG2SC/BG12NBA/BG1HOFS/BG1VOFS/VMAIN/VMADD(L/H)/VMDATA(L/H)/CGADD/CGDATA/TM/TS/`
`CGWSEL/CGADSUB/COLDATA/NMITIMEN/MEMSEL/MDMAEN/DMAP0/BBAD0/A1T0(L/H)/A1B0/DAS0(L/H)`; constants
`INIDISP_ON/INIDISP_FORCE_BLANK/VMAIN_INC_HIGH_1/TM_BG1..OBJ/BGMODE_1/BGMODE_3`; macros `SNES_RGB`,
`SNES_BGSC`; helpers `snes_vram_addr(word)`, **`snes_ppu_reset_blank()`**.

## Recommended library shape (suggestion, not a mandate)
1. **Keep `snes.h` as the thin register map** (it is). Build the library *on top*, don't fold policy into it.
2. **Layer it:** (a) a `vblank`/force-blank-gated *upload queue* (the access-window rule in one place — this
   is where correctness lives); (b) VRAM allocator (char + tilemap regions); (c) tile/palette/sprite
   asset loaders (prefer DMA, const data in `.rodata`); (d) BG + OAM front-ends.
3. **Build order that de-risks fastest:** static BG image via DMA → CGRAM via DMA → OAM/sprites → v-blank-driven
   updates → Mode 7. Get one DMA upload provably correct before generalising.
4. **Verify like this repo does:** leave a CRC/sentinel of what you uploaded in WRAM and assert it on **both**
   emulators (`dev/jgxcheck.cpp` for bsnes, a Lua autoboot for MAME), and screenshot via the §3 pipeline. A
   render that only "looks right" is not verified; tie the pixels to a number.
5. **Always `-mllvm -verify-machineinstrs`** under `+mos-a16`, and prefer `noinline` for register-heavy kernels.

### External references (canonical)
- **fullsnes** (nocash) — the exhaustive SNES hardware reference (PPU regs, OAM, DMA, timing).
- **anomie's** SNES docs (PPU/registers/timing) — the classic deep dives.
- This repo: `examples/snes/mandel-display.c`, `examples/snes/mandel-far.c` (Track 3, DMA + far),
  `dev/mandel-shot.sh`, `docs/investigations/snes-emulator-screenshots.md`.
