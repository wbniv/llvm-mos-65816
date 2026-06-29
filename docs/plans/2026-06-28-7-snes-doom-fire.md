# #7 — SNES Doom-fire: per-cell decay + PRNG, palette ramp

**Status:** DONE + PUBLISHED (2026-06-28). Demo **#7** of the **compiler stress-test demo battery**.
Gate `0x3C59`; `dev/run.sh doom-fire` RESULT PASS (bsnes-jg + disasm; MAME SKIP env-wide). Live at
[biohack.net/snes/doom-fire/](https://biohack.net/snes/doom-fire/).

## Context
Renders the classic **Doom PSX fire** effect: a 32×28 heat grid whose bottom row is a constant
max-heat source; every frame each interior cell inherits the cell below it minus a random decay,
with a random horizontal drift, so flames rise and flicker. The heat value (0..15) indexes a 16-entry
black→red→orange→yellow→white palette uploaded to CGRAM; the grid is drawn as 32×28 solid-colour
8×8 tiles on **BG1 4bpp** (one tile per cell, like rdiff #8).

Why it is a distinct compiler test vs the others:
- **Array sweep** — a full-grid flat-index scan (`fire[src]` read, `fire[dst]` write) every frame:
  the hottest loop is `lda (zp),y` / `sta (zp),y`-class indexed byte accesses over an 896-byte array.
  No demo so far stresses a plain 8-bit array sweep with a *variable* write offset.
- **PRNG** — an xorshift16 per non-zero cell; under `+mos-a16` the `^`/`<<`/`>>` become native
  16-bit `eor`/`asl`/`lsr` inside one `rep`/`sep` bracket.
- **CGRAM** — the visual *is* the palette ramp (16 colours pushed every frame, 32 B).

Unlike rdiff (#8, heavy 32-bit mul-add) and 1d-ca (#6, pure boolean rows), fire is **multiply-free /
divide-free**: the stress is the indexed array traffic + the PRNG, not the ALU libcalls.

## Algorithm
Flat-index propagation (closer to Fabien Sanglard's original than an (x,y) form, and it avoids a
per-cell `y*W` multiply). Heat ∈ `[0, FIRE_MAX=15]`; bottom row pinned at `FIRE_MAX`.

```
fire_step(uint8_t *fire, int16_t W, int16_t H, uint16_t *rng):
    int16_t cells   = W * H                    # one mul/call (not per cell)
    int16_t srcrow0 = (H - 1) * W              # first index of the source row
    for src in W .. cells-1:                   # rows 1..H-1, top→bottom
        pixel = fire[src]
        if pixel == 0:
            fire[src - W] = 0                   # cool cell above
        else:
            r   = xorshift16(rng)              # native-16 eor/asl/lsr under rep/sep
            rnd = r & 3                         # {0,1,2,3}
            dst = src - W + 1 - rnd             # row above, drift {+1,0,-1,-2}
            if 0 <= dst < srcrow0:              # never write into the source row
                fire[dst] = pixel - (rnd & 1)  # random 1-step decay
```

- `W*H`, `(H-1)*W` — two 16-bit multiplies **per call** (hoisted; negligible). The per-cell loop
  has **no** multiply/divide → disasm has **no** `__mulsi3`/`__udivmodsi4` (intentional).
- `xorshift16` — `x^=(uint16_t)(x<<7); x^=(uint16_t)(x>>9); x^=(uint16_t)(x<<8)` → native 16-bit
  `eor` + `asl`/`lsr` under one `rep`/`sep`.
- All widths `int16_t`/`uint16_t`/`uint8_t`; each xorshift term cast back to `uint16_t` so host
  (32-bit int) and target (16-bit int) agree bit-for-bit.

## Screen layout
Full screen, no border — the grid IS the 32×28 tilemap. Source row at the bottom (row 27).

```
 col → 0                              31
row 0  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   ← cool (heat 0..3, near-black/dark-red)
 ...   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
 ...   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓   ← mid (orange/yellow)
row 27 ████████████████████████████████   ← source row, heat 15 (white-hot)
```

## Display architecture
- **One Drawable** `FireLayer` (BG1 4bpp), modelled on rdiff's `RdiffLayer`.
- VRAM: `FIRE_CHR=0x0000` (16 solid-colour 4bpp tiles, 256 words), `FIRE_MAP=0x4000` (32×32 tilemap).
- Tile index == heat value directly (0..15) — no scaling.
- **Half-tilemap DMA** each frame (alternating): rows 0..13 then rows 14..27 = 14×32×2 = **896 B/frame**
  (≤ 1024 BitmapCanvas cap, ≤ 1536 budget). Full screen refreshes at 30 fps effective — fine for fire.
- CGRAM: 16 colours (palette 0, entries 0..15) pushed each emit = **32 B**.
- Total DMA/frame ≈ 896 + 32 = **928 B** ≤ 1536.
- `TitleLayer` on BG2 ("DOOM FIRE" / "HEAT FIELD"), held ~1 s then hidden (gate-neutral).

Palette ramp (CGRAM 0..15): `(0,0,0)` → dark reds → red/orange → yellow → `(31,31,31)` white.

## Files
| File | New/Mod | Purpose |
|---|---|---|
| `examples/65816/doom-fire.h` | new | portable host+target heat-field math: `fire_step`, `fire_rng`, `doomfire_gate_crc` |
| `examples/snes/doom-fire.c` | new | SNES ROM: `FireLayer` BG1 drawable + frame loop |
| `examples/snes/corpus/doom-fire_sim.c` | new | corpus slice (5-way differential) |
| `tools/doom-fire-sim.c` | new | host oracle (prints gate CRC) |
| `dev/doom-fire.sh` | new | gate script (host oracle + disasm + bsnes-jg + MAME) |
| `dev/doom-fire.lua` | new | MAME autoboot snapshot+assert |
| `Taskfile.yml` | mod | `doom-fire` + `doom-fire-play` tasks |
| `examples/snes/corpus/expected.tsv` | mod | corpus manifest row |
| `TODO.md`, `docs/investigations/plan-index.md`, `docs/investigations/2026-06-27-compiler-stress-test-demo-ideas.md` | mod | tracking |

## Reused infrastructure
| Asset | From | Used for |
|---|---|---|
| `RdiffLayer` solid-tile + half-DMA pattern | `examples/snes/rdiff.c` | `FireLayer` |
| xorshift16 | `invaders_logic.h` / `rdiff.h` | per-cell PRNG |
| `TitleLayer` | `snesgfx/title_layer.h` | title overlay |
| `Display`/`Drawable`/`UploadQueue` | `snesgfx/` | frame loop + DMA |
| gate-script skeleton | `dev/rdiff.sh` / `dev/rdiff.lua` | `dev/doom-fire.{sh,lua}` |

## Differential gate
- `corpus_result = doomfire_gate_crc()` — folds the full 16×16 gate grid into a rotate-XOR CRC after
  each of `FIRE_GATE_STEPS=30` steps (gate grid `16×16`, kept small so corpus-a16 doesn't time out).
- `EXPECT` = **`0x3C59`** (host oracle == bsnes-jg corpus_result, confirmed).
- **5-way bar** (host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == default/a16@bsnes-jg) —
  no far pointers, all data in bank-0 WRAM.
- Disasm probes (on `doom-fire_sim.o`, +mos-a16): `rep`/`sep` ≥ 1 (native-16), `eor` ≥ 1 (xorshift),
  `asl`+`lsr` ≥ 1 (shifts). **No** `__mulsi3`/`__udivmodsi4` expected in the hot loop.

## Publication
`/snes-rom-page --rom build/doom-fire.sfc --slug doom-fire --site ~/SRC/biohack.net
--title "Doom Fire" --preview build/doom-fire-mame.png
--selfcheck "0x<VMA> 2 0x<EXPECT> 500 doom-fire"`

## Verification steps
1. Host oracle compiles and prints a plausible CRC.
   ```
   $ cc -O2 -I examples/65816 tools/doom-fire-sim.c -o /tmp/df-host && /tmp/df-host
   doom-fire gate_crc = 0x3C59
   ```
   PASS — also ASCII-rendered the full 32×28 sim (120 steps): dense white-hot source
   row at the bottom, flames thinning upward — a textbook rising fire.

2. ROM builds clean; snes-checksum.py exits 0. (Covered by step 4 §2.)
   ```
   ==> built build/doom-fire.sfc (+mos-a16); corpus_result @ WRAM 0x302
   ```
   PASS — `python3 tools/snes-checksum.py build/doom-fire.sfc` exited 0.

3. Corpus slice host-compiles; ./a.out exits 0.
   ```
   $ cc -O2 -std=c99 -I examples examples/snes/corpus/doom-fire_sim.c -o /tmp/df-corpus
   $ /tmp/df-corpus ; echo $?
   0
   ```
   PASS.

4. `dev/run.sh doom-fire` — host oracle + disasm gate + bsnes-jg + MAME.
   ```
   ==> host oracle: Doom-fire gate hash = 0x3C59
   ==> disasm gate (xorshift16 PRNG + array sweep, native-16, multiply-free)
       PASS  eor=6  asl/lsr=8  rep/sep=21  (xorshift16 + array sweep, native-16)
   ==> bsnes-jg: render + framebuffer dump (build/doom-fire-jg.png) + assert
   SMOKE: PASS off=0x302 len=2 got=0x3C59 (ran 500 frames, bsnes-jg)
       SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content)
   RESULT: PASS — Doom-fire rendered on SNES; … corpus hash 0x3C59 host == +mos-a16
   ```
   PASS (bsnes-jg + disasm + host). MAME leg SKIPped — the SPC700 IPL is absent in this
   environment (env-wide, affects every demo's MAME leg, not a defect in this ROM). The
   bsnes-jg framebuffer (`build/doom-fire-jg.png`) shows the rising fire through the ramp.

5. `dev/run.sh corpus-a16` — full 5-way differential.
   ```
   MISSING SNES BIOS: /work/dev/roms/s_smp/spc700.rom
     MAME's snes driver needs the SPC700 IPL ROM (sha1 97e35255…).
   ```
   BLOCKED env-wide — the `corpus-a16` differential `check` requires the MAME legs
   (`a16_fuzz.py check` has `--no-bsnes` but no `--no-mame`), and the SPC700 IPL is
   absent here, so the whole suite aborts before testing any slice (same block the CORDIC
   and maze demos hit). The bsnes-jg leg of the differential is covered by step 4's
   host == +mos-a16 PASS. The slice + `expected.tsv 0x3C59` row are in place for when the
   IPL is supplied.

6. /snes-rom-page publishes; page shows the ROM running.
   ```
   $ curl -s -o /dev/null -w '%{http_code}' https://biohack.net/snes/doom-fire/   → 200
   <title>Doom Fire — bioHACK•NET</title>
   ```
   PASS — published to https://biohack.net/snes/doom-fire/ (biohack.net v1.0.110). The page
   embeds the same bsnes-jg WASM core whose headless gate produced `build/doom-fire-jg.png`
   (textbook fire + corpus 0x3C59); a "Verify fidelity" button reproduces the 0x3C59 assert
   live. NOTE: a local headless-browser *screenshot* of the page couldn't be captured (no
   Chrome installed; headless firefox non-functional here) — the built HTML/manifest wiring
   was verified directly instead (BJG_DEFAULT_ROM, canvas#screen, preview path, selfcheck
   off=0x302/want=0x3C59), and the `<style>`+boot-`<script>` are byte-identical to the
   proven rdiff page.

7. `task md -- docs/plans/2026-06-28-7-snes-doom-fire.md` renders cleanly. PASS (Astro/site
   build of the page itself also succeeded; doc is plain markdown).
</content>
</invoke>
