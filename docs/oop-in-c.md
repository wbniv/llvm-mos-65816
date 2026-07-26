# OOP-in-C on the 65816 — snesgfx Design Notes

**Verified 2026-06-30** via `examples/snes/mandel-oop.c` (the formal verification client);
**counts and measurements refreshed 2026-07-26** (rebased toolchain; hardened measurement in
`dev/mandel-oop.sh`). Confirmed across all **113** SNES demos that include `snesgfx/`
(113 of 114 `examples/snes/*.c` — the sole exception is `hello.c`) and Space Invaders.

---

## §1 — The library

`snesgfx` is a **13-header** header-only OOP-in-C rendering library for the SNES 65816.
It encapsulates two hardware correctness invariants that are easy to violate:

1. **Boot bracket** — `snes_ppu_reset_blank()` must run exactly once, and force-blank
   must be released LAST (after the first complete upload). Owned by `display_init()`.
2. **Access window** — VRAM/CGRAM/OAM writes are only valid in force-blank or v-blank.
   Owned by `UploadQueue` / `upq_flush()`, called only from `display_frame()`.

Clients call `display_init → display_add → display_frame` with zero bare `REG_*`/`snes_*`
pokes in `main()`. Every public call takes the object as receiver (`Type_verb(Type *self,…)`).

---

## §2 — Dispatch model: two forms

| Form | Use | Cost |
|---|---|---|
| Static dispatch (direct call) | Everything except `Scene`'s drawable loop — always known type | 0 (inlined by compiler) |
| Per-object vtable (`DrawableVT`) | `scene_emit` — genuinely heterogeneous: 1 call/drawable/frame | **measured**: see §8 — ~1.35× on a dispatch-bound loop; sub-percent at 1 call/frame |

(An earlier revision listed a third "selector table" form for `controller_poll` — that was
aspirational: `controller.h` is five static-inline accessors over `{cur, prev}`, pure static
dispatch, cost 0. No selector table exists anywhere in snesgfx.)

The key discipline: **one virtual call per drawable per frame, never per tile/pixel/entity.**
The expensive loops inside `emit()` are monomorphic and inlinable. §8 quantifies exactly what
breaking this rule costs.

---

## §3 — Drawable interface

```c
typedef struct {
  void (*reserve)(Drawable *self, VramAlloc *va);   // once at display_add(): force-blank setup
  void (*emit)   (Drawable *self, UploadQueue *q);  // once per frame: enqueue VRAM/CGRAM jobs
} DrawableVT;

typedef struct Drawable {
  const DrawableVT *vt;   // vtable pointer FIRST (upcast: (Drawable*)&concrete is free)
  uint8_t tm_bits;        // main-screen enable bits (Display manages REG_TM via shadow)
} Drawable;
```

`reserve()` runs in force-blank (direct PPU register writes OK — established pattern).
`emit()` runs before `snes_wait_vblank()` (WRAM-only), enqueues jobs for `upq_flush()` in v-blank.

---

## §4 — Measured dispatch cost (mandel-oop, re-measured 2026-07-26)

| Metric | Result |
|---|---|
| Indirect JMP instructions in `.text` | 0 |
| **Indirect dispatch call sites** (jmp-ind + jsr-ind + `jsr __call_indir`) | **1** — the `scene_emit` vtable call |
| `mandel-oop` `.text` | 3,660 bytes |
| ROM size | 32,768 bytes (LoROM) |
| `corpus_result` | **0x204F** — identical on host and `+mos-a16`@bsnes-jg; MAME leg SKIP (no SPC700 IPL in this environment — `dev/_emu.sh` gate) |

**Correction to the 2026-06-30 record:** the original "0 indirect JMPs / LTO devirtualized all
vtable calls" claim was an artifact of the measurement — the old gate counted only the `jmp (`
disassembly form (and `|| true`'d over a possibly-missing ELF, reporting 0 either way).
llvm-mos routes C function-pointer calls through the `__call_indir` helper, which that pattern
misses. Re-measured with the hardened `dev/mandel-oop.sh` (ELF-existence assert + full pattern):
**one indirect call survives LTO** — the single `scene_emit → vt->emit` dispatch. LTO does NOT
devirtualize even this provably-single-target chain. The design consequence is unchanged (one
coarse virtual call per drawable per frame is noise), but the mechanism claim was wrong.

---

## §5 — Size delta (mandel-oop.c vs mandel-display.c)

The 2026-06-30 measurement (`+338 bytes / +10%` OOP overhead: `mandel-oop` 3,656 B vs
`mandel-display` 3,318 B `.text`) captured the two programs when they were feature-equivalent.
**They have since diverged**: `mandel-display.c` grew a coarse-preview progressive-refinement
pass and a title card, and now measures 8,290 B `.text` vs `mandel-oop`'s 3,660 B — the
comparison is no longer apples-to-apples and the historical +338 B figure should not be quoted
as current. The honest current statements are:

- The OOP machinery itself (Display, UploadQueue, Scene, VramAlloc, vtable `emit()` path)
  costs a few hundred bytes over a minimal procedural equivalent (the 2026-06-30 measurement,
  preserved here as history).
- Across the 113 demos that share these headers, the marginal cost of adding a new Drawable is
  just its `.text` + vtable (typically 100–400 bytes of emit logic).

---

## §6 — Mode 7 as a Drawable (`MandelLayer`)

Mode 7 is the rendering mode NOT covered by the other concrete drawables. `mandel-oop.c`
wraps it as `MandelLayer`:

- **`reserve()`** — direct Mode 7 register writes in force-blank (sets `BGMODE_7`, `M7SEL`,
  tilemap, matrix, centre, scroll; computes the 64×56 grid via far stores to `$7E2000`;
  uploads to Mode 7 VRAM via DMA). Does NOT touch `REG_TM` — `base.tm_bits = TM_BG1` lets
  Display manage the TM shadow.
- **`emit()`** — colour cycle via `upq_push_cgram`; spin+zoom animation via `upq_push_scroll`
  (reused for the write-twice `M7A/M7B/M7C/M7D` registers, which have the same protocol as
  scroll latches). 5 queue jobs/frame (well within `UPQ_MAX_JOBS=16`).

This confirms the `upq_push_scroll` write-twice mechanism generalises beyond scroll registers
to any write-twice PPU port including the Mode 7 matrix.

---

## §7 — The no-bare-functions rule (confirmed)

`main()` in `mandel-oop.c` contains exactly three calls:
```c
display_init(&screen);
display_add(&screen, (Drawable *)&layer);
display_frame(&screen);   // in loop
```

Zero `REG_*` pokes, zero `snes_*` calls. All PPU access is encapsulated in `reserve()` /
`emit()` / `upq_flush()`. The pattern scales: all 113 demos that use `snesgfx` follow the same
structure — `main()` is pure orchestration with no hardware pokes.

---

## §8 — Static vs. all-virtual dispatch (measured 2026-07-26)

**The experiment:** what does it cost to make EVERY snesgfx member function virtual — the
design §2 forbids? All ~40 receiver-typed member functions across 11 headers were converted to
a three-mode switch (`SNESGFX_DISPATCH`, experiment branch only — see
[the investigation](investigations/2026-07-26-snesgfx-static-vs-virtual-dispatch.md) and its
re-applyable [patch](investigations/2026-07-26-snesgfx-all-virtual.patch)):

- **mode 0** — static inline (production; verified byte-identical `.text` to pre-experiment main)
- **mode 1** — out-of-line direct calls (`noinline` impls, direct call sites): isolates the
  **loss-of-inlining** cost — an address-taken function cannot inline
- **mode 2** — per-type vtables, every member call via `self->vt->verb(self, …)`: adds the
  **indirect-dispatch** cost on top

Scope exclusions: constructors (`*_init` — they install the vtable), `HScrollN`-receiver
functions (its `tab[]` IS the DMA-visible HDMA table; a vt member would corrupt the layout),
free functions (`splash_show`, `m7splash*`, `splash16` — no receiver), and `DrawableVT`
(already virtual). Mode 2 adds a 2-byte vt pointer per object (WRAM).

**Correctness gate:** `mandel-oop` `corpus_result == 0x204F` and the bench oracle CRC
`0x26EC` in ALL modes (bsnes-jg; `-verify-machineinstrs` clean).

**Vehicle A — mandel-oop.c** (`+mos-a16 -Os`):

| Mode | `.text` | Indirect call sites |
|---|---|---|
| 0 static inline | 3,660 B | 1 |
| 1 out-of-line direct | **3,537 B** (−3.4%) | 2 |
| 2 all-virtual | 5,470 B (**+49%**) | 15 |

**Vehicle B — `snesgfx_bench.c` throughput** (canvas star: `canvas_clear` + 12 `canvas_line`,
whose Bresenham loop pays one `canvas_plot` dispatch **per pixel** in mode 2 — the exact
anti-pattern §2 forbids; 2,400 deterministic bsnes-jg frames, `dev/measure-snesgfx-dispatch.sh`):

| Mode | `.text` | Ind. calls | Redraws completed | Relative |
|---|---|---|---|---|
| 0 static inline | 1,918 B | 0 | 175 | 1.00× |
| 1 out-of-line direct | 1,934 B | 0 | **201** | **0.87× cost — 15% FASTER** |
| 2 all-virtual | 2,199 B (+15%) | 5 | 149 | 1.35× vs mode 1, 1.17× vs mode 0 |

**Vehicle C — `invaders.c`**, the real multi-drawable game (SpriteSet + TitleLayer + Controller +
custom drawables; 15 `sprite_set_put`/`hide` sites in nested per-alien loops). Gate = the
deterministic attract-CRC (`0x9D57`, host oracle `tools/invaders-sim.c`) at a fixed frame — a
PASS also proves that mode's per-frame cost still fits the v-blank frame budget:

| Mode | `.text` | Ind. calls | Attract gate |
|---|---|---|---|
| 0 static inline | 12,972 B | 1 | PASS |
| 1 out-of-line direct | **11,571 B** (**−10.8%**) | 2 | PASS |
| 2 all-virtual | 15,647 B (**+20.6%**) | **57** | PASS |

**Findings:**

1. **Naive inlining is not free on the 65816.** Mode 1 *beats* mode 0 by 15% on the
   dispatch-bound loop: inlining `canvas_plot` into the Bresenham loop bloats the caller's
   a16/ZP live set (the same register-budget effect that motivated `canvas_line`'s
   pre-existing `noinline`). And on the real game it's also **10.8% smaller** — with many
   call sites, one out-of-line body beats N inlined copies at `-Os`. "Static inline
   everywhere" is a size default, not a speed guarantee — measure, don't assume
   (governing lesson #1).
2. **Virtual dispatch proper costs ~1.35×** on a per-pixel-dispatch loop (mode 1 → mode 2,
   the clean indirection-only comparison), plus **+15–49% `.text`** (vtables, forwarder
   plumbing, un-folded argument setup; invaders +20.6% with 57 live indirect sites). The
   per-call overhead is the `__call_indir` route: ZP vt-pointer loads + slot load + indirect
   JSR. Notably, even all-virtual invaders still makes its frame budget (gate PASS) — the
   cost hides inside the v-blank wait until a loop is dispatch-bound.
3. **The §2 discipline is validated quantitatively**: at one virtual call per drawable per
   frame the cost is unmeasurable (mandel-oop CRC/frames identical across modes); at one
   virtual call per *pixel* it costs a third of the machine. Virtualize interfaces, not
   rasterizers.
4. LTO devirtualizes **nothing** here (15 indirect sites survive in mode-2 mandel-oop, all
   provably single-target) — on llvm-mos, "the compiler will devirtualize it" is not an
   argument for making members virtual.
5. The earlier "~8 cycles (JSR + ZP loads)" §2 estimate was unsourced; the measured ratios
   above replace it.
