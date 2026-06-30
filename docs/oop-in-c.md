# OOP-in-C on the 65816 — snesgfx Design Notes

**Verified 2026-06-30** via `examples/snes/mandel-oop.c` (the formal verification client)
and confirmed across all 29 SNES demos and Space Invaders.

---

## §1 — The library

`snesgfx` is a 12-header header-only OOP-in-C rendering library for the SNES 65816.
It encapsulates two hardware correctness invariants that are easy to violate:

1. **Boot bracket** — `snes_ppu_reset_blank()` must run exactly once, and force-blank
   must be released LAST (after the first complete upload). Owned by `display_init()`.
2. **Access window** — VRAM/CGRAM/OAM writes are only valid in force-blank or v-blank.
   Owned by `UploadQueue` / `upq_flush()`, called only from `display_frame()`.

Clients call `display_init → display_add → display_frame` with zero bare `REG_*`/`snes_*`
pokes in `main()`. Every public call takes the object as receiver (`Type_verb(Type *self,…)`).

---

## §2 — Dispatch model: three forms

| Form | Use | Cost |
|---|---|---|
| Static dispatch (direct call) | Inner loops, hot paths — always known type | 0 (inlined by compiler) |
| Per-object vtable (`DrawableVT`) | `scene_emit` — genuinely heterogeneous: 1 call/drawable/frame | ~8 cycles (JSR + ZP loads); LTO may devirtualize |
| Selector table | `controller_poll` (joypad event dispatch) — thin per-event dispatch | ~10 cycles |

The key discipline: **one virtual call per drawable per frame, never per tile/pixel/entity.**
The expensive loops inside `emit()` are monomorphic and inlinable.

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

## §4 — Measured dispatch cost (mandel-oop vs mandel-display, 2026-06-30)

| Metric | Result |
|---|---|
| Runtime indirect JMPs in `.text` | **0** (LTO devirtualized all vtable calls to direct calls) |
| OOP `.text` overhead | **+338 bytes** (+10% over procedural mandel-display.c) |
| ROM size | Both 32,768 bytes (same LoROM footprint) |
| `corpus_result` | **0x204F** — identical on host, +mos-a16@bsnes-jg |

LTO with `-Os` devirtualizes the single-drawable `scene_emit → _mandel_emit` chain entirely
(provably one concrete type), eliminating the vtable call overhead at runtime. With multiple
concrete drawable types in the same `Scene` (e.g. Space Invaders: SpriteSet + TitleLayer),
LTO cannot devirtualize and the `JSR (abs,X)` or `__call_indir` form appears — but only
once per drawable per frame.

---

## §5 — Size delta (mandel-oop.c vs mandel-display.c)

```
mandel-oop  .text:     3656 bytes   (OOP: MandelLayer + Display machinery + upload queue)
mandel-display .text:  3318 bytes   (procedural: manual force-blank + vblank + DMA)
───────────────────────────────────────────────────────────────────────────────────────
OOP overhead:           +338 bytes  (+10%)
```

The overhead comes from the snesgfx boilerplate (Display, UploadQueue, Scene, VramAlloc) and
the vtable-based `emit()` path replacing the procedural `wait_vblank_fresh() + dma_chr_to()`
loop. Across the 29 demos that share these headers (already in each ROM), the marginal cost of
adding a new Drawable is just its `.text` + vtable (typically 100–400 bytes of emit logic).

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
`emit()` / `upq_flush()`. The pattern scales: all 29 demos that use `snesgfx` follow the same
structure — `main()` is pure orchestration with no hardware pokes.
