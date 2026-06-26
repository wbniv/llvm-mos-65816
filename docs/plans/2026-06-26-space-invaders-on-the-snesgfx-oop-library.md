# Plan — Space Invaders on the `snesgfx` OOP library

## Status — as-built 2026-06-27

**Done & verified (all GREEN):** `snesgfx` library (`display`/`upload`/`vram`/`drawable`/`scene`/
`sprite_set`/`controller`); the full game (`invaders.c`) — fleet of 3 alien types × 2-frame anim + march +
speed-up, player, shot, alien bombs, UFO, AABB collisions, scoring/lives, attract **and** interactive play
(START). Differential bar: host == default@MAME == a16@MAME == xy16@MAME == default/a16@bsnes-jg == **0x3DAC**,
`-verify-machineinstrs` clean, bsnes **3× byte-identical** (`dev/run.sh invaders`). Real **gfx4snes** art via
**Option B** (`art/invaders/draw.py` → committed `.pic`/`.pal` → `dev/build.sh` objcopy into bank-$00
`.rodata`). Corpus 5-way slice (`corpus/invaders_sim.c`, `0x3DAC`). Both-emulator screenshots clean.
**Bug fixed:** `SpriteSet` did `REG_TM |= TM_OBJ` on the **write-only** TM register → bsnes flap; now a
`Display` TM shadow. Commits `1d753fe`, `c76d735`, `b71f93d`, `e6d31e6`, `3e87d01`, `aca9594`.

**P7 page:** `/space-invaders` built, screenshot-verified, committed on `biohack.net` (`c20b62e`). **Deploy
to production (https://www.biohack.net/space-invaders/) PENDING explicit user OK** — `task publish
TAG=v1.0.75` (tag → GitHub Actions → Cloudflare Pages) was guardrail-blocked as an outward deploy.

**Remaining (polish, P4–P5):** on-screen HUD (score/lives via a `TextLayer` BG) and destructible shields
(`ShieldField`). Not required for a playable, verified game; deferred.

## Context

The user wants a real, on-screen **Space Invaders** for the SNES, written **using the `snesgfx`
OOP-in-C rendering library** — which so far exists only as a design
([`docs/plans/2026-06-26-snes-rendering-oop-library.md`](/home/will/SRC/llvm-mos-65816/docs/plans/2026-06-26-snes-rendering-oop-library.md)).
So this is two deliverables: **(1) build out the `snesgfx` library** (especially the sprite/OAM front-end,
the least-developed part — the handoff calls OAM "not yet built in this repo"), and **(2) the game on top**.
It is the natural "graphical payoff" customer for #321's `+mos-a16` work, and — because Space Invaders needs
**no far pointers** — it builds **both** default-8-bit *and* `+mos-a16` *and* `+mos-xy16`, so it earns the
**full 5-way differential bar** (richer than the a16-only Mandelbrot demo).

This plan also honors the session's OOP discipline (established while reviewing the library plan): **objects +
methods only, no bare functions; the application is itself an object; the per-object vtable is a coarse seam,
never a per-entity hot-loop cost.**

**Toolchain note:** the SNES code is compiled by *this repo's* `mos-clang` (llvm-mos). PVSnesLib's `gfx4snes`
is borrowed **only as a host-side asset converter** — we are not switching toolchains.

## Goal & scope

A playable, recognizable Space Invaders (player ship, 5×11 marching/animating/speeding alien fleet of 3
types, player shot + alien bombs, destructible shields, bonus UFO, score/lives HUD, attract + play), built on
`snesgfx`, and **verified on the repo's differential bar** (host == default@MAME == a16@MAME == a16@bsnes-jg,
+ corpus 5-way default==a16==xy16, + two-emulator screenshots, + `-verify-machineinstrs` clean), and finally
**published as a playable in-browser page at https://www.biohack.net/space-invaders/** (P7, `snes-rom-page`).

Phased so an MVP lands first and each phase is independently verifiable (build order de-risks fastest).

## Asset pipeline — **existing tools only** (no new converter)

Per the user: use an existing CLI/Makefile batch converter. The decisive choice:

- **`gfx4snes`** — PVSnesLib's graphics converter, in the foundry apt package **`pvsneslib-core`** (already
  in `apt.foundrylinux.org resolute main`). Converts PNG/BMP → SNES **4bpp tile data (`.pic`) + BGR555
  palette (`.pal`) + tilemap (`.map`)** — exactly what sprite/font/shield art needs. Batch, scriptable.
  - **Prereq (one reproducible step):** `sudo apt install pvsneslib-core`. It installs under
    `/usr/lib/pvsneslib` and exports `PVSNESLIB_HOME` via `/etc/profile.d/pvsneslib.sh`; the tools are **not**
    on `$PATH`, so invoke `gfx4snes` by absolute path (resolve the exact subdir with
    `dpkg -L pvsneslib-core | grep gfx4snes` at implementation; confirm flags with `gfx4snes -h`).
- **Embed via the linker as a real object — `llvm-objcopy` (Option B, chosen & measured).** The raw
  `gfx4snes` `.pic`/`.pal` become genuine relocatable objects the linker places; the data never passes through
  the compiler as an array. **Validated end-to-end** (`build/llvm-mos-install`): the output target is
  **`elf32-mos`** (`EM_MOS 0x1966`), and objcopy auto-emits `_binary_<name>_start/_end/_size` symbols. The one
  required detail — objcopy defaults the blob into **`.data`** (which on this platform has a RAM VMA + ROM
  init-image LMA, i.e. it would burn scarce WRAM) — is fixed by renaming it to **`.rodata`**:

  ```sh
  llvm-objcopy -I binary -O elf32-mos \
    --rename-section .data=.rodata.invaders_pic,alloc,load,readonly,data,contents \
    invaders.pic build/invaders.pic.o
  ```

  Measured result: the blob lands at **`$8077` in `.rodata` (bank-$00 ROM)**, symbols `_binary_invaders_pic_start`
  / `_binary_invaders_pic_end` / `_binary_invaders_pic_size` (the `…_size` is an ABS symbol whose *address* is
  the byte count), bytes present in the `.sfc`, links clean. (Run objcopy with the asset's **basename** as the
  input — `cd examples/snes` — so the symbol is `_binary_invaders_pic_start`, not a path-mangled name.)
  *Rejected alternatives:* module-level `asm(".incbin")` (works, but embeds the blob in the game's TU — less
  clean separation than a real linked object); drdevtools `bin2src` / PVSnesLib `constify` (make a compiled C
  array — the thing we're avoiding).
- **`dev/build.sh` sidecar convention (small, reusable change).** For `examples/snes/<name>.c`, build.sh
  objcopies any committed sidecar binaries `examples/snes/<name>.{pic,pal,map,chr,bin}` → `build/<name>.<ext>.o`
  (the recipe above, section `.rodata.<name>_<ext>`) and links them with `<name>.c`. This keeps the generic
  one-`.c`-per-ROM loop working *and* lets `invaders.c` reference the `_binary_*` symbols. `OBJCOPY` =
  `$MOS_TOOLCHAIN/bin/llvm-objcopy`.
- **Authoring:** sprite/font art is committed **PNG** source (classic squid/crab/octopus, ship, bullets,
  bombs, UFO, an 8×8 ASCII font, shield blocks). drdevtools' GUI **`spritex`** is the interactive editor if
  hand-pixeling is wanted — but it is **not** in the build path (it's interactive; the build uses `gfx4snes`).

**Pipeline (regeneration is a documented `dev/` step; the small `.pic`/`.pal` binaries are committed so a
routine `dev/build.sh` needs no pvsneslib install):** `art/*.png` → `gfx4snes` → committed
`examples/snes/invaders.pic`/`.pal` → `dev/build.sh` **objcopies** them to `.rodata` objects → linked with
`invaders.c`, which references them through a tiny **hand-written** `examples/snes/invaders_art.h` (just
`extern const uint8_t _binary_invaders_pic_start[];` + readable `#define`s, e.g.
`#define invaders_tiles _binary_invaders_pic_start`) → DMA'd to OBJ VRAM / CGRAM 128+. Only *regeneration*
needs `pvsneslib-core`; the committed binaries keep routine builds dependency-free and `git diff`-auditable.

## Architecture

### `snesgfx` components to build (header-only `static inline`; methods, not bare functions)

The library is header-only because `dev/build.sh` links every `examples/snes/**/*.c` as a standalone ROM
(precedent: `mode7.h`). Invaders drives these (co-implementing the library plan's P2–P3):

- **`snesgfx/sprite_set.h` — `SpriteSet` (the central new piece, OAM front-end).** A contiguous 544-byte RAM
  OAM shadow (`uint8_t lo[512]` 128×{Xlo,Y,tile,attr} + `uint8_t hi[32]` 2-bits/sprite). Methods:
  `sprite_set_init(s, size_pair, chr_base_word)`, `sprite_set_put(s,i,x,y,tile,attr,large)` (writes the 4 low
  bytes + the 2-bit high field: bit0=X bit8, bit1=size), `sprite_set_move`, `sprite_set_hide` (Y=0xE0),
  `sprite_set_palette(s,q,group,colors,n)`. `reserve()` sets `REG_OBSEL` + `TM_OBJ`; `emit()` enqueues one
  544-byte OAM DMA (`BBAD_OAMDATA`) per frame. Sprite tile VRAM sits at a fixed 8K-word page (OBSEL
  granularity). **Static OAM slot map** (disjoint compile-time ranges, no runtime contention): 0=player,
  1=shot, 2–5=bombs, 6=UFO, 8–62=fleet (slot=8+row*11+col), 63–127 free (explosions).
- **`snesgfx/bg_layer.h`** — two concrete `Drawable`s:
  - **`TextLayer`** (HUD: score/lives/title) — a 2bpp BG3 tiled layer + an ASCII font tileset;
    `bg_text_puts`/`bg_text_num` write into a per-row shadow with a dirty-row mask; `emit()` DMAs only dirty
    rows (64 B each). Avoids a 2 KB full-tilemap shadow.
  - **`ShieldField`** (destructible) — BG1 4bpp; a small RAM **chr shadow** (≈24 tiles × 32 B) + a dirty-tile
    mask (tilemap static, uploaded once; only chr changes). `shield_test(x,y)` (collision query),
    `shield_damage(x,y)` (erase a blast cluster across all 4 bitplanes, mark dirty); `emit()` re-DMAs only
    dirty tiles. **Phased last with a discrete-state fallback** (swap pre-authored "chipped" tiles) before
    true per-pixel erase.
- **`snesgfx/controller.h` — `Controller`** (edge detection): `controller_poll` (`prev=cur; cur=snes_read_pad1()`),
  `controller_held/pressed/released`. (The library plan's selector-table form stays valid for menus; the game
  uses the edge-detect form — both are methods.)
- **`snesgfx/display.h` + `upload.h` + `vram.h`** — as in the library plan, but `display_init` selects
  **`BGMODE_1`** (BG1 shields + BG3 HUD + OBJ) instead of Mode 7. Owns the boot bracket
  (`snes_ppu_reset_blank`, release force-blank **last** on first frame), the `UploadQueue`, the `VramAlloc`,
  and the `Scene` of drawables.

### Entity model — the one decision everything hangs on

**The per-object vtable seam lives only at the render-layer level; game entities are real objects dispatched
*statically*.** The `Scene` holds 3 genuinely-different `Drawable*` (SpriteSet, TextLayer, ShieldField) → **3
virtual `emit()` calls per frame**, the entire dispatch budget the library mandates. Game entities
(`Fleet`, `Player`, `Bullets`, `Ufo`) are concrete typed objects with receiver-first methods called
**directly** (inlinable, zero indirection) — the cheapest OOP form (oop-in-c §5 rung 1), reserving the
expensive vtable for where the call site truly doesn't know the type. A per-entity `Entity` vtable would cost
~8 ZP ops + `JMP(vector)` **per entity per frame** (~60×) purely to pick a statically-known method — wrong on
a 3.58 MHz CPU. (Optional: disassemble one vtable-entity build to put a measured number against this, per
"measure, don't assume" — then keep static dispatch.)

- **`Fleet`** = the alien grid as **one** object: `alive[5]` bitmaps + one origin `(ox,oy)` + fixed spacing +
  `dir`/`step_down`/`anim`/`move_period` (period shrinks with `alive_count` → the iconic speed-up). NOT 55
  objects. `fleet_update` (march/edge-reverse/step-down/animate), `fleet_draw(f, spriteset)` (the monomorphic
  55-iter hot loop → slots 8–62), `fleet_hittest`. `noinline` under a16 (register-heavy).
- **`Player`**, **`Bullets`** (one pool: index 0 = player shot, 1.. = alien bombs), **`Ufo`** — small typed
  objects; `*_update` + `*_draw(self, spriteset)` into their disjoint slot ranges.
- **Collisions**: integer AABB, fixed iteration order (deterministic): shot×fleet (clear bit, score,
  speed-up), shot×UFO, shot×shield, bomb×shield, bomb×player. `noinline` under a16.

### The `Game`/`App` object + frame loop

`Game` owns the `Display`, the one `SpriteSet`, `TextLayer`, `ShieldField`, the entity subsystems,
`Controller`, and score/lives/state. `main()` only constructs and calls methods (no bare calls):

```c
int main(void){ static Game g; game_init(&g); for(;;){ game_update(&g); display_frame(&g.screen); } }
```

`game_update` (active display): poll input, step sim, run collisions, write the RAM shadows. `display_frame`
(vblank): `scene_emit` (3 virtual calls) + `upq_flush` (DMAs: 544 B OAM always; dirty HUD rows; dirty shield
tiles — well within the ~38-scanline vblank). First frame releases force-blank last. `noinline` the
register-heavy kernels under a16; always `-mllvm -verify-machineinstrs`.

## Verification — the differential bar (gold standard)

Mirror the `mandel.h` + `tools/mandel-render` pattern exactly:

1. **`examples/snes/invaders_logic.h`** — a **portable, HAL-free** deterministic simulation (`<stdint.h>`
   only; explicit `int16_t`/`uint8_t` widths on every narrowing — `int` is 16-bit on target, 32-bit on host).
   Fleet march/speed-up, a **scripted attract-AI "player"** (driven by frame counter + a fixed-seed
   xorshift16, the `k_prng.c` routine), bullets, AABB collisions, scoring; an explicit **serializer** (never
   `memcpy` the struct — host/target padding differs) + CRC16 (the `mandel.h` routine). `inv_step(state)` +
   `inv_state_crc(state)`. This same logic runs both on the SNES (rendered) and on the host.
2. **`tools/invaders-sim.c`** — host oracle: `#include "invaders_logic.h"`, run `INV_FRAMES`, print the
   **golden CRC** (the single source of truth, like `mandel-render`).
3. **`examples/snes/invaders.c`** — the game includes the same logic; the **attract** path runs the identical
   N-frame deterministic sequence, renders it via `snesgfx`, latches `corpus_result = inv_state_crc(&s)` at
   frame N, then **freezes** (so both emulators screenshot the identical frame — defuses cross-core
   frame-count divergence).
4. **`dev/invaders.sh`** (auto-registers as `dev/run.sh invaders`; models `dev/mandel-shot.sh` + `dev/a16add.sh`):
   build host oracle → build default + a16 ROMs (`snes-checksum`) → assert `corpus_result == golden` on
   **default@MAME + a16@MAME** (`dev/_emu.sh run_assert`) and **a16@bsnes-jg** (`jgxcheck`) → capture
   **screenshots from both** (Xvfb MAME `video:snapshot` via `dev/invaders.lua`; bsnes-jg framebuffer PNG) →
   3× bsnes SHA check (proves `snes_ppu_reset_blank` pinned the PPU). Add the `invaders` stanza to
   `dev/run.sh --help`.
5. **Corpus 5-way slice:** add `examples/snes/corpus/invaders_sim.c` (HAL-free, includes `invaders_logic.h`,
   writes `corpus_result`) + an `expected.tsv` row → `dev/run.sh corpus-a16` gives **default==a16==xy16 on
   MAME+bsnes** + dual `-verify-machineinstrs` for free. Shared header ⇒ the three sites can't drift.

**Determinism:** the gate is a **no-input self-playing attract** (scripted input would diverge MAME vs
bsnes-jg, which can't inject). Reading a zero joypad each frame is identical on both cores; the proof CRC is
computed only from attract state. The shipped ROM is still **playable** — START leaves attract into
`MODE_PLAY` and reads the pad; the gate never presses START, so it stays deterministic.

## Files

New:
- `examples/snes/snesgfx/sprite_set.h`, `bg_layer.h`, `controller.h`, `display.h`, `upload.h`, `vram.h`,
  `drawable.h`, `scene.h` (the library; `display/upload/vram/drawable/scene` shared with the library plan)
- `examples/snes/invaders.c` (the game: `Game`/entity objects + `main`; single linked program)
- `examples/snes/invaders_logic.h` (shared HAL-free sim + serializer + CRC)
- `examples/snes/invaders_art.h` (tiny **hand-written** `extern _binary_*` decls + readable `#define`s — NOT a
  generated array) + committed `examples/snes/invaders.pic`/`.pal` (raw `gfx4snes` output, objcopied to
  bank-$00 `.rodata` objects by `dev/build.sh` and linked in)
- `art/invaders/*.png` (committed source art) + a regen step (`dev/gen-invaders-art.sh` invoking `gfx4snes`)
- `tools/invaders-sim.c` (host oracle)
- `dev/invaders.sh`, `dev/invaders.lua` (gate + MAME screenshot)
- `examples/snes/corpus/invaders_sim.c` + row in `examples/snes/corpus/expected.tsv`
- `docs/plans/2026-06-27-snes-space-invaders-on-snesgfx.md` (project-convention copy of this plan, on impl)

Modify: `dev/run.sh` (`--help` stanza only — dispatch is generic); `dev/build.sh` (the sidecar-objcopy
convention above, so asset-bearing examples link their `.pic`/`.pal` objects).

Read alongside: `platforms/snes/snes_ppu.h`/`snes_dma.h`/`snes_joypad.h`, `dev/_emu.sh`, `dev/smoke.lua`,
`dev/jgxcheck.cpp`, `dev/mandel-shot.{sh,lua}`, `examples/65816/mandel.h`, `examples/65816/k_prng.c`.

## Phasing (each phase: build default+a16, `-verify-machineinstrs` clean, state-CRC on both emulators)

- **P0** — Library core for Invaders (`display/upload/vram` in Mode 1 + `SpriteSet`); smoke: one sprite on
  screen via the OAM shadow + DMA; dump & verify the 544 OAM bytes.
- **P1** — `Player` + `Controller`: ship moves, fires a shot that travels up.
- **P2** — `Fleet`: the marching/animating/speeding 5×11 grid (edge reverse + step-down). The game's core.
- **P3** — `Bullets` + collisions: shot×fleet (clear bit/score/speed-up), bombs×player. **← MVP: a
  recognizable, verifiable game.** Wire `invaders_logic.h` + the host oracle + `dev/invaders.sh` + the corpus
  slice here (the differential bar goes green).
- **P4** — `TextLayer` HUD (score/hi/lives/title) + the `gfx4snes` font asset path.
- **P5** — `ShieldField` (discrete-state damage first, then per-pixel erase; verify chr bytes vs a host model).
- **P6** — `Ufo`, explosions, attract↔play states, level progression.
- **P7 — publish a playable in-browser page** at **https://www.biohack.net/space-invaders/** via the
  `snes-rom-page` skill (shared bsnes-jg WASM player + a `/space-invaders` Astro page with controls). Ship
  the `+mos-a16` ROM (`build/invaders-a16.sfc`). **Hard prerequisite:** the ROM must pass the bsnes 3×-capture
  determinism check (the page runs bsnes-jg WASM, so any power-on flap shows there) — already enforced by
  `dev/invaders.sh`. The ROM should boot into the deterministic attract demo and hand control to the player on
  START (so visitors can watch *and* play).

## Verification steps (run during implementation; paste raw output + PASS/FAIL — **PENDING**)

1. `cc -O2 -I examples/snes tools/invaders-sim.c -o build/invaders-sim && build/invaders-sim` prints a stable
   CRC twice (determinism). → PENDING
2. `dev/run.sh corpus-a16` shows `invaders_sim PASS` (host==default==a16==xy16 on MAME+bsnes, verify clean). → PENDING
3. `dev/run.sh invaders`: `corpus_result == golden` on default@MAME, a16@MAME, a16@bsnes-jg; both screenshots
   written (`build/invaders-{mame,jg}.png`); 3× bsnes SHA identical. → PENDING
4. `-mllvm -verify-machineinstrs` clean for `invaders.c` under `+mos-a16` and `+mos-xy16`. → PENDING
5. No-bare-functions audit: `grep -E 'REG_|snes_|upq_|vram_' examples/snes/invaders.c` appears only inside
   methods, never in `main`. → PENDING
6. Asset reproducibility: re-run the `gfx4snes` step; `git diff examples/snes/invaders.pic invaders.pal` is
   empty; the objcopy'd `.rodata` blob lands in bank-$00 ROM (check the `.map`, not RAM). → PENDING
7. Eyeball both screenshots: recognizable Space Invaders (fleet, ship, shields, HUD). → PENDING

## Risks

- **R1 `+mos-a16` register pressure** in `fleet_draw`/`collisions`/`shield_damage` → allocator crash or
  undefined-physreg COPY (caught only by `-verify-machineinstrs`). Mitigation: `noinline` those kernels; the
  default-8-bit build is the safety net (no a16 allocator risk; no far pointers).
- **R2 Determinism traps:** never CRC the raw struct (host≠target padding) — use the serializer; any un-cast
  `int` intermediate diverges; an a16/default/xy16 state-CRC mismatch is a **real codegen defect**, triage it.
- **R3 Shield pixel-destruction** (4bpp bitplane nibble erase + pixel→tile mapping) is the most bug-prone
  code → phase last, discrete-state fallback first, byte-verify vs a host model.
- **R4 OAM is greenfield** (no helper exists) — write+verify the 544 B shadow/DMA from scratch (P0).
- **R5 DMA silent no-ops** (`DAS=0`→64 KiB; `MDMAEN` is the trigger; wrong `BBAD`) — get one DMA provably
  correct (dump VRAM) before generalizing.
- **R6 Screenshot capture** — MAME needs Xvfb (offscreen → black PNG); freeze-at-N defuses cross-core frame
  races; `snes_ppu_reset_blank` is mandatory or bsnes screenshots flap.
- **R7 Tooling prereq** — `gfx4snes` (foundry `pvsneslib-core`, repo already configured) is needed **only to
  regenerate** the committed `.pic`/`.pal` from PNG; routine `dev/build.sh` just **objcopies+links** the committed
  binaries (no pvsneslib dependency). gfx4snes lives under `$PVSNESLIB_HOME` (not on `$PATH`, invoke by
  absolute path); used purely as a host asset converter, never as the SNES toolchain.
