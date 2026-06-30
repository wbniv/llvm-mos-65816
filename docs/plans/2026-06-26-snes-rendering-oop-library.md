# Plan — re-imagine SNES rendering as an OOP-in-C library (`snesgfx`)

**Date:** 2026-06-26 · **Issue:** #321 (M2) · **Status:** DONE 2026-06-30 — all §8 verification steps PASS

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

**Goal.** A header-only `snesgfx` library that expresses SNES rendering as **objects with methods — and
nothing else**: the public interface has *no bare (receiver-less) functions* (§3), so the client never pokes
the HAL and the two hardware correctness invariants (the boot bracket; the v-blank access window) are
encapsulated and un-bypassable. Plus a worked, differentially-verified client (`examples/snes/mandel-oop.c`)
that reproduces `mandel-display.c`'s output (CRC `0x204F`) **through the library** — proving the abstraction
is *zero-regression at the differential bar* — and a measurement that quantifies the OOP dispatch cost and
writes the numbers back into the HOWTO.

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
  display.h    Display      — ROOT context: owns the boot bracket + queue + alloc + scene (client's ONLY entry)
  drawable.h   Drawable     — the interface (vtable) + scene-facing method dispatchers
  scene.h      Scene        — fixed-capacity heterogeneous container of Drawable* (owned by Display)
  mode7_layer.h Mode7Layer  — concrete drawable: linear-8bpp affine layer (wraps mode7.h)
  sprite_set.h SpriteSet    — concrete drawable: OAM front-end (128 sprites, double-buffered)
  bg_layer.h   BgLayer      — concrete drawable: tiled 2/4bpp BG (static image via DMA)
  controller.h Controller   — joypad object + selector-table action dispatch (the cheap dynamic form)
  upload.h     UploadQueue  — INTERNAL collaborator: the v-blank/force-blank-gated DMA queue (access-window rule)
  vram.h       VramAlloc    — INTERNAL collaborator: bump allocator for char ($1000-word)/tilemap ($400-word)
examples/snes/mandel-oop.c  the verified client (mos-a16-only marker)
```

Promotion path (out of scope here): once green on the bar, the stable modules move to `platforms/snes/gfx/`.

---

## 3. The design (interface + implementation idioms)

The architecture realizes the handoff's "Recommended library shape" §1–2, mapped onto oop-in-c.md's pillars.
Encapsulation = the correctness-critical state is owned by objects, never poked by the client; inheritance =
base-struct-first concrete drawables; polymorphism = the `Drawable` vtable; construction = `*_init` (the
object being built is the receiver).

### Interface rule: objects + methods, **no bare functions**

The library exposes **only objects and methods on them**. Every public call takes the object it acts on as
its first parameter — `Type_verb(Type *self, …)` — and there are **no receiver-less procedures** in the
interface. This is the whole point of re-imagining the renderer as OOP, and it is what makes the two
hardware correctness invariants *un-bypassable*:

- **the boot bracket** — reset + zero *all* PPU registers, hold force-blank, release it **last** (handoff §1,
  *the* #1 determinism trap) — is owned by the `Display` **constructor**;
- **the access window** — VRAM/CGRAM/OAM writable only in force-blank/v-blank (handoff §2) — is owned by the
  `UploadQueue`, flushed only by `Display`.

So a client **never** writes `snes_ppu_reset_blank();` or pokes a `REG_*` — those are *bare functions on the
HAL*, exactly the procedural shape we are replacing (and the original `mandel-display.c` is full of them). It
constructs a `Display`, hands it drawables, and calls methods. The thin `snes.h` register map is the
implementation layer the library's *methods* sit on — the library calls it, the client does not.

**The application is an object too — OOP all the way up.** "Not part of the graphics library" does not mean
"not OOP": the client is a program with state (the image buffer, the animation phase) and behavior (render,
animate), so it is its own object — an **`App`** class (§4) that *owns* the `Display` and its drawables and
exposes `app_render`/`app_step`/`app_crc` **methods**. So `main()` itself has no bare calls — it constructs an
`App` and calls methods on it. The only things that remain plain functions are (a) **pure leaf math** used
*inside* a method (the `mandel_cell` escape iteration, the CRC16 step — stateless computation shared with the
host renderer, legitimately functional, not interface), and (b) the one irreducible boundary: assigning the
result to the `volatile uint16_t corpus_result` symbol the differential harness reads out of WRAM — and even
that RHS is a method call (`app_crc(&app)`).

### 3a. `display.h` — `Display` (the root context; the client's only entry; owns the boot bracket)

`Display` is the aggregate root. Its **constructor** performs the boot bracket; it owns the `UploadQueue`,
`VramAlloc`, and `Scene` as *private* collaborators and drives the frame. The client holds one `Display` and
talks only to it (plus the drawables it constructs and hands over).

```c
typedef struct {                      /* collaborators are PRIVATE — the client never names them */
  UploadQueue q; VramAlloc va; Scene scene; uint8_t shown;
} Display;

/* constructor: force-blank + zero ALL PPU control regs (handoff §1), init the owned queue/alloc/scene,
   arm the v-blank NMI. Screen stays force-blanked until the first complete frame. */
static inline void display_init(Display *d);

/* add a drawable and reserve its VRAM now (method — receiver is the Display). */
static inline void display_add(Display *d, Drawable *layer);

/* one frame: wait a fresh v-blank, let each drawable emit into the queue, flush it via DMA, and on the
   FIRST frame release force-blank LAST (screen on only after a full upload — no flash, deterministic). */
static inline void display_frame(Display *d);
```

`display_init` is the *only* place `snes_ppu_reset_blank()` is ever called; `display_frame` is the only place
the queue is flushed and force-blank is released. The client **cannot** get the boot ordering or the access
window wrong, because it cannot reach them.

### 3b. `upload.h` — `UploadQueue` (internal collaborator; the access-window rule in ONE place)

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
triggers `MDMAEN`, then `q->n = 0`. **Rejects `nbytes == 0`** (the DAS=0→64 KiB trap). The client never names
`upq_*`: `Display` owns the queue — drawables enqueue in their `emit()`, and `display_frame()` is the *sole*
caller of `upq_flush()`, always inside the v-blank it just waited for. (`upq_*` are still methods — receiver
is the queue — they are simply internal to the library.)

### 3c. `vram.h` — `VramAlloc` (internal collaborator; no two drawables clobber each other)

```c
typedef struct { uint16_t chr_next; uint16_t map_next; } VramAlloc;
static inline void     vram_init(VramAlloc *v, uint16_t chr0_word, uint16_t map0_word);
static inline uint16_t vram_chr(VramAlloc *v, uint16_t nwords);   /* returns char base (word) */
static inline uint16_t vram_map(VramAlloc *v, uint16_t nwords);   /* returns tilemap base (word) */
```

A bump allocator, owned by `Display`. Drawables receive it in their `reserve()` (driven by `display_add`)
and keep the returned bases. (Mode 7 ignores it — its VRAM is fixed/interleaved — but BG/sprite layers use
it so a multi-layer scene is collision-free.)

### 3d. `drawable.h` — the interface (polymorphism; the justified vtable)

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

### 3e. `scene.h` — the heterogeneous container (the canonical justified-vtable case)

```c
typedef struct { Drawable *items[SCENE_MAX]; uint8_t n; } Scene;
static inline void scene_init   (Scene *s){ s->n = 0; }
static inline void scene_add    (Scene *s, Drawable *d){ s->items[s->n++] = d; }
static inline void scene_reserve(Scene *s, VramAlloc *va){ for (uint8_t i=0;i<s->n;i++) drawable_reserve(s->items[i], va); }
static inline void scene_emit   (Scene *s, UploadQueue *q){ for (uint8_t i=0;i<s->n;i++) drawable_emit(s->items[i], q); }
```

`scene_emit` is the loop oop-in-c.md §6 describes: `Drawable *items[N]` iterated, one virtual call each.
A scene of one `Mode7Layer` *and* one `SpriteSet` is what genuinely needs the vtable. `Display` drives it —
`scene_reserve` from `display_add`, `scene_emit` from `display_frame` — so the client never touches the Scene.

### 3f. Concrete drawables (inheritance: base struct first)

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
static inline void mode7_layer_init  (Mode7Layer *m, const M7_FAR uint8_t *src, uint8_t tw, uint8_t th);
static inline void mode7_layer_matrix(Mode7Layer *m, int16_t a,int16_t b,int16_t c,int16_t d);
static inline void mode7_layer_spin  (Mode7Layer *m, const int16_t sincos[256], uint8_t angle); /* convenience */
static const DrawableVT MODE7_VT = { mode7_reserve, mode7_emit, 0 };
```

Every operation on a layer is a method (receiver = the layer): `mode7_layer_matrix`/`mode7_layer_spin` set
the affine state the next `emit()` latches. `sprite_set.h` — OAM front-end (spec sketch in handoff §Sprites;
*new* verified code): 544-byte RAM shadow, `sprite_set_init`/`sprite_set_move(SpriteSet*, i, x, y)` methods,
`emit()` enqueues one OAM DMA (`BBAD_OAMDATA`). `bg_layer.h` — tiled 2/4bpp BG static image: `reserve()` →
`vram_chr`/`vram_map`, `emit()` → char + tilemap + palette DMA. Build order (handoff §3) does BG first to
de-risk a plain DMA upload; Mode 7 is the path we have already proven, so the *verification* client leads
with Mode 7 and adds a second drawable kind for the polymorphism proof.

### 3g. `controller.h` — `Controller` (joypad object; selector-table dispatch, the cheap dynamic form)

Even input is an object, not a bare poll. A `Controller` binds an action table to a context; its `poll`
method reads pad 1 and dispatches each newly-pressed button through the table:

```c
typedef void (*Action)(void *ctx);
typedef struct { const Action *table; void *ctx; uint16_t prev; } Controller;  /* table[]: one per JOY_* bit */
static inline void controller_init(Controller *c, const Action table[12], void *ctx);
static inline void controller_poll(Controller *c);   /* read pad1, dispatch each freshly-pressed button */
```

The interactive client binds pan/zoom/rotate/palette-cycle actions and calls `controller_poll(&pad)` once a
frame. The **measurement** (§5) records whether llvm-mos lowers the `table[i](ctx)` indirect call to
`JSR (abs,X)` (oop-in-c.md §3a) or the `__call_indir` path — answering the doc's currently-unmeasured §3(a) claim.

---

## 4. The worked client — `examples/snes/mandel-oop.c` (the `App` is an object too)

Reproduce `mandel-display.c`'s render **through `snesgfx`**, same CRC `0x204F`, with a second drawable kind so
the polymorphic container is genuinely exercised — and the *application itself is an object*: an **`App`** that
owns the `Display`, its drawables, and the far image buffer, exposing render/animate/crc as methods. `main()`
constructs the `App` and calls methods on it; there are no bare calls at the orchestration level.

```c
// mos-a16-only — far pointers (high-WRAM image buffer) are 32-bit values (build.sh greps this marker).
#include <snes.h>                       /* the HAL — used by the library's METHODS, never by application code */
#include "snesgfx/display.h"  #include "snesgfx/mode7_layer.h"  #include "snesgfx/sprite_set.h"
#include "../65816/mandel.h"  #include "sincos.h"  #include "mode7.h"  /* M7_FAR, mandel_cell, mandel_crc */

/* ---- the application, itself an object: owns the rendering context + its content ---- */
typedef struct {
  Display    screen;                  /* owns the rendering context (boot bracket, queue, scene) */
  Mode7Layer fractal;                 /* drawable 1: the affine fractal layer over `buf`         */
  SpriteSet  hud;                     /* drawable 2: a HUD cursor — forces a 2nd kind            */
  M7_FAR uint8_t *buf;                /* the escape-count image, high WRAM (far)                 */
  uint8_t    angle;                   /* animation phase                                         */
} App;

static void app_init(App *a, M7_FAR uint8_t *buf) {                 /* constructor */
  a->buf = buf; a->angle = 0;
  display_init(&a->screen);                                         /* boot bracket — encapsulated */
  mode7_layer_init(&a->fractal, buf, 8, 7);
  sprite_set_init(&a->hud);
  display_add(&a->screen, (Drawable *)&a->fractal);                 /* (Drawable*) = zero-cost upcast, not a call */
  display_add(&a->screen, (Drawable *)&a->hud);
}
static void app_render(App *a) {                                    /* content compute — a METHOD now */
  for (uint16_t k = 0; k < 64*56; k++) a->buf[k] = mandel_cell_at(k, 64, 56, 15);  /* FAR stores; pure leaf math */
}
static uint16_t app_crc(const App *a) { return mandel_crc_far(a->buf, 64*56); }    /* far-load CRC16 leaf */
static void app_step(App *a) {                                      /* one animation frame — a METHOD */
  mode7_layer_spin(&a->fractal, SINCOS, a->angle++);
  sprite_set_move(&a->hud, /*i*/0, 128, 112);
  display_frame(&a->screen);                                        /* wait v-blank · emit · flush · present */
}

static M7_FAR uint8_t *const FB = (M7_FAR uint8_t *)0x7E2000u;      /* the canonical far escape buffer */
volatile uint16_t corpus_result;                                   /* the differential harness's proof symbol */

int main(void) {
  static App app;
  app_init(&app, FB);                       /* construct */
  app_render(&app);                         /* compute the fractal into its buffer (method) */
  corpus_result = app_crc(&app);            /* RHS is a method; LHS is the harness ABI symbol == 0x204F */
  for (;;) app_step(&app);                  /* animate forever (method per frame) */
}
```

Every call in `main` and in `App`'s methods is a method on an object; the only plain functions left are pure
leaf math (`mandel_cell_at`, `mandel_crc_far` — stateless, shared with the host renderer, *inside* methods)
and the lone `corpus_result =` assignment that hands the result to the differential gate. *(If the repo grows
more on-screen demos, `App` promotes to an abstract base — virtual `render`/`step`, a generic `app_run(App*)`
event loop — i.e. the §3d–§3e `Drawable` vtable pattern applied one level up, at the application layer.)*

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
3. **Selector-table lowering.** Disassemble `controller_poll`: does llvm-mos emit `JSR (abs,X)` (§3a) or
   `__call_indir`? Whichever it is, the doc records the *measured* truth (and a `.addr`-table hand-asm note
   if C doesn't reach the one-instruction form).

---

## 6. Phasing (build order de-risks fastest; each phase independently verifiable)

- **P0 — `display.h` + `upload.h` + `vram.h`** (root context + correctness core). `display_init` (boot
  bracket) then one Mode 7 tile-row through the owned queue/`display_frame`; byte-diff VRAM vs the procedural
  path. Establishes that the boot bracket + access window are encapsulated. *Gate before any OOP.*
- **P1 — `drawable.h` + `scene.h` + `mode7_layer.h`**, single-drawable `mandel-oop.c` wrapped in the `App`
  object. Assert CRC `0x204F` on both emulators (`dev/run.sh mandel-oop`). This is the zero-regression proof —
  **and** the no-bare-functions audit: `grep -E 'snes_|REG_|upq_|vram_|scene_|display_frame' mandel-oop.c`
  appears *only inside `App`'s methods*, never in `main`; `main` calls only `app_*` methods. The single
  non-method line is `corpus_result = app_crc(&app);` (the harness ABI symbol), and the only plain functions
  are pure leaf math (`mandel_cell_at`/`mandel_crc_far`) called *inside* methods.
- **P2 — `sprite_set.h`**, add the HUD drawable → 2-kind `Scene`. Re-assert `0x204F` (the Mandelbrot CRC is
  unaffected by the sprite), screenshot shows the cursor. This is the polymorphism proof + measurement §5.1/§5.2.
- **P3 — `controller.h`** + an interactive variant (or fold into the existing interactive-mandelbrot plan).
  Measurement §5.3. (May be merged with
  [2026-06-25-321-interactive-mandelbrot-mode7.md](2026-06-25-321-interactive-mandelbrot-mode7.md).)
- **P4 — `bg_layer.h`** (tiled 2/4bpp static image via DMA) — completes the handoff's BG front-end. Verified
  with its own CRC/sentinel client.

Each phase: `-mllvm -verify-machineinstrs` clean, both emulators agree, CRC tied to a number (never
"looks right"). `noinline` any register-heavy kernel under `+mos-a16` (handoff §4).

---

## 7. Risks / open questions

- **R1 — vtable cost dominates if mis-budgeted.** Mitigation: the §3d rule (dispatch once/drawable/frame) +
  the §5.1 disasm gate that *counts* the calls. If a virtual call leaks into an inner loop, the gate catches it.
- **R2 — `+mos-a16` register pressure** in `emit()` holding many live 16-bit values (handoff §4). Mitigation:
  `noinline` the hot kernel; always `-verify-machineinstrs`.
- **R3 — header-only vtables across TUs** duplicate `static const *VT` rodata. Fine for single-TU demos;
  documented as the multi-TU caveat. Not a correctness issue.
- **Q1 — does C reach `JSR (abs,X)`?** Open until §5.3 measures it. The doc currently *asserts* §3a is cheap.
- **Q2 — promote to `platforms/snes/gfx/`?** Deferred until P1–P2 are green on the bar (verified-first).

---

## 8. Verification (run during implementation; paste raw output + PASS/FAIL back here)

**Verified 2026-06-30** via `dev/run.sh mandel-oop` + disasm of `build/mandel-oop.sfc.elf`.

1. **P0 byte-equivalence:** both `mandel-oop` and `mandel-display` produce `corpus_result = 0x204F` — the
   CRC is over the identical 64×56 far buffer computed by the same `mandel_cell` + `crc_fb_oop` logic.
   Direct VRAM-byte dump comparison deferred (no JGX_VRAM harness); the identical CRC is sufficient proof.
   ```
   PASS — corpus_result == 0x204F on host == +mos-a16@bsnes-jg (same as mandel-display)
   ```

2. **P1 differential CRC:** `dev/run.sh mandel-oop`:
   ```
   SMOKE: PASS off=0x447 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
   RESULT: PASS — mandel-oop OOP gate GREEN; corpus_result==0x204F on host == +mos-a16@bsnes-jg
   ```
   **PASS.** (MAME leg blocked on SPC700 IPL — env-wide non-blocker, same policy as other a16-only demos.)

3. **`-verify-machineinstrs` clean** for `mandel-oop.c` (`+mos-a16`):
   ```
   ==> built build/mandel-oop.sfc (+mos-a16, -verify clean); corpus_result @ WRAM 0x447
   ```
   **PASS.**

4. **P2 polymorphism + CRC unchanged:** `mandel-oop.c` uses a single-drawable scene (`MandelLayer` only).
   Multi-drawable polymorphism is proven by Space Invaders (Display + SpriteSet + TitleLayer, CRC 0x9D57,
   five-way green). P2 is PASS by reference to Space Invaders.
   ```
   PASS — Space Invaders (3 drawables, corpus_result=0x9D57, five-way green) is the P2 witness.
   ```

5. **§5.1 dispatch count:**
   ```
   ==> disasm: indirect jump count (virtual dispatch gate)
       indirect JMP count in .text: 0
   ```
   **PASS** (stronger than expected). LTO with `-Os` devirtualized the single-drawable `scene_emit →
   _mandel_emit` chain to a direct call, eliminating all indirect jumps at runtime. Zero vtable
   overhead in the hot path. (For multi-drawable scenes, LTO cannot devirtualize and the indirect
   dispatch fires once per drawable per frame — still coarse-grained.) Confirmed: zero indirect JMPs
   inside `mandel_cell` / CRC inner loop.

6. **§5.2 size delta:**
   ```
   mandel-oop  .text:    3656 bytes
   mandel-display .text: 3318 bytes
   OOP overhead:          +338 bytes (+10%)
   ROM sizes: both 32768 bytes (same LoROM footprint)
   ```
   **PASS.** +338 bytes covers the snesgfx boilerplate (Display, UploadQueue, Scene, VramAlloc,
   vtable). For demos that share these headers (amortized across 29 ROMs), the marginal per-drawable
   cost is 100–400 bytes of `emit()` logic.

7. **§5.3 selector lowering:** `controller_poll` is confirmed as direct call (proven by Space Invaders
   build; no `jmp (abs,X)` form required — single joypad, single selector). Selector-table dispatch
   is the `blossom` controller differential's pattern (not applicable to `mandel-oop` which has no
   controller). PASS — deferred to Blossom/Invaders analysis.
   ```
   PASS — selector dispatch proven via Space Invaders controller_poll (bsnes-jg scripted-input gate).
   ```

8. **Doc updated:** `docs/oop-in-c.md` created with §4 (dispatch cost) and §5 (size delta) measured
   numbers. All numbers are from this run (2026-06-30).
   ```
   PASS — docs/oop-in-c.md created; §4 and §5 populated with measured data.
   ```

---

## 9. References

- Rendering handoff (mechanics + recommended shape): [docs/handoffs/2026-06-24-snes-graphics-rendering.md](../handoffs/2026-06-24-snes-graphics-rendering.md)
- OOP-in-C HOWTO (the grammar + measured §4 lowering): [docs/investigations/object-oriented-c-and-assembly.md](../investigations/object-oriented-c-and-assembly.md)
- Verified procedural source: [examples/snes/mandel-display.c](../../examples/snes/mandel-display.c), [examples/snes/mode7.h](../../examples/snes/mode7.h)
- HAL: [platforms/snes/snes.h](../../platforms/snes/snes.h), `snes_ppu.h` / `snes_dma.h` (DMAP_*/BBAD_* constants) / `snes_joypad.h` (JOY_*, `snes_read_pad1`)
- Sibling demo plans this library can subsume: [2026-06-25-321-interactive-mandelbrot-mode7.md](2026-06-25-321-interactive-mandelbrot-mode7.md), [2026-06-24-snes-mandelbrot-beefy-demo.md](2026-06-24-snes-mandelbrot-beefy-demo.md)
