---
name: snes-demo
description: >-
  Build and publish a new SNES compiler stress-test demo: write the plan, implement the
  algorithm header + ROM + corpus slice + host oracle + gate script, run the differential
  gate, and publish to biohack.net via /snes-rom-page. Works from a one-line description
  like the entries in 2026-06-27-compiler-stress-test-demo-ideas.md.
whenToUse: >-
  When the user asks to implement a numbered demo from the SNES compiler stress-test battery,
  describes a new SNES demo to build, or says "build #N" / "implement the <name> demo".
---

# snes-demo

End-to-end recipe for a new SNES ROM in the compiler stress-test battery
(the `llvm-mos-65816` project root — `git rev-parse --show-toplevel`).

**This skill is self-contained.** All SNES hardware reference, snesgfx API, gate-script
templates, and the plan-doc template are inlined below. You do not need to separately read
`docs/snes-demo-cookbook.md` — this file supersedes it. Do read `docs/agent-handoff.md`
(build mechanics: `dev/run.sh`, Docker env, toolchain paths) and `CLAUDE.md` (commit
discipline) before starting.

---

## Inputs

Gather these before writing a line of code:

- **Demo ID and tagline** — e.g. "#7 Doom-fire: per-cell decay + PRNG, palette ramp".
- **Algorithm description** — the hot loop, the codegen corners it stresses, the visual output.
- **Slug** — URL path, lowercase `[a-z0-9-]`, e.g. `doom-fire`. Used for the ROM filename,
  gate script, Taskfile entry, biohack.net page URL, and snes-rom-page arguments.
- **5-way or 3-way bar** — does the demo need far pointers / high WRAM?
  - No far pointers, all data in bank-0 WRAM → **5-way** (host == default@MAME == +mos-a16@MAME
    == +mos-xy16@MAME == default/a16@bsnes-jg).
  - Requires far pointers / data in bank ≥ 1 → **3-way** (host == +mos-a16@MAME == +mos-a16@bsnes-jg).
  - **Prefer 5-way** — it compiles the same math three ways and asserts they all agree.
- **Key codegen probes** — what to grep for in the disasm: `__mulsi3`, `__udivsi3`,
  `__udivmodsi4`, `rep`/`sep`, etc.

---

## SNES hardware budget

**Display:** 256×224 pixels NTSC.

**PPU Mode 1** (selected by `display_init()`, never changed):
- **BG1** — 4bpp tilemap, 16 colors × 8 palettes = 128 unique colors.
- **BG2** — 4bpp tilemap (same range).
- **BG3** — 2bpp tilemap, 4 colors × 8 palettes = 32 unique colors.
- **OBJ** — sprites.

All existing demos use **BG3 2bpp** for text/HUD (via `TextLayer` or a custom drawable).
Add BG1 or BG2 for a full-color layer when you need more than 4 colors per tile.

**Tiles:** 8×8 pixels. A 256×224 screen = 32×28 = 896 tilemap entries (2 bytes each).
- 2bpp: 8 words/tile = 16 bytes.
- 4bpp: 16 words/tile = 32 bytes.

**CGRAM:** 256 color registers (15-bit BGR555). `SNES_RGB(r,g,b)` where r/g/b ∈ 0–31.
BG3 palette 0 = CGRAM[0..3], palette 1 = CGRAM[8..11], …, palette 7 = CGRAM[56..63].
BG1 palette 0 = CGRAM[0..15], …, palette 7 = CGRAM[112..127].
Upload palette data with `upq_push_cgram()` from inside `emit()`.

**V-blank DMA budget (NTSC):** ≈ 4 200 CPU cycles ≈ 2 100 bytes/frame.
Budget conservatively at **1 536 bytes/frame** (1.5 KiB) for safety.
- A tilemap row: 32 entries × 2 bytes = 64 bytes → max **24 rows/frame**.
- A 32×28 full-screen tilemap (1 792 bytes) does **not** fit one V-blank — cap with a
  dirty-range window or split over 2 frames.
- `BitmapCanvas` caps at `CANVAS_FLUSH_TILES = 64` tiles × 16 bytes = **1 024 bytes**.
- Full-palette CGRAM push: 256 colors × 2 bytes = **512 bytes**.

---

## snesgfx component guide

All headers live in `examples/snes/snesgfx/`. Include them in the SNES ROM file only.

| Header | What it provides | When to use |
|--------|-----------------|-------------|
| `display.h` | `Display` struct, `display_init()`, `display_add()`, `display_frame()` | Always — the frame loop |
| `drawable.h` | `Drawable` vtable base (`reserve`/`emit` pair) | Always — base of every layer |
| `scene.h` | `Scene` container of up to `SCENE_MAX` (4) `Drawable*` | Always (owned by Display) |
| `upload.h` | `UploadQueue`, `upq_push_vram/cgram/oam()`, `upq_flush()` | Always (owned by Display) |
| `vram.h` | `VramAlloc` bump allocator | Always (owned by Display) |
| `bitmap_canvas.h` | `BitmapCanvas` — 2bpp canvas of N×M tiles, set-pixel + Bresenham + capped DMA | Scatter plots, pixel drawing, line drawing |
| `text_layer.h` | `TextLayer` — **2-row HUD only** (TEXT_NROWS = 2); font8.h glyphs into BG3 tilemap | Two HUD bars (top + bottom) |
| `sprite_set.h` | `SpriteSet` — OAM sprite manager | Sprites |
| `controller.h` | Joypad polling helpers | Interactive demos |

**`TextLayer` limitation:** it only supports 2 HUD rows. For full-screen text (e.g. a
digit display covering 27+ rows), write a **custom Drawable** — see the `PiHud` pattern in
`examples/snes/spigot.c:44–200` as the canonical model.

**Rule: never write to PPU ports outside `emit()`.** All VRAM/CGRAM/OAM writes go through
`upq_push_*()` → `upq_flush()`, which Display guarantees is called only during V-blank.
Exception: `reserve()` runs in force-blank, so direct `REG_VMDATA` writes are safe there.

**The frame loop** is always the same three calls:

```c
Display d;
display_init(&d);
display_add(&d, (Drawable *)&my_layer);   // calls reserve() in force-blank
for (;;) {
    compute_one_frame();       // game logic (runs during active display)
    display_frame(&d);         // wait v-blank → emit() → DMA flush
}
```

---

## Writing a custom Drawable

Use this when `TextLayer` and `BitmapCanvas` don't cover your layout. Model: `PiHud` in
`examples/snes/spigot.c:44`.

```c
#define FONT_BASE 256   // tile# where font8.h glyphs start (matches spigot.c convention)

typedef struct {
    Drawable base;           // MUST be first
    uint16_t map_word;       // BG3 tilemap base word (e.g. 0x4000)
    uint16_t shadow[ROWS * COLS];  // local VRAM tilemap mirror
    uint32_t dirty_rows;     // bitmask: bit i → row i needs re-DMA
} MyLayer;

static void _my_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    MyLayer *l = (MyLayer *)d;
    // Load font8.h glyphs into BG3 chr VRAM at tile FONT_BASE (force-blank: direct write OK).
    snes_vram_addr((uint16_t)(FONT_BASE * 8));
    for (uint16_t i = 0; i < (uint16_t)FONT8_N * 8; i++) REG_VMDATA = FONT8[i];
    // Set BG3 chr base (BG34NBA low nibble = chr_word >> 12).
    REG_BG34NBA = (uint8_t)((CANVAS_CHR >> 12) & 0x0Fu);
    // Set BG3 tilemap base.
    REG_BG3SC = SNES_BGSC(l->map_word, 0);
    // Fill shadow with FONT_BASE (space tile).
    for (uint16_t i = 0; i < ROWS * COLS; i++) l->shadow[i] = FONT_BASE;
    l->base.tm_bits = TM_BG3;   // enable BG3 on main screen
    l->dirty_rows = (uint32_t)((1u << ROWS) - 1u);   // all rows dirty
}

static void _my_emit(Drawable *d, UploadQueue *q) {
    MyLayer *l = (MyLayer *)d;
    for (uint8_t i = 0; i < ROWS && q->n < UPQ_MAX_JOBS; i++) {
        if (!(l->dirty_rows & (uint32_t)(1u << i))) continue;
        upq_push_vram(q, (uint16_t)(l->map_word + (uint16_t)i * COLS),
                      &l->shadow[(uint16_t)i * COLS], 0x00u,
                      COLS * 2u, VMAIN_INC_HIGH_1);
        l->dirty_rows &= ~(uint32_t)(1u << i);
    }
}

static const DrawableVT MY_VT = { _my_reserve, _my_emit };
// Init: l->base.vt = &MY_VT; l->map_word = MAP_WORD;
```

The `emit()` guard `q->n < UPQ_MAX_JOBS` naturally caps DMA to the V-blank budget
(`UPQ_MAX_JOBS = 16` jobs × 64 bytes/row = 1 024 bytes). Adjust to your row width.

**BG3 VRAM layout used by spigot.c (the reference):**
- `CANVAS_CHR = 0x0000` — BG3 chr base word (canvas tiles 0..255, then font at tile 256).
- `CANVAS_MAP = 0x4000` — BG3 tilemap base word.
- Font at tile 256 → chr word 2 048 (256 × 8 words).
- When you have **no BitmapCanvas**, you still place the font at tile 256 and the tilemap at
  `0x4000` — same convention, just `tm_bits = TM_BG3` (not 0) because no canvas enables BG3 first.

---

## The algorithm header (`examples/65816/<slug>.h`)

This is the **portable, host-compilable** logic. The differential gate requires it to compile
identically on both host (64-bit x86, 32-bit `int`) and target (16-bit `int` on 65816):

**Width rules:**
- Use `int16_t`/`uint16_t` and `int32_t`/`uint32_t` everywhere (`<stdint.h>`).
- **Never use bare `int`** — it's 32-bit on host, 16-bit on target. Any `int` arithmetic is
  a gate bug, not just a lint warning.

**Arithmetic rules:**
- `(int16_t)a * (int16_t)b` promotes to `int` on host (32-bit) but stays 16-bit on target —
  wrap in `(int32_t)a * (int32_t)b` if you need a 32-bit result.
- 32-bit multiply → `__mulsi3`; 32-bit divide → `__udivsi3`/`__divsi3`; combined div+mod in
  the same expression → `__udivmodsi4`.

**Gate hash pattern:**
```c
#define GATE_N 100u   // iterations; keep ≤ 120 SNES frames of computation

static inline uint16_t <slug>_gate_crc(void) {
    uint16_t h = 0;
    // run GATE_N steps of the algorithm ...
    h = (uint16_t)((h << 1) | (h >> 15)) ^ (uint16_t)step_result;
    return h;
}
```

**xorshift16 RNG** (copy from `invaders_logic.h` if your demo uses randomness):
```c
static uint16_t rng_state = 0xBEEFu;
static inline uint16_t rng16(void) {
    rng_state ^= (uint16_t)(rng_state << 7);
    rng_state ^= (uint16_t)(rng_state >> 9);
    rng_state ^= (uint16_t)(rng_state << 8);
    return rng_state;
}
```

---

## Steps

Work through these in order. **Plan first; never start coding without it.**

### 1 — Write the plan

File: `docs/plans/YYYY-MM-DD-N-snes-<slug>.md` (date = today, N = battery ID).

Template (fill in all sections):

```markdown
# #N — SNES <Name>: <tagline>

**Status:** PLANNED. Demo **#N** of the **compiler stress-test demo battery**.

## Context
What it renders, why it is a distinct test vs the other demos, which codegen corners it hits.

## Algorithm
Pseudocode for the hot loop. Explicit `uint16_t`/`uint32_t` types; no bare `int`. Mark which
operations map to `__mulsi3`, `__udivsi3`, `__udivmodsi4`, `rep`/`sep`, etc.

## Screen layout
ASCII art of the 32×28 tile grid (BG assignments, palette regions, HUD).

## Display architecture
Which drawables. Which BG layers. VRAM layout (chr base word, tilemap base word).
Palette map (CGRAM offsets). V-blank DMA budget (bytes/frame for each upload type).

## Files
Table: new files + modified files, one-line purpose each.

## Reused infrastructure
Table: asset → from → used for.

## Differential gate
- `corpus_result` definition (what it folds, at what GATE_N).
- `EXPECT` value (fill in after first successful run).
- 5-way or 3-way bar and rationale.
- Disasm probes (what to grep for in the corpus object).

## Publication
/snes-rom-page invocation with exact arguments.

## Verification steps
1. Host oracle compiles and prints a plausible CRC.
2. ROM builds clean; snes-checksum.py exits 0.
3. Corpus slice host-compiles; ./a.out exits 0.
4. `dev/run.sh <slug>` — host oracle + disasm gate + bsnes-jg + MAME all PASS.
5. `dev/run.sh corpus-a16` — all slices PASS.
6. /snes-rom-page publishes; headless screenshot shows the ROM running.
7. `task md -- docs/plans/...` renders cleanly.
```

Add a `[wip]` TODO entry under "Compiler stress-test demo battery" in `TODO.md` with a
`([plan](docs/plans/...))` link.

Add a row to `docs/investigations/plan-index.md` (one line, same format as existing rows).

### 2 — Implement the algorithm header

File: `examples/65816/<slug>.h`

- Portable C99, `<stdint.h>` only. No bare `int`.
- Include state structs, init, and per-frame step functions.
- Include `<slug>_gate_crc()` — pure function, folds `GATE_N` iterations into a `uint16_t`.
- Includes xorshift16 RNG if the demo uses randomness.

Host-compile sanity check:
```bash
cc -O2 -std=c99 -I examples examples/snes/corpus/<slug>_sim.c -o /tmp/<slug>-host && /tmp/<slug>-host
```

### 3 — Corpus slice

File: `examples/snes/corpus/<slug>_sim.c`

```c
/* Corpus slice: <slug> HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean. */
#include "../../65816/<slug>.h"

static <StateType> s;   // static to avoid large soft-stack frame

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = <slug>_gate_crc();
    for (;;) {}
    return 0;
}
```

Key rules:
- `volatile uint16_t corpus_result;` declared **before** the header include (matching pi_sim.c).
- State is `static` (not local) to keep the soft-stack frame small.
- `for (;;) {}` after the assignment (the harness reads WRAM and kills the emulator externally).

The corpus harness picks up all `*_sim.c` files automatically — no Taskfile wiring needed.

### 4 — Host oracle

File: `tools/<slug>-sim.c`

```c
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/<slug>.h"

int main(void) {
    printf("<slug> gate_crc = 0x%04X\n", <slug>_gate_crc());
    return 0;
}
```

The gate script compiles this with `cc -O2 -I examples` and captures the output.

### 5 — SNES ROM

File: `examples/snes/<slug>.c`

- Include `<snes.h>` and the snesgfx headers.
- Declare `volatile uint16_t corpus_result;` as a named global (linker-map → WRAM address).
- Assign `corpus_result = <slug>_gate_crc()` before the main loop starts (or every N frames).
- Refer to `examples/snes/spigot.c` as the canonical template — read it fully before writing.
- For new display requirements not in existing snesgfx headers, write a local `typedef Drawable`
  inside `<slug>.c` (like `PiHud` in `spigot.c`). See the *Writing a custom Drawable* section.
- State struct goes `static App a;` in main() to avoid soft-stack pressure.

### 6 — Gate script

File: `dev/<slug>.sh` (copy `dev/pi.sh`; make executable with `chmod +x`)

Edit these parts only:
- ROM name: `spigot` → `<slug>`, `pi` → `<slug>` throughout.
- §3 disasm probes: replace `__udivmodsi4`/`__mulsi3` with the ops your demo stresses.
- Lua script: `dev/pi.lua` → `dev/<slug>.lua`.
- RESULT message label.

File: `dev/<slug>.lua` — copy `dev/pi.lua`, change the print label only:
```lua
print(string.format("SHOT: PASS corpus=0x%04X (snapshot at frame %d)", v, f))
-- change "π spigot+MC" label in the comment at the top
```

**Full gate-script structure** (5 sections from `dev/pi.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh <slug>"; exit 0;; esac

ROOT=/work; BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain"; exit 1; }
[ -f "$CFG" ]            || { echo "FATAL: SDK not built"; exit 1; }

# §1. Host oracle
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/<slug>-sim.c" -o "$BUILD/<slug>-sim"
EXPECT=$("$BUILD/<slug>-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: $EXPECT"

# §2. Build ROM (+mos-a16) and locate corpus_result in the map
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/<slug>.map" -o "$BUILD/<slug>.sfc" \
  "$ROOT/examples/snes/<slug>.c"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/<slug>.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/<slug>.map")
OFF="0x$VMA"; ADDR=$(printf '0x%X' $((0x7E0000 + 0x$VMA)))
echo "==> built build/<slug>.sfc; corpus_result @ WRAM $OFF"

rc=0

# §3. Disasm probe — edit these for your demo's codegen corners
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/<slug>_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/<slug>_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/<slug>_sim.o" 2>/dev/null || true)
div=$(printf '%s\n' "$dis" | grep -c '__udivmodsi4' || true)   # edit as needed
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$div" -ge 1 ] && [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __udivmodsi4=$div  __mulsi3=$mul  rep/sep=$rs"
else
  echo "    FAIL  __udivmodsi4=$div  __mulsi3=$mul  rep/sep=$rs  (expected all >= 1)"; rc=1
fi

# §4. bsnes-jg (copy verbatim from dev/pi.sh §4 — only ROM path and label change)
JGX="$BUILD/jgxcheck"; VENDOR="$ROOT/vendor/bsnes-jg"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" \
        -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert"
  "$JGX" "$BUILD/<slug>.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/<slug>-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# §5. MAME under Xvfb (copy verbatim from dev/pi.sh §5 — ROM path + Lua script change)
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert"
  SNAP="$BUILD/.<slug>-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/<slug>.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/<slug>.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/<slug>-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — <Name> on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"; fi
exit $rc
```

Wire into `Taskfile.yml`:

```yaml
  <slug>:
    desc: "#N: <tagline> — assert corpus_result (0x<EXPECT>) == host on MAME + bsnes-jg + disasm gate. Leaves build/<slug>.sfc + build/<slug>-{mame,jg}.png."
    cmds:
      - dev/run.sh <slug>

  <slug>-play:
    desc: "PLAY the <Name> demo in a MAME window (build first with: task <slug>)."
    cmds:
      - |
        set -euo pipefail
        if [ ! -f build/<slug>.sfc ]; then
          echo "==> build/<slug>.sfc missing — building (dev/run.sh <slug>)…"
          dev/run.sh <slug>
        fi
      - task: mandel-mame
        vars: { ROM: <slug> }
```

### 7 — Run the gate

```bash
dev/run.sh <slug>
```

**Failure triage:**
- `SHOT: FAIL off=X len=Y got=0x0000` → `corpus_result` not set before the frame count expires.
  Reduce `GATE_N` or increase `--seconds_to_run` in the gate script.
- Disasm probe FAIL → compiler inlined/eliminated the hot call. Add
  `__attribute__((noinline))` to the hot function, or increase `GATE_N`.
- bsnes-jg mismatch → real miscompile (or stale build — run `dev/run.sh toolchain` first).

Fill in `EXPECT` in the plan doc after the first successful run.

### 8 — Corpus-a16 suite

```bash
dev/run.sh corpus-a16
```

All slices must PASS. If any regress, investigate before proceeding.

### 9 — Publish

Invoke `/snes-rom-page` with:

```
--rom build/<slug>.sfc
--slug <slug>
--site ~/SRC/biohack.net
--title "<Display Title>"
--preview build/<slug>-mame.png
--selfcheck "0x<VMA> 2 0x<EXPECT> 500 <label>"
```

`VMA` (WRAM offset of `corpus_result`):
```bash
awk '$NF=="corpus_result"{print $1; exit}' build/<slug>.map
```

### 10 — Close out

- Paste raw output of each verification step into the plan doc, then mark `PASS` or `FAIL`.
- Mark the TODO item `[x]` and move it to the Done section (one tight line, ≤ 150 chars).
- Update `docs/investigations/plan-index.md` with the commit SHA.
- Commit — stage only your files:
  `examples/65816/<slug>.h`, `examples/snes/<slug>.c`,
  `examples/snes/corpus/<slug>_sim.c`, `tools/<slug>-sim.c`,
  `dev/<slug>.sh`, `dev/<slug>.lua`,
  `Taskfile.yml`, `TODO.md`, `docs/plans/…`, `docs/investigations/plan-index.md`.
  End the commit message with:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

## Codegen corners quick-reference

| Demo wants to stress | Ops to probe | Notes |
|----------------------|--------------|-------|
| 32-bit multiply | `__mulsi3` / `__mulsf3` | `(int32_t)a * b` on the hot path |
| 32-bit divide | `__udivsi3` / `__divsi3` | `(uint32_t)a / b` |
| Combined div+mod | `__udivmodsi4` | clang emits this when both quot and rem are used in the same expr |
| Native 16-bit | `rep` / `sep` | Always present under `+mos-a16` when native-s16 ops fire |
| Array sweep | Size of inner loop (objdump -d) | Wide arrays → lots of `lda/sta (zp)` pairs |
| PRNG / bitops | `eor` / `asl` / `lsr` count | xorshift16 shows up as native 16-bit shifts under `+mos-a16` |
| CGRAM animation | DMA byte count per frame | Keep ≤ 256 bytes for palette; verify ≤ 1 536 B total DMA |

---

## CGRAM / animated palettes

`upq_push_cgram(q, idx, src, bank, nbytes)` enqueues DMA into CGRAM starting at color `idx`.
Call from your drawable's `emit()`.

For **palette animation** (fire ramps, fades, cycling): build `uint16_t pal[N]` in RAM, update
each frame in `compute_one_frame()`, push in `emit()`. For N ≤ 16 that's 32 bytes — trivial.

**BG3 2bpp (4 colors):** palette 0 = CGRAM[0..3], pushed as `nbytes = 8`.
**BG1 4bpp (16 colors):** palette 0 = CGRAM[0..15], pushed as `nbytes = 32`.

To use all 8 BG1 palettes (128 colors), push 256 bytes starting at CGRAM[0].
DMA cost: 256 bytes — fits comfortably in one V-blank.

---

## VRAM tilemap DMA budget

Full-screen tilemap re-upload (32×28 × 2 = 1 792 bytes) does NOT fit one V-blank.

| Strategy | DMA / frame | Notes |
|----------|-------------|-------|
| **Dirty-range window** (BitmapCanvas model) | ≤ 1 024 B (`CANVAS_FLUSH_TILES = 64`) | Best when most tiles don't change |
| **Per-row dirty bitmask** (PiHud model) | 64 B/dirty row; cap via `q->n < UPQ_MAX_JOBS` | Best for text; each row = 64 B |
| **Smaller field** | e.g. 32×14 × 2 = 896 B | Halve the height |
| **Double-buffer + half-rate** | 1 792 B over 2 frames | Visually OK at 30 fps effective |
| **Animated CGRAM only** | 256 B (full palette) | Palette is the animation; tiles are static |

---

## Working examples

| Demo | ROM | Algorithm header | Gate script | Key technique |
|------|-----|-----------------|-------------|---------------|
| **π Spigot + Monte-Carlo (#19)** | `examples/snes/spigot.c` | `examples/65816/pi_spigot.h` | `dev/pi.sh` | Carry-chain div/mod + 16×16→32 mul; custom `PiHud` drawable |
| **N-body Orbits (#13)** | `examples/snes/n-body.c` | `examples/65816/n-body.h` | `dev/n-body.sh` | `__mulsi3` (r²) + `__udivsi3` (1/r²); `noinline` to cap RA pressure; CGRAM fade |
| **Spirograph (#11)** | `examples/snes/spirograph.c` | `examples/65816/spiro.h` | `dev/spirograph.sh` | Sin/cos LUT + mul; `BitmapCanvas` + `TextLayer` |
| **Bignum Factorial (#20)** | `examples/snes/factorial.c` | `examples/65816/factorial.h` | `dev/factorial.sh` | base-10000 bignum; `__mulsi3` + `__udivmodsi4`; custom 28-row `FactDisplay` |

**`spigot.c` + `pi_spigot.h` is the canonical template** — the most recent, cleanest, and best-commented example of the full pattern. Read it before writing a new demo.

---

## Sanity checks at each stage

- **After writing the header:** host-compile succeeds; host oracle prints a plausible hash.
- **After writing the corpus slice:** `cc` compiles it; `./a.out` exits 0.
- **After writing the ROM:** `mos-clang --config ... -o build/<slug>.sfc ...` succeeds;
  `snes-checksum.py` exits 0.
- **After the gate:** both emulators agree with the host oracle; disasm probes all ≥ 1.
- **After publication:** headless screenshot of `http://localhost:8799/<slug>/` shows the ROM
  running (not a blank page or "ROM failed to load").
