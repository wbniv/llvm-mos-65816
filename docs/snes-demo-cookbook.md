# SNES Demo Cookbook

A recipe for building and publishing new demos in the **compiler stress-test demo battery** —
the numbered list of SNES ROMs in
[`docs/investigations/2026-06-27-compiler-stress-test-demo-ideas.md`](investigations/2026-06-27-compiler-stress-test-demo-ideas.md).
Read [`CLAUDE.md`](../CLAUDE.md) and [`docs/agent-handoff.md`](agent-handoff.md) first (project
conventions, build mechanics, the differential gate). This file is the SNES-demo-specific layer
on top.

---

## The invariant pattern

Every demo is **six artifacts** wired to one shared build/test/publish pipeline:

```
examples/65816/<name>.h        ← portable C logic (host + SNES compile both use it)
examples/snes/<name>.c         ← SNES ROM (snesgfx frame + display + frame loop)
examples/snes/corpus/<name>_sim.c  ← corpus slice (runs the gate hash, writes corpus_result)
tools/<name>-sim.c             ← host oracle (same hash, prints it; gate compares against this)
dev/<name>.sh                  ← gate script (build ROM → disasm probe → bsnes-jg → MAME)
Taskfile.yml entry             ← `task <name>` = `dev/run.sh <name>`
```

Publication is a seventh step: the `/snes-rom-page` skill scaffolds a playable emulator page at
[biohack.net/snes/](https://biohack.net/snes/) and its own `/snes/<slug>` page.

The plan doc (`docs/plans/YYYY-MM-DD-7-snes-<name>.md`) precedes all of them — plan first,
code second. Number the plan after its battery ID (`#7`, `#11`, `#19`, …).

---

## SNES hardware budget (the subset that matters for demos)

**Display:** 256×224 pixels NTSC (or 256×240 PAL — use NTSC).

**PPU modes:** `display_init()` in `snesgfx/display.h` selects **Mode 1** and never changes
it. Mode 1 gives:
- **BG1** — 4bpp tilemap, 16 colors per palette × 8 palettes = 128 unique colors.
- **BG2** — 4bpp tilemap (same palette range).
- **BG3** — 2bpp tilemap, 4 colors per palette × 8 palettes = 32 unique colors.
- **OBJ** — sprites (Space Invaders uses this).

All existing demos use **BG3 2bpp** for text / HUD (via `TextLayer` or `BitmapCanvas`). Add
BG1 or BG2 for a full-color render layer if you need more than 4 colors per tile.

**Tiles:** 8×8 pixels. A 256×224 screen = 32×28 = 896 tilemap entries. Each entry is 2 bytes
(tile index + palette + flip). VRAM is 64 KiB words (word = 2 bytes). Tile character data:
- 2bpp: 8 words/tile = 16 bytes.
- 4bpp: 16 words/tile = 32 bytes.

**CGRAM:** 256 color registers, each a 15-bit BGR555 word (`SNES_RGB(r,g,b)` where r/g/b ∈
0–31). BG3 palette 0 = CGRAM[0..3], palette 1 = CGRAM[8..11], …, palette 7 = CGRAM[56..63].
BG1 palette 0 = CGRAM[0..15], …, palette 7 = CGRAM[112..127]. Use `upq_push_cgram()` to
upload palette data inside `emit()`.

**V-blank DMA budget (NTSC):** approximately **4 200 CPU cycles ≈ 2 100 bytes/frame** at
~2 cycles/byte for DMA. Budget conservatively at **1 536 bytes** (1.5 KiB/frame) to leave room
for overhead. `BitmapCanvas` caps its per-frame flush at `CANVAS_FLUSH_TILES = 64` tiles ×
16 bytes = **1 024 bytes** — designed to fit. A 32×28 full-screen tilemap (896 × 2 = 1 792
bytes) does NOT fit one V-blank; either cap with a dirty-range window or split across frames.

**Joypad input:** automatic reading is the default. `display_init()` enables
`NMITIMEN_AUTOJOY`; poll the completed latch through the shared controller object:

```c
Controller pad;
controller_init(&pad);

for (;;) {
  controller_poll(&pad);              /* waits out JOYBUSY, then reads REG_JOY1 */
  uint16_t held = controller_held(&pad);
  uint16_t pressed = controller_pressed(&pad);
  /* update, draw, display_frame() */
}
```

Do not call `snes_read_pad1()` in a normal frame loop: it performs a manual `$4016` serial read and
requires AUTOJOY to be disabled. Manual polling is reserved for reviewed timing/peripheral
exceptions. Never combine the two mechanisms, and never restore `$4200` with a literal
`NMITIMEN_NMI` if the program owns automatic input. Deadline-sensitive demos must include input in
their exact cadence/slip gate; the SVX2 transport work demonstrated that an otherwise small manual
poll was enough to create presentation slips.

---

## snesgfx component guide

All headers live in `examples/snes/snesgfx/`. Include them in the SNES ROM file only (not in
the portable logic header).

| Header | What it provides | When to use |
|--------|-----------------|-------------|
| `display.h` | `Display` struct, `display_init()`, `display_add()`, `display_frame()` | Always — the frame loop |
| `drawable.h` | `Drawable` vtable base (reserve/emit pair) | Always — the base of every layer |
| `scene.h` | `Scene` container of up to `SCENE_MAX` (4) `Drawable*` items | Always (owned by Display) |
| `upload.h` | `UploadQueue`, `upq_push_vram/cgram/oam()`, `upq_flush()` | Always (owned by Display) |
| `vram.h` | `VramAlloc` bump allocator for VRAM regions | Always (owned by Display) |
| `bitmap_canvas.h` | `BitmapCanvas` — a 2bpp canvas of N×M 8×8 tiles, set-pixel + Bresenham + capped dirty-tile DMA | Scatter plots, pixel drawing, line drawing |
| `text_layer.h` | `TextLayer` — a tiled BG3 layer that renders `font8.h` glyphs into a tilemap shadow, DMA'd each dirty row | Text / HUD panels |
| `sprite_set.h` | `SpriteSet` — OAM sprite manager | Sprites (used by Space Invaders) |
| `controller.h` | Joypad polling helpers | Interactive demos |

**Rule: never write to PPU data ports outside `emit()`.** All VRAM/CGRAM/OAM writes go through
`upq_push_*()` → `upq_flush()` which Display guarantees is only called during V-blank.
The one exception is `reserve()` (runs in force-blank, so direct writes are safe there).

**The frame loop** is always the same three calls:

```c
Display d;
display_init(&d);
display_add(&d, (Drawable *)&my_layer);
// ... other layers ...
for (;;) {
    compute_one_frame();        // update state (runs during active display)
    display_frame(&d);          // wait v-blank → emit → DMA flush
}
```

**Writing a custom Drawable** (when `TextLayer` and `BitmapCanvas` don't fit):

```c
typedef struct {
    Drawable base;      // MUST be first
    uint16_t map_word;  // BG VRAM tilemap base (word addr)
    uint16_t shadow[N]; // local VRAM mirror
    // ...
} MyLayer;

static void _my_reserve(Drawable *d, VramAlloc *va) {
    MyLayer *l = (MyLayer *)d;
    // Allocate VRAM (va is the bump allocator)
    // Write chr data, set BG registers — safe here (force-blank)
    l->base.tm_bits = TM_BG3; // or TM_BG1 / TM_BG2
}
static void _my_emit(Drawable *d, UploadQueue *q) {
    MyLayer *l = (MyLayer *)d;
    // Push only dirty regions: upq_push_vram(q, l->map_word + ..., shadow + ..., 0, nbytes, VMAIN_INC_HIGH_1)
    // CGRAM update if palette changed: upq_push_cgram(q, cgidx, pal_array, 0, nbytes)
}

// Init:
static const DrawableVtbl MY_VTBL = { _my_reserve, _my_emit };
l->base.vtbl = &MY_VTBL;
```

---

## The algorithm header (`examples/65816/<name>.h`)

This is the **portable, host-compilable** logic. The differential gate depends on it compiling
identically on both host (64-bit x86 with 32-bit `int`) and target (16-bit `int` on 65816),
so:

**Width rules:**
- Use `int16_t`/`uint16_t` and `int32_t`/`uint32_t` everywhere (`<stdint.h>`).
- Never use bare `int` — it's 32-bit on host, 16-bit on target.
- `sizeof(int) == 2` on the SNES, `sizeof(int) == 4` on host — any `int` arithmetic is a bug
  in the gate, not just a lint warning.

**Arithmetic rules:**
- `(int16_t)a * (int16_t)b` promotes to `int` on host (32-bit) but stays 16-bit on target —
  wrap in `(int32_t)a * (int32_t)b` if you need a 32-bit result.
- 32-bit multiply stresses `__mulsi3`; 32-bit divide stresses `__udivsi3`/`__divsi3`. Both
  are on the hot path in most demos — this is the point.

**Gate hash (`<name>_gate_crc()`):** a pure function that folds N iterations of the algorithm
into a 16-bit CRC. The corpus slice calls it and writes the result to `corpus_result`. The host
oracle calls it and prints it. The gate script compares them.

```c
// Minimal gate hash pattern:
static inline uint16_t <name>_gate_crc(void) {
    uint16_t h = 0;
    for (int i = 0; i < GATE_N; i++) {
        // run one step
        h = (uint16_t)((h << 1) | (h >> 15)) ^ (uint16_t)step_result;
    }
    return h;
}
```

Keep `GATE_N` small enough that the corpus slice finishes in ≤ 120 frames on SNES (the
`corpus-a16` harness timeout). Measure once headlessly and halve it if it's borderline.

**RNG:** copy the 4-line xorshift16 from `invaders_logic.h`:

```c
static uint16_t rng_state = 0xBEEF;
static inline uint16_t rng16(void) {
    rng_state ^= rng_state << 7;
    rng_state ^= rng_state >> 9;
    rng_state ^= rng_state << 8;
    return rng_state;
}
```

---

## Corpus slice (`examples/snes/corpus/<name>_sim.c`)

The corpus slice is the bridge between the logic header and the `corpus-a16` harness. Template:

```c
#include <stdint.h>
volatile uint16_t corpus_result;
#include "../../65816/<name>.h"

int main(void) {
    corpus_result = <name>_gate_crc();
    return 0;
}
```

Wire it into `Taskfile.yml`'s `CORPUS_SIMS` list (or wherever `corpus-a16` picks up slices).
Check `examples/snes/corpus/spiro_sim.c` and `pi_sim.c` for the exact pattern.

---

## Host oracle (`tools/<name>-sim.c`)

Compiles and runs on the host. Calls the same `<name>_gate_crc()` and prints the hash:

```c
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/<name>.h"

int main(void) {
    uint16_t h = <name>_gate_crc();
    printf("<name> gate_crc = 0x%04X\n", h);
    return 0;
}
```

The gate script compiles this with `cc -O2 -I examples` and captures the output.

---

## Gate script (`dev/<name>.sh`)

Template (copy `dev/pi.sh`, replace the demo-specific parts):

```bash
#!/usr/bin/env bash
# dev/<name>.sh — gate for the <Name> demo (#N compiler stress-test)
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh <name>"; exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain"; exit 1; }
[ -f "$CFG" ]            || { echo "FATAL: SDK not built";  exit 1; }

# 1. Host oracle
cc -O2 -I "$ROOT/examples" "$ROOT/tools/<name>-sim.c" -o "$BUILD/<name>-sim"
EXPECT=$("$BUILD/<name>-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: $EXPECT"

# 2. Build ROM (add +mos-a16 if you want the 5-way bar; omit if far-pointer-only)
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/<name>.map" -o "$BUILD/<name>.sfc" \
  "$ROOT/examples/snes/<name>.c"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/<name>.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/<name>.map")
OFF="0x$VMA"; ADDR=$(printf '0x%X' $((0x7E0000 + 0x$VMA)))

# 3. Disasm probe (edit for the codegen corners this demo stresses)
DIS=$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/<name>_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/<name>_sim.o" 2>/dev/null &&
  "$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/<name>_sim.o" 2>/dev/null || true)
# Examples of things to probe:
#   __mulsi3 / __mulsf3   (32-bit multiply)
#   __udivsi3 / __divsi3  (32-bit divide)
#   __udivmodsi4           (combined div+mod when both quot+rem used in same expr)
#   rep / sep             (native 16-bit bracketing under +mos-a16)
MUL=$(printf '%s\n' "$DIS" | grep -cE '__mulsi3' || true)
RS=$(printf '%s\n'  "$DIS" | grep -cwE 'rep|sep' || true)
if [ "$MUL" -ge 1 ] && [ "$RS" -ge 1 ]; then
    echo "    PASS  __mulsi3=$MUL  rep/sep=$RS"
else
    echo "    FAIL  __mulsi3=$MUL  rep/sep=$RS  (expected all >= 1)"; rc=1
fi

# 4. bsnes-jg leg (same in every gate; copy verbatim from pi.sh or spirograph.sh)
# ... (see dev/pi.sh §4)

# 5. MAME under Xvfb leg (copy from pi.sh §5; rename the Lua script)
# ... (see dev/pi.sh §5)

if [ "$rc" -eq 0 ]; then
    echo "RESULT: PASS — <Name> on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
    echo "RESULT: FAIL"; fi
exit $rc
```

The bsnes-jg and MAME legs are boilerplate — copy them verbatim from `dev/pi.sh` sections 4
and 5, updating only: the ROM path (`<name>.sfc`), the Lua script path (`dev/<name>.lua`), the
PNG output names, and the settled-frame count passed to `jgxcheck` (500 is a safe default).

The **Lua script** (`dev/<name>.lua`) controls MAME: it reads `SHOT_ADDR` and `SHOT_WANT` from
the environment, waits for `corpus_result` to be set, then emits `SHOT: PASS off=… len=… got=…`
and calls `emu.exit()`. Copy `dev/pi.lua`, change nothing except the demo label in the
`print` call.

---

## Taskfile wiring

Add two entries to `Taskfile.yml`:

```yaml
  <name>:
    desc: "#N: the <Name> compiler-stress demo — <one-line description>."
    cmds:
      - dev/run.sh <name>

  <name>-play:
    desc: "Open build/<name>.sfc in a MAME window (build it first with: task <name>)."
    cmds:
      # copy the mame-play recipe from task mandel-play
      - ...
```

---

## 5-way vs 3-way differential bar

The differential bar tells you which compiler modes agree:

| Bar | Condition | Modes compared |
|-----|-----------|----------------|
| **5-way** | No far pointers (all data in bank-0 WRAM) | host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == default/a16@bsnes-jg |
| **3-way** | Requires far pointers / high WRAM (bank ≥ 1) | host == +mos-a16@MAME == +mos-a16@bsnes-jg |

**Prefer the 5-way bar.** It compiles the same math three ways (8-bit / a16 / xy16) and asserts
they all agree. Far pointers collapse to a16-only. The heat-field demo battery entries (#7, #8,
…) use near WRAM and should build with the 5-way bar.

Build the ROM three times in `dev/run.sh <name>` if you want the xy16 leg:

```bash
for MODE in "" "+mos-a16" "+mos-xy16"; do
    EXTRA=${MODE:+-Xclang -target-feature -Xclang "$MODE"}
    "$TOOL/mos-clang" ... $EXTRA -o "$BUILD/<name>-${MODE:-default}.sfc" ...
done
```

The corpus-a16 harness only needs the `+mos-a16` build (it's the discriminating axis for the
native-16-bit codegen path). Add a `+mos-xy16` corpus slice if the demo stresses index-width
codegen.

---

## CGRAM / animated palettes

CGRAM holds 256 color entries (each 2 bytes, BGR555). The `upq_push_cgram(q, idx, src, bank,
nbytes)` call enqueues a DMA from `src` into CGRAM starting at color `idx`. Call it from your
drawable's `emit()`.

**Palette animation (fire ramps, fades, cycling):** build a `uint16_t pal[N]` in RAM, update
it each frame in `compute_one_frame()`, then push the whole palette in `emit()`. For N ≤ 16
that's 32 bytes — trivial V-blank cost.

**Fire palette example (16-color BG1 ramp):**

```c
static void build_fire_palette(uint16_t *pal, uint8_t frame) {
    // 0 = black, 1..5 = dark red ramp, 6..10 = red→orange, 11..14 = orange→yellow, 15 = white
    static const uint8_t R[16] = {0,10,16,20,24,28,31,31,31,31,31,31,31,31,31,31};
    static const uint8_t G[16] = {0, 0, 0, 2, 4, 6, 8,12,16,20,24,28,30,31,31,31};
    static const uint8_t B[16] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 8,12,16,22,31};
    for (uint8_t i = 0; i < 16; i++)
        pal[i] = SNES_RGB(R[i], G[i], B[i]);
}
```

DMA cost: 16 colors × 2 bytes = 32 bytes — negligible.

**BG3 2bpp (4 colors):** palette 0 = CGRAM[0..3], pushed as `nbytes = 8`.

**BG1 4bpp (16 colors):** palette 0 = CGRAM[0..15], pushed as `nbytes = 32`.

To use all 8 palettes of BG1 (128 colors), push the whole 256-byte block starting at CGRAM[0].
DMA cost: 256 bytes — fits comfortably in one V-blank.

---

## VRAM tilemap DMA budget

Full-screen tilemap re-upload (32×28 × 2 bytes = 1 792 bytes) does NOT fit one V-blank. Your
options:

| Strategy | DMA / frame | Notes |
|----------|-------------|-------|
| **Dirty-range window** (BitmapCanvas model) | ≤ 1 024 B (`CANVAS_FLUSH_TILES = 64`) | Best when most tiles don't change |
| **Smaller field** | e.g. 32×14 × 2 = 896 B | Halve the height; fire only in lower half |
| **Double-buffer + half-rate** | 1 792 B over 2 frames | Visually OK at 30 fps effective |
| **Animated CGRAM only** | 256 B (full palette) | The *palette* is the animation; tiles are static per-cell-value |

For the **doom-fire** demo: the natural design is a small field (`FIRE_W × FIRE_H` tiles where
`FIRE_W × FIRE_H × 2 ≤ 1 536 bytes`) — e.g. 32×23 = 736 entries × 2 = 1 472 bytes. Heat value
0–15 maps to one of 16 tile indices (the "level tiles"), and the palette is the fire ramp. Only
tiles whose heat value CHANGED need a tilemap update — but since fire is pseudo-random and
nearly every cell changes, use a dirty bitmask or just re-upload the full field if it fits.

---

## Extended cartridges — past the 4 MiB wall

Default to LoROM (`platforms/snes`). Reach for a bigger mapping only when the *data* demands it,
and never by padding an image: LoROM and HiROM both top out at exactly 4 MiB, so a 6 MiB LoROM
file is just a 6 MiB file whose top 2 MiB no address reaches.

| Need | Platform | Map mode | Ceiling |
|---|---|---|---:|
| ≤ 32 KiB near code, small assets | `snes` | `$20` | 4 MiB |
| one array > 32 KiB (LoROM's bank window) | `snes-hirom` | `$21` | 4 MiB |
| more than 4 MiB of assets | `snes-exhirom` | `$25` | 8 MiB |

**The one fact to internalise about ExHiROM.** The image is split in two and selected on the
bank's high bit, *inverted*: file `$000000-$3FFFFF` is banks `$C0-$FF`, and file `$400000+` is
banks `$40-$7D`. Because the CPU fetches RESET from `$00:FFFC` and bank `$00`'s upper half
belongs to the **second** region, the header, the vectors and the near-code window live at file
`$408000-$40FFFF` — the boot code is in bank `$40`, not `$C0`. `crt0` needs no change.

That also makes the file **non-monotonic in CPU space**: file `$3FFFFF` is `$FF:FFFF`, and the
next byte, file `$400000`, is `$40:0000`. Anything crossing it must be walked as an ordered
segment list. Combined with the DMA source address not carrying into the bank byte, the rule for
any large asset is the same: **one descriptor per logical object, plus a list of bank-bounded
physical segments** — never a pointer you increment and hope.

**Do not do the arithmetic yourself.** [`tools/snes_cartmap.py`](../tools/snes_cartmap.py) is the
single authoritative model (a port of bsnes-jg's own bus decode). Import it; do not re-derive a
mapping in a packer, a linker generator or a report renderer:

```python
from snes_cartmap import CartMap
cm = CartMap("exhirom", 6 << 20)
cm.describe(0x400000)     # {'physical_rom': 1, 'cpu_bank': 0x40, 'cpu_address': 0x0000, ...}
cm.file_to_cpu(0x5FFFFF)  # (0x5F, 0xFFFF) -- the ONE canonical address; raises on a hole
cm.max_dma_span(0x3FFE00) # bytes before the transfer must be split
cm.holes()                # ranges present in the file that nothing can address
```

Checklist for an over-4-MiB demo:

- link with `platforms/snes-exhirom` (its `link.ld` is generated from the model, and a host test
  asserts the checked-in copy still matches);
- patch the header with `tools/snes-checksum.py --mapping exhirom` — the ROM-size byte and the
  checksum describe the **mirrored logical** size (4+2 MiB checksums as 8 MiB:
  `sum(big) + 2*sum(small)`), not the file length;
- verify with `tools/snes-checksum.py --inspect`, which also reports what bsnes-jg's heuristics
  will actually detect the image as; and
- before trusting a new size, add it to `dev/run.sh cartsize-canary` — the canary ROM reads the
  first and last byte of every decoded window, every accepted mirror, and spans crossing one
  bank, several banks and the physical device boundary, on real emulators.

Plan: [`docs/plans/2026-07-30-exhirom-video-boundary-test.md`](plans/2026-07-30-exhirom-video-boundary-test.md).
Geometry, holes and checksum rules:
[`docs/refs/snes-hardware/snes-hardware-summary.md`](refs/snes-hardware/snes-hardware-summary.md).

---

## V-blank timing rule

The SNES V-blank is short. Never run game logic inside the V-blank; only the
`upq_flush()` DMA runs there. The frame loop is:

```
active display → compute_one_frame()  ← all your C code runs here
v-blank        → emit() → upq_flush() ← only DMA (CPU stalled by hardware)
active display → ...
```

`display_frame()` encapsulates this: it waits for the NEXT v-blank (discarding a stale flag
via `(void)REG_RDNMI`), calls each drawable's `emit()` to fill the queue, then calls
`upq_flush()` to drain it.

---

## Idle-loop rule (forward progress)

**Never write a bare `for (;;) {}` / `while (1);` — including a body that is only a
comment.** C11 forward-progress rules let LLVM delete a side-effect-free infinite loop, and
`main` then falls through into a reset loop. The differential gates assert only WRAM and are
*insensitive* to reset loops, so an affected demo passes silently with a broken display —
this bit the cartsize canary (`3e80748`/`92c1b74`) before the repo-wide sweep (`903de3e`,
2026-08-01: 338 sites audited, 216 bare loops fixed across 214 files).

The house idiom for a terminal halt:

```c
for (;;) __asm__ volatile("wai");
```

Inline asm is never DCE'd, so the loop survives at any optimization level; `wai` also
parks the CPU. It is correct with or without NMI enabled — these are terminal halts, and
the gates read memory, not continued execution. A *frame loop* needs no idiom: a body that
calls `display_frame()` (or otherwise touches volatile MMIO every iteration) is not
removable.

---

## Publication (`/snes-rom-page`)

After the gate passes, invoke the `/snes-rom-page` skill. Inputs:

- `--rom build/<name>.sfc`
- `--slug <url-slug>` (e.g. `doom-fire`)
- `--site /home/will/biohack.net`
- `--title "Doom Fire"` (display name)
- `--preview /tmp/<name>-preview.png` (256×224 screenshot from the gate)
- `--selfcheck "0xOFF LEN 0xWANT FRAMES label"` (WRAM gate assert; OFF from the `.map`)

The skill:
1. Runs `scaffold.sh` (copies ROM + engine + preview + manifest entry).
2. Scaffolds `src/pages/snes/<slug>.astro` from `page-template.astro` with ROM-specific text.
   The template includes a **Fullscreen** button (`id="fullscreen"`) wired in `app.js` — it
   fullscreens the canvas wrapper and toggles to "Exit full"; hidden on browsers without the API.
3. Adds a gallery card to `src/pages/snes/index.astro`.
4. Builds the site, headless-screenshots the live page.
5. Commits + `task release` (auto-bumps the patch version + deploys to Cloudflare Pages).

Use a MAME screenshot as the preview (the `$SNAP/snes/0000.png` the gate emits). The selfcheck
offset comes from `awk '$NF=="corpus_result"' build/<name>.map`.

---

## Plan doc template

Write `docs/plans/YYYY-MM-DD-N-snes-<name>.md` before coding. Sections (in order):

```markdown
# #N — SNES <Name>: <tagline>

**Status:** PLANNED. Demo **#N** of the **compiler stress-test demo battery**
([ideas](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md); TODO.md → #N).
...

## Context
What it renders, why it's a distinct test vs the other demos, codegen corners it hits.

## Algorithm
Pseudocode for the hot loop (what the compiler has to optimise). Explicit `uint16_t`/`uint32_t`
types; no bare `int`. Mark which operations map to `__mulsi3`, `__udivsi3`, `rep`/`sep`, etc.

## Screen layout
ASCII art of the 32×28 tile grid, showing BG assignments, palette regions, HUD.

## Display architecture
Which drawables. Which BG layers. VRAM layout (chr base word, tilemap base word). Palette map.
V-blank DMA budget (bytes per frame for each upload).

## Cartridge ROM map
A visual Mermaid bank map plus an exact table generated from the final linker
map. Cover every bank in the cartridge image, including code/rodata,
header/vectors, assets, and padding. For each occupied bank list every section
or asset and its byte size; for every bank list used, capacity, and free bytes.
The plan must name the mapping type and total ROM size. Never infer these
figures from source arrays when the linker map can provide final aligned sizes.

## Files
Table: new files + modified files, one-line purpose each.

## Reused infrastructure
Table: asset → from → used for. Avoids duplicating what's already in snesgfx / the 65816 headers.

## Differential gate
- `corpus_result` definition (what it folds, and at what GATE_N).
- `EXPECT` value (fill in after first run).
- 5-way or 3-way bar decision and rationale.
- Disasm probes (what to grep for in the corpus object).

## Publication
/snes-rom-page invocation with the exact arguments.

## Verification steps
Numbered list (these become the plan's PASS/FAIL record):
1. Build + smoke (MAME boots, corpus_result == EXPECT).
2. Publish (snes-rom-page, live screenshot, gallery updated).
3. 4-way / 5-way differential gate (corpus-a16 all PASS).
4. Regression check (existing corpus suite unchanged).
5. `task md -- docs/plans/...` plan renders cleanly.
```

After coding, paste raw command output under each step and mark `PASS` or `FAIL`. Then add a
one-line entry to `docs/investigations/plan-index.md` and mark the TODO item `[x]`.

---

## Quick checklist

Before calling a demo "done":

- [ ] Plan doc written, TODO item marked `[wip]` (not `[x]` yet).
- [ ] Plan contains a generated visual cartridge ROM map and exact per-bank
      used/free/section-size table from the final link map.
- [ ] `examples/65816/<name>.h` compiles both host-side and as part of the SNES ROM.
- [ ] `examples/snes/corpus/<name>_sim.c` wired into `corpus-a16` and **PASS**.
- [ ] `tools/<name>-sim.c` prints the same hash the corpus slice produces on SNES.
- [ ] `dev/<name>.sh` passes: disasm probe PASS + bsnes-jg PASS + MAME PASS.
- [ ] `Taskfile.yml` entries added.
- [ ] `/snes-rom-page` run; biohack.net headless screenshot shows the ROM playing.
- [ ] `dev/run.sh corpus-a16` — all slices still PASS (no regressions).
- [ ] `dev/run.sh corpus` — existing default-8bit suite still PASS.
- [ ] Plan verification steps filled in with raw output + PASS/FAIL.
- [ ] `docs/investigations/plan-index.md` row added.
- [ ] TODO item promoted to `[x]` and moved to Done section.

---

## Reference: worked examples

| Demo | ROM | Algorithm header | Gate script | Key technique |
|------|-----|-----------------|-------------|---------------|
| **π Spigot + Monte-Carlo (#19)** | `examples/snes/spigot.c` | `examples/65816/pi_spigot.h` | `dev/pi.sh` | Carry-chain div/mod + 16×16→32 mul; custom `PiHud` drawable |
| **Descending memmove Scroll Slabs (#79)** | `examples/snes/mvscrl.c` | `examples/65816/mvscrl.h` | `dev/mvscrl.sh` | Overlapping `G_MEMMOVE` both directions (Descending/Ascending legalization); full 5-way bar; dual V-ring 60 fps scroll presentation |
| **Truncation Staircase (#83)** | `examples/snes/truncstair.c` | `examples/65816/truncstair.h` | `dev/truncstair.sh` | `G_FPTOSI`/`G_SITOFP` softfloat casts (truncf-via-cast); 60 fps repaint-on-change + banded `BG3HOFS` scroll ring |
| **N-body Orbits (#13)** | `examples/snes/n-body.c` | `examples/65816/n-body.h` | `dev/n-body.sh` | `__mulsi3` (r²) + `__udivsi3` (1/r²); `noinline` to cap RA pressure; CGRAM palette fade |
| **Blossom (Hopalong)** | `examples/snes/blossom.c` | (inline) | `dev/blossom.sh` | `hud.h` HDMA `BGMODE`/`TM` screen split (Mode 7 plot band + BG3 text bars); far high-WRAM scatter (a16-only); CGRAM palette cycling |
| **Mandelbrot, doubles** | `examples/snes/mandel-double.c` | `examples/65816/mandel-double.h` | `dev/mandel-double.sh` | `mandel-display.c` shared Mode 7 chunky module; line-at-a-time reveal; `BGMODE_1` title splash; far 16×16 title font (`TITLE_FONT16_FAR`) |
| **Space Invaders** | `examples/snes/invaders.c` | `examples/snes/invaders_logic.h` | `dev/invaders*` | `SpriteSet`; the full OOP `snesgfx` showcase |
| **LZSS Gallery** | `examples/snes/lzss-gallery.c` | `examples/65816/lzss.h` | `dev/lzss-gallery.sh` | Far ROM asset descriptors + LZSS far→near decode; on-console repack self-check differential; reserved sprite CGRAM 224–255; hand-written asm thunks must preserve the A:X argument ABI (the `decode_bank7e` lesson) |

The `spigot.c` + `pi_spigot.h` pair remains the **canonical template** for the full pattern
end-to-end; `mvscrl.c` is the most **modern gate/corpus exemplar** (5-way bar + 60 fps
presentation + precise legalizer-corner comments) — read both before writing a new demo. The
**LZSS Gallery** is a *reference*, not a template: by far the largest demo, read it for the
far-data, self-check, and dashboard patterns rather than as a starting skeleton.

Gallery source integrity is part of correctness. Vendor one reproducible,
full-composition master for every work and record its object page, exact file
identity, dimensions, license, and SHA-256. Reject detail crops, presentation
frames, watermarks, and gigapixel tiles such as filenames ending in `x0-y1`;
those can produce a technically valid palette and LZSS stream for the wrong
image. The 2026-08-01 La Grande Jatte correction is the regression example:
the former tile was replaced by the complete 1280×852 public-domain master,
then every indexed, palette, stream, packing, target-decode, and preview
artifact was regenerated from it.
