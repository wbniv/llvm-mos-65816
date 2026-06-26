# Plan — re-imagine SNES rendering as an OOP-in-C library (`snesgfx`)

**Date:** 2026-06-26 · **Issue:** #321 (M2) · **Status:** DRAFT (contract for implementation)

**What:** Take the low-level SNES rendering mechanics we have *proven* on the differential bar — the
force-blank/v-blank access window, DMA uploads, the VRAM word/char/tilemap layout, the Mode 7 path — and
**re-imagine them as a small, header-only object-oriented C library**. The library is the *natural*
structure for this code: the rendering handoff already says so, and the
[OOP-in-C HOWTO](../investigations/object-oriented-c-and-assembly.md) (shipped as `oop-in-c.md`) is the
design grammar. This plan is also a **living test of that HOWTO**: the library is the first real,
verified consumer of its patterns, and its *measured* dispatch cost gets fed back into the doc (closing the
"improve oop-in-c.md" loop with numbers, not assertions — the repo bar is *measure, don't assume*).

**Read alongside:**
- [docs/handoffs/2026-06-24-snes-graphics-rendering.md](../handoffs/2026-06-24-snes-graphics-rendering.md)
  — the low-level mechanics + the "Recommended library shape" we are realizing here.
- [docs/investigations/object-oriented-c-and-assembly.md](../investigations/object-oriented-c-and-assembly.md)
  — the OOP-in-C grammar + the *measured* 65816 virtual-call lowering (§4) this plan budgets against.
- [examples/snes/mandel-display.c](../../examples/snes/mandel-display.c) + [examples/snes/mode7.h](../../examples/snes/mode7.h)
  — the verified procedural code we are refactoring *behind* the OOP seam (CRC `0x204F`, `mandel-shot` gate).
- [platforms/snes/snes.h](../../platforms/snes/snes.h) (+ `snes_ppu.h`/`snes_dma.h`/`snes_joypad.h`) — the
  thin register HAL the library sits *on top of* (we do not fold policy into it).

---

## 1. Goal & non-goals

**Goal.** A header-only `snesgfx` library that expresses SNES rendering as objects, plus a worked,
differentially-verified client (`examples/snes/mandel-oop.c`) that reproduces `mandel-display.c`'s output
(CRC `0x204F`) **through the library** — proving the abstraction is *zero-regression at the differential bar*
— and a measurement that quantifies the OOP dispatch cost and writes the numbers back into the HOWTO.

**The three OOP forms, deliberately, so the library demonstrates each (per oop-in-c.md §5):**
1. **Static dispatch (default).** A single-type scene calls concrete methods *directly* — inlinable, zero
   indirection. This is the common case and must stay free.
2. **Per-object vtable (the justified seam).** A *heterogeneous* `Scene` of `Drawable *` of different kinds
   (a Mode 7 layer **and** a sprite set **and** a tiled BG) — the one place a vtable earns its ~8-ZP-op +
   indirect-jump cost (oop-in-c.md §4), because the call site genuinely doesn't know the concrete type.
3. **Selector table (the cheap dynamic form).** Input/command dispatch (joypad button → action) via a
   function-pointer table — oop-in-c.md §3(a)'s `JSR (abs,X)` idiom. **Whether llvm-mos actually emits
   `JSR (abs,X)` from a C function-pointer-array index is an open `measure` item** (the HOWTO asserts it is
   cheap but §4 only measured per-object vtables — this library closes that gap).

**Non-goals.**
- **Do not touch `mandel-display.c`** — it is the `mandel-shot` publish/release gate. `mandel-oop.c` is a
  *parallel* client so the gate stays on the known-good file and we get a clean before/after.
- Not a general engine: no scrolling/collision/sound. BG/sprite front-ends are scoped to what we can verify.
- No dynamic allocation (no `malloc` on this target): objects are caller-owned `static`/stack storage;
  containers are fixed-capacity arrays.

---

## 2. Why header-only (a hard constraint, not a preference)

`dev/build.sh` compiles **every** `examples/snes/**/*.c` (globstar on) into a standalone `.sfc` and links it
— a library `.c` with no `main`/reset vector would fail the build. So `snesgfx` is **header-only**
(`static inline` functions, `static const` vtables), exactly like the existing `mode7.h` and the
`platforms/snes/*.h` HAL. This is also the *right* shape for the 65816: everything inlines, vtables fold to
ROM `.rodata`, and there is no cross-TU link complexity. Demos are single-TU; a future multi-TU game would
split into `.c`+`.h` compiled outside the examples auto-build (noted, not built here).

**Layout** (grouped subdir; headers are not globbed as programs):

```
examples/snes/snesgfx/
  upload.h     UploadQueue  — the v-blank/force-blank-gated DMA upload queue (THE correctness core)
  vram.h       VramAlloc    — bump allocator for char ($1000-word) + tilemap ($400-word) regions
  drawable.h   Drawable     — the interface (vtable) + scene-facing dispatchers
  scene.h      Scene        — fixed-capacity heterogeneous container of Drawable*
  mode7_layer.h Mode7Layer  — concrete drawable: linear-8bpp affine layer (wraps mode7.h)
  sprite_set.h SpriteSet    — concrete drawable: OAM front-end (128 sprites, double-buffered)
  bg_layer.h   BgLayer      — concrete drawable: tiled 2/4bpp BG (static image via DMA)
  input.h      selector-table joypad→action dispatch (the cheap dynamic form)
examples/snes/mandel-oop.c  the verified client (mos-a16-only marker)
```

Promotion path (out of scope here): once green on the bar, the stable modules move to `platforms/snes/gfx/`.

---

## 3. The design (interface + implementation idioms)

The architecture realizes the handoff's "Recommended library shape" §1–2, mapped onto oop-in-c.md's pillars.
Encapsulation = opaque-ish handles for the correctness-critical objects (queue, allocator); inheritance =
base-struct-first concrete drawables; polymorphism = the `Drawable` vtable; construction = `*_init`.

### 3a. `upload.h` — `UploadQueue` (encapsulation; the access-window rule in ONE place)

The single rule "VRAM/CGRAM/OAM are writable only during force-blank or v-blank" (handoff §1/§2) lives here
and nowhere else. Clients *enqueue* typed jobs whenever (e.g. while computing during active display);
`upq_flush()` runs them all via DMA and **is the only code that touches the data ports**, after ensuring the
window is open.

```c
typedef enum { UPQ_VRAM, UPQ_CGRAM, UPQ_OAM } UpqKind;   /* B-bus dest implied by kind */
typedef struct {
  UpqKind  kind;
  uint16_t dest;        /* VRAM word addr / CGRAM index / OAM addr */
  uint16_t src;         /* A-bus source address (bank in src_bank) */
  uint8_t  src_bank;
  uint16_t nbytes;      /* 0 is rejected (DAS=0 means 65536 — handoff §2 trap) */
  uint8_t  dmap;        /* DMAP_* (direction/step/unit); kind picks a sane default */
  uint8_t  vmain_high;  /* VRAM only: VMAIN_INC_HIGH_1 vs _LOW_1 */
} UpqJob;

typedef struct { UpqJob job[UPQ_MAX_JOBS]; uint8_t n; uint8_t chan; } UploadQueue;  /* fixed ring */

static inline void upq_init(UploadQueue *q, uint8_t dma_chan);
static inline void upq_vram_chr(UploadQueue *q, uint16_t dword, const void *src, uint8_t bank, uint16_t nb);
static inline void upq_vram_map(UploadQueue *q, uint16_t dword, const void *src, uint8_t bank, uint16_t nb);
static inline void upq_cgram(UploadQueue *q, uint8_t cgidx, const void *src, uint16_t nb);
static inline void upq_oam(UploadQueue *q, const void *src544, uint16_t nb);
static inline void upq_flush(UploadQueue *q);   /* MUST run in force-blank or v-blank; asserts/waits */
```

Implementation notes: each `upq_*` records a `UpqJob` with the correct `BBAD`/`DMAP`/`VMAIN` for its kind
(reusing the named constants in `snes_dma.h`: `BBAD_VMDATA`/`DMAP_UNIT_2`, `BBAD_CGDATA`/`DMAP_UNIT_1`,
`BBAD_OAMDATA`). `upq_flush()` iterates `job[0..n)`, sets `VMADD`/`CGADD`/`OAMADD` then the channel regs,
triggers `MDMAEN`, then `q->n = 0`. **Rejects `nbytes == 0`** (the DAS=0→64 KiB trap). The queue does **not**
itself wait for v-blank by default (the demo flushes inside `wait_vblank_fresh()`); a `upq_flush_in_vblank()`
convenience wraps the wait for callers that want the rule fully owned by the queue.

### 3b. `vram.h` — `VramAlloc` (encapsulation; no two drawables clobber each other)

```c
typedef struct { uint16_t chr_next; uint16_t map_next; } VramAlloc;
static inline void     vram_init(VramAlloc *v, uint16_t chr0_word, uint16_t map0_word);
static inline uint16_t vram_chr(VramAlloc *v, uint16_t nwords);   /* returns char base (word) */
static inline uint16_t vram_map(VramAlloc *v, uint16_t nwords);   /* returns tilemap base (word) */
```

A bump allocator. Drawables call it in `reserve()` and keep the returned bases. (Mode 7 ignores it — its
VRAM is fixed/interleaved — but BG/sprite layers use it so a multi-layer scene is collision-free.)

### 3c. `drawable.h` — the interface (polymorphism; the justified vtable)

```c
typedef struct Drawable Drawable;
typedef struct {
  void (*reserve)(Drawable *self, VramAlloc *va);  /* claim VRAM regions (once)            */
  void (*emit)   (Drawable *self, UploadQueue *q); /* enqueue this frame's uploads          */
  void (*dtor)   (Drawable *self);                 /* optional; 0 if none                   */
} DrawableVT;
struct Drawable { const DrawableVT *vt; };          /* base object: vtable pointer FIRST     */

static inline void drawable_reserve(Drawable *d, VramAlloc *va){ d->vt->reserve(d, va); }
static inline void drawable_emit   (Drawable *d, UploadQueue *q){ d->vt->emit(d, q); }
```

**Dispatch-budget rule (the load-bearing design decision).** A virtual call on the 65816 is ~8 ZP
loads/stores + `JMP (vector)` and is **not inlinable** (oop-in-c.md §4). So the vtable seam is
**coarse-grained**: `emit()` is called **once per drawable per frame** — never inside the per-tile/per-pixel
inner loop. The expensive byte/DMA loop *inside* `emit()` is monomorphic (direct calls / inlined). One
virtual call decides "which kind of thing uploads itself"; the hot loop after that is type-known and free.
This is what makes per-object polymorphism affordable on a 3.58 MHz CPU.

### 3d. `scene.h` — the heterogeneous container (the canonical justified-vtable case)

```c
typedef struct { Drawable *items[SCENE_MAX]; uint8_t n; } Scene;
static inline void scene_init   (Scene *s){ s->n = 0; }
static inline void scene_add    (Scene *s, Drawable *d){ s->items[s->n++] = d; }
static inline void scene_reserve(Scene *s, VramAlloc *va){ for (uint8_t i=0;i<s->n;i++) drawable_reserve(s->items[i], va); }
static inline void scene_emit   (Scene *s, UploadQueue *q){ for (uint8_t i=0;i<s->n;i++) drawable_emit(s->items[i], q); }
```

`scene_emit` is the loop oop-in-c.md §6 describes: `Drawable *items[N]` iterated, one virtual call each.
A scene of one `Mode7Layer` *and* one `SpriteSet` is what genuinely needs the vtable.

### 3e. Concrete drawables (inheritance: base struct first)

`mode7_layer.h` — wraps the verified `mode7.h` logic behind `Drawable`. `src` is the far high-WRAM image
buffer (`M7_FAR`) the client computes; `emit()` uploads it tile-row by tile-row and latches the affine regs.

```c
typedef struct {
  Drawable base;                       /* member 0 — upcast (Drawable*)&m7 is free */
  const M7_FAR uint8_t *src;           /* image, high WRAM (far)                    */
  uint8_t tiles_w, tiles_h;
  int16_t a, b, c, d;                  /* affine matrix (8.8)                       */
  uint16_t cx, cy, sx, sy;             /* centre + scroll                           */
} Mode7Layer;
static inline void mode7_layer_init(Mode7Layer *m, const M7_FAR uint8_t *src, uint8_t tw, uint8_t th);
static inline void mode7_layer_matrix(Mode7Layer *m, int16_t a,int16_t b,int16_t c,int16_t d);
static const DrawableVT MODE7_VT = { mode7_reserve, mode7_emit, 0 };
```

`sprite_set.h` — OAM front-end (spec sketch in handoff §Sprites; *new* verified code). 544-byte RAM shadow,
`emit()` enqueues one OAM DMA (`BBAD_OAMDATA`). `bg_layer.h` — tiled 2/4bpp BG static image: `reserve()` →
`vram_chr`/`vram_map`, `emit()` → char + tilemap + palette DMA. Build order (handoff §3) does BG first to
de-risk a plain DMA upload; Mode 7 is the path we have already proven, so the *verification* client leads
with Mode 7 and adds a second drawable kind for the polymorphism proof.

### 3f. `input.h` — selector-table dispatch (the cheap dynamic form)

```c
typedef void (*Action)(void *ctx);
/* one entry per button bit (JOY_* order); 0 = ignore. Dispatch every pressed button. */
static inline void input_dispatch(uint16_t pad, const Action table[12], void *ctx);
```

The interactive client maps D-pad/buttons → pan/zoom/rotate/palette-cycle actions through `table[]`. The
**measurement** (§5) records whether llvm-mos lowers this to `JSR (abs,X)` (oop-in-c.md §3a) or the
`__call_indir` path — answering the doc's currently-unmeasured §3(a) claim.

---

## 4. The worked client — `examples/snes/mandel-oop.c`

Reproduce `mandel-display.c`'s render **through `snesgfx`**, same CRC `0x204F`, plus a second drawable kind
so the polymorphic container is genuinely exercised:

```c
// mos-a16-only — far pointers (high-WRAM Mandelbrot buffer) are 32-bit values (build.sh greps this marker).
#include <snes.h>
#include "mode7.h"
#include "snesgfx/upload.h"  #include "snesgfx/vram.h"  #include "snesgfx/drawable.h"
#include "snesgfx/scene.h"   #include "snesgfx/mode7_layer.h"  #include "snesgfx/sprite_set.h"
#include "../65816/mandel.h" #include "sincos.h"

static M7_FAR uint8_t *const fb = (M7_FAR uint8_t *)0x7E2000u;   /* the canonical far escape buffer */
volatile uint16_t corpus_result;

int main(void) {
  snes_ppu_reset_blank();
  UploadQueue q; upq_init(&q, /*chan=*/0);
  VramAlloc   va; vram_init(&va, /*chr0*/0, /*map0*/0);
  Mode7Layer  bg; mode7_layer_init(&bg, fb, 8, 7);     /* the fractal layer  */
  SpriteSet   hud; sprite_set_init(&hud);              /* e.g. a centre cursor — forces a 2nd kind */
  Scene s; scene_init(&s); scene_add(&s,(Drawable*)&bg); scene_add(&s,(Drawable*)&hud);
  scene_reserve(&s, &va);
  /* ... compute the Mandelbrot into fb via FAR stores (unchanged math from mandel-display.c) ... */
  for (;;) {
    /* update affine/HUD state (active display) */
    wait_vblank_fresh();
    scene_emit(&s, &q);     /* ONE virtual call per drawable */
    upq_flush(&q);          /* the only code that touches the PPU data ports, in v-blank */
  }
  corpus_result = crc_fb();  /* far-load CRC over fb == 0x204F == tools/mandel-render 64 56 15 */
}
```

A new `dev/run.sh mandel-oop` gate (mirrors `mandel-shot`) builds it `+mos-a16`, boots both emulators
headless, and asserts `corpus_result == 0x204F` on host == a16@MAME == a16@bsnes-jg. (Far pointers can't
compile default-8bit, so — like every far gate — the differential is the a16-only subset; this is the
honest bar for this code, identical to `mandel-shot`/`mandel-far`.)

---

## 5. Measurement — feed real numbers back into oop-in-c.md (the repo bar)

The HOWTO must not assert costs it hasn't measured. This library produces three measurements; they update
`docs/investigations/object-oriented-c-and-assembly.md` §4–§5 in the *same* implementation commit:

1. **Per-object vtable cost, in situ.** Disassemble `mandel-oop.o` (`-mllvm -verify-machineinstrs`,
   `llvm-objdump -d`). Confirm `scene_emit`'s `drawable_emit` lowers to the §4 `__call_indir` sequence and
   count the calls: it must be **once per drawable per frame** (2 here), **never** per tile. Record bytes &
   est. cycles per call.
2. **OOP vs procedural delta.** Compare `.text`/`.rodata` size of `mandel-oop.sfc` (OOP, 2 kinds) vs
   `mandel-display.sfc` (monomorphic, direct calls) from the `.map`s. Quantify the abstraction's cost in
   bytes; confirm the *inner* DMA/byte loops are byte-identical (the cost is only the once-per-frame seam).
3. **Selector-table lowering.** Disassemble `input_dispatch`: does llvm-mos emit `JSR (abs,X)` (§3a) or
   `__call_indir`? Whichever it is, the doc records the *measured* truth (and a `.addr`-table hand-asm note
   if C doesn't reach the one-instruction form).

---

## 6. Phasing (build order de-risks fastest; each phase independently verifiable)

- **P0 — `upload.h` + `vram.h`** (correctness core). Reproduce one Mode 7 tile-row DMA from `mandel-display`
  through `upq_*`/`upq_flush`; byte-diff VRAM vs the procedural path. *Gate before any OOP.*
- **P1 — `drawable.h` + `scene.h` + `mode7_layer.h`**, single-drawable `mandel-oop.c`. Assert CRC `0x204F`
  on both emulators (`dev/run.sh mandel-oop`). This is the zero-regression proof.
- **P2 — `sprite_set.h`**, add the HUD drawable → 2-kind `Scene`. Re-assert `0x204F` (the Mandelbrot CRC is
  unaffected by the sprite), screenshot shows the cursor. This is the polymorphism proof + measurement §5.1/§5.2.
- **P3 — `input.h`** + an interactive variant (or fold into the existing interactive-mandelbrot plan).
  Measurement §5.3. (May be merged with
  [2026-06-25-321-interactive-mandelbrot-mode7.md](2026-06-25-321-interactive-mandelbrot-mode7.md).)
- **P4 — `bg_layer.h`** (tiled 2/4bpp static image via DMA) — completes the handoff's BG front-end. Verified
  with its own CRC/sentinel client.

Each phase: `-mllvm -verify-machineinstrs` clean, both emulators agree, CRC tied to a number (never
"looks right"). `noinline` any register-heavy kernel under `+mos-a16` (handoff §4).

---

## 7. Risks / open questions

- **R1 — vtable cost dominates if mis-budgeted.** Mitigation: the §3c rule (dispatch once/drawable/frame) +
  the §5.1 disasm gate that *counts* the calls. If a virtual call leaks into an inner loop, the gate catches it.
- **R2 — `+mos-a16` register pressure** in `emit()` holding many live 16-bit values (handoff §4). Mitigation:
  `noinline` the hot kernel; always `-verify-machineinstrs`.
- **R3 — header-only vtables across TUs** duplicate `static const *VT` rodata. Fine for single-TU demos;
  documented as the multi-TU caveat. Not a correctness issue.
- **Q1 — does C reach `JSR (abs,X)`?** Open until §5.3 measures it. The doc currently *asserts* §3a is cheap.
- **Q2 — promote to `platforms/snes/gfx/`?** Deferred until P1–P2 are green on the bar (verified-first).

---

## 8. Verification (run during implementation; paste raw output + PASS/FAIL back here)

> Steps are the spec; output is the evidence. Marked **PENDING** until the implementation phase runs them.

1. **P0 byte-equivalence:** dump VRAM for a single Mode 7 tile-row uploaded via `upq_*` and via the
   procedural `dma_chr_to`, diff the bytes.
   ```
   PENDING — JGX_VRAM=1 jgxcheck dump vs mandel-display reference; expect identical.
   ```
2. **P1 differential CRC:** `dev/run.sh mandel-oop` — assert `corpus_result == 0x204F` on host ==
   a16@MAME == a16@bsnes-jg.
   ```
   PENDING
   ```
3. **`-verify-machineinstrs` clean** for `mandel-oop.c` (`+mos-a16`).
   ```
   PENDING
   ```
4. **P2 polymorphism + CRC unchanged:** 2-kind scene still asserts `0x204F`; screenshot shows the HUD sprite.
   ```
   PENDING
   ```
5. **§5.1 dispatch count:** `llvm-objdump -d mandel-oop.o` — exactly N `__call_indir`/frame (N = #drawables),
   none in the per-tile loop.
   ```
   PENDING
   ```
6. **§5.2 size delta:** `.text`+`.rodata` of `mandel-oop.sfc` vs `mandel-display.sfc` from the `.map`s.
   ```
   PENDING
   ```
7. **§5.3 selector lowering:** disasm `input_dispatch` → record `JSR (abs,X)` vs `__call_indir`; update the doc.
   ```
   PENDING
   ```
8. **Doc updated in the same commit:** oop-in-c.md §4/§5 carry the §5.1–§5.3 measured numbers; `oop-in-c.md`
   build copy regenerates (`dev/build-release-docs.sh`, reads committed `main`).
   ```
   PENDING
   ```

---

## 9. References

- Rendering handoff (mechanics + recommended shape): [docs/handoffs/2026-06-24-snes-graphics-rendering.md](../handoffs/2026-06-24-snes-graphics-rendering.md)
- OOP-in-C HOWTO (the grammar + measured §4 lowering): [docs/investigations/object-oriented-c-and-assembly.md](../investigations/object-oriented-c-and-assembly.md)
- Verified procedural source: [examples/snes/mandel-display.c](../../examples/snes/mandel-display.c), [examples/snes/mode7.h](../../examples/snes/mode7.h)
- HAL: [platforms/snes/snes.h](../../platforms/snes/snes.h), `snes_ppu.h` / `snes_dma.h` (DMAP_*/BBAD_* constants) / `snes_joypad.h` (JOY_*, `snes_read_pad1`)
- Sibling demo plans this library can subsume: [2026-06-25-321-interactive-mandelbrot-mode7.md](2026-06-25-321-interactive-mandelbrot-mode7.md), [2026-06-24-snes-mandelbrot-beefy-demo.md](2026-06-24-snes-mandelbrot-beefy-demo.md)
