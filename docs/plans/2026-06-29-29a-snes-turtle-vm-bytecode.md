# #29a — SNES Bytecode-VM Turtle: jump-table dispatch + function-pointer opcode table

<!-- Title card — fill in after the gate runs (step 9): the SAME build/turtle-vm-jg.png that becomes the
     /snes-rom-page --preview. Path is screenshots/turtle-vm.png (relative to docs/plans/). -->
<p align="center"><img src="screenshots/turtle-vm.png" width="512" alt="Bytecode-VM Turtle demo running on the SNES (bsnes-jg render)"></p>

**Status:** PUBLISHED — [biohack.net/snes/turtle-vm/](https://biohack.net/snes/turtle-vm/) (`v1.0.130`).
RESULT PASS, bit-exact 5-way differential (`0x4007`), no compiler bug (jump-table / function-pointer
dispatch correct in default / +mos-a16 / +mos-xy16 — a live confirmation of the xy16 `JMPIdxIndir`
hardening). Demo **#29a** of the **compiler stress-test demo battery** — a **Round 2** entry (new codegen
corners). See
[`docs/investigations/2026-06-27-compiler-stress-test-demo-ideas.md`](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md).

## Context

Every demo so far is straight-line arithmetic with simple branches. **None use computed / indirect
control flow.** This one is a tiny **stack-machine bytecode interpreter** that draws LOGO-style **turtle
graphics**, and it leans on the two indirect-dispatch corners the battery never executes:

1. **Jump-table dispatch** — the interpreter's main `switch (op)` over a *dense* opcode range lowers to a
   **`JMP (abs,X)`** (the `JMPIdxIndir` pseudo) — a computed branch through a table of code addresses.
   This is exactly the dispatch the recent **xy16 `requiredXWidth` hardening** singled out as the one
   jump-table family member the memory rule couldn't reach, so the demo is a *live* cross-mode exercise of
   that fix (default / +mos-a16 / +mos-xy16 must all dispatch identically).
2. **Function-pointer opcode table** — the binary ALU ops (`+ − × min max …`) are stored in a
   `static const` array of function pointers and invoked **indirectly** (`jsr __call_indir` through a
   `.rodata` table). The classic VM "opcode table", never built before here.

Confirmed both lower as intended at `-Os`/`+mos-a16` (measured: `jmp ($0,x)` for the switch,
`jsr __call_indir` + `R_MOS_ADDR16 .rodata.<table>` for the fnptr call).

**Bit-exact differential.** The VM is deterministic integer fixed-point (turtle position Q8.8, heading
0..255 indexing the shared `SINCOS` 8.8 LUT; segment math widened to `int32_t` → `__mulsi3`). Exact ⇒
host x86 == console bit-for-bit; a jump-table or indirect-call miscompile dispatches a wrong opcode and the
path CRC diverges. Far-pointer-free (bytecode, stacks, turtle all in bank-0 WRAM; near function pointers)
⇒ full **5-way bar**.

The picture is the proof: a correct VM walks the bytecode into a coherent **multi-colour spiral rosette**;
a dispatch miscompile scrambles the opcodes and the turtle scrawls garbage (or the CRC freezes).

## Algorithm

A stack machine. Dense opcodes 0..N (so the dispatch `switch` becomes a jump table):

```
OP_PUSH  (imm)   push a 1-byte immediate
OP_ALU   (sub)   pop b,a → push ALU_TAB[sub](a,b)     # function-pointer table (indirect call)
OP_FWD           pop d → turtle moves forward d; emit a line segment if pen down
OP_TURN          pop a → heading = (heading + a) & 255
OP_PEN   (col)   set pen colour 0..3 (0 = up)
OP_REP   (n)     push loop frame (count=n, start=pc)
OP_ENDREP        if --count > 0 jump to start; else pop frame
OP_ITER          push the current loop's iteration index (drives growing-spiral arithmetic)
OP_DUP / OP_DROP stack manipulation
OP_HALT          stop

vm_run(prog):                          # the hot loop — switch(op) → JMP (abs,X) jump table
  while op != HALT:
    switch (op) { case OP_PUSH: ...; case OP_ALU: ... ALU_TAB[sub](a,b) ...; ... }

# turtle move (FWD), Q8.8 position, SINCOS 8.8 LUT:
dx = (int32_t)d * SINCOS[(h+64)&255]   # __mulsi3 ; cos
dy = (int32_t)d * SINCOS[ h      ]     # __mulsi3 ; sin
x += dx ; y += dy                      # Q8.8 accumulate ; pixel = >>8
```

**Gate** (`vm_gate_crc`): run the fixed bytecode program with `segs=NULL` (no storage — pure dispatch),
folding every emitted segment's endpoints + colour into a rotate-XOR CRC16. The whole run flows through the
jump-table switch and the fnptr ALU table, so the CRC is a bit-exact witness of both dispatch paths.

## Screen layout

```
256 x 224, Mode 1.
+--------------------------------------------------+  BG2  TitleLayer (fly-in, then hidden)
| BYTECODE VM                          TURTLE      |
|                                                  |
|              +----------------+                  |  BG3  BitmapCanvas 128x128 (2bpp), centred
|              |   the spiral   |                  |       box at tile col 8, row 6 — the turtle
|              |   rosette grows|                  |       draws here, colour by pen opcode
|              +----------------+                  |
+--------------------------------------------------+
```

## Display architecture

- **`Display` + `BitmapCanvas` (BG3 2bpp) + `TitleLayer` (BG2)** — mirrors `examples/snes/spirograph.c`.
- **Canvas:** 128×128, centred (box col 8, row 6). 4 colours (CGRAM[0..3]): bg + 3 pen hues.
- **VM state:** bytecode (ROM `const`), data stack, loop stack, turtle — all bank-0 WRAM. A compact segment
  buffer (`uint8_t x0,y0,x1,y1,col` ×~160 = ~800 B) the ROM drains a few lines/frame so the turtle is seen
  drawing; the gate/corpus slice pass `segs=NULL` (no buffer).
- **DMA budget:** canvas dirty-tile cap (`CANVAS_FLUSH_TILES=64` → ≤ 1 KiB/frame) + the title's tiny CGRAM.

## Files

| File | New/Mod | Purpose |
|---|---|---|
| `examples/65816/turtle_vm.h` | new | shared stack-machine VM + turtle + gate |
| `examples/snes/turtle-vm.c` | new | on-SNES BitmapCanvas turtle renderer |
| `examples/snes/corpus/turtle-vm_sim.c` | new | 5-way differential corpus slice |
| `tools/turtle-vm-sim.c` | new | host oracle |
| `dev/turtle-vm.sh` / `dev/turtle-vm.lua` | new | differential gate + MAME autoboot |
| `Taskfile.yml`, `examples/snes/corpus/expected.tsv` | mod | task + golden row |
| `TODO.md`, `docs/investigations/plan-index.md`, demo-ideas backlog | mod | tracking |

## Reused infrastructure

| Asset | From | Used for |
|---|---|---|
| `BitmapCanvas` (set-pixel + Bresenham + capped DMA) | `snesgfx/bitmap_canvas.h` | the turtle's drawing surface |
| `TitleLayer` | `snesgfx/title_layer.h` | BG2 title overlay |
| `SINCOS` 8.8 LUT | `examples/snes/sincos.h` | turtle FWD direction |
| jgxcheck / Lua autoboot / checksum | `dev/avalanche.sh` pattern | the gate |

## Differential gate

- `corpus_result = vm_gate_crc()` — run the program, rotate-XOR CRC16 of all emitted segments.
- `EXPECT = 0x4007` (host oracle, stable `-O2` == `-O0`). corpus_result @ WRAM `0x20`.
- **5-way bar** — far-pointer-free (near function pointers; data in bank-0).
- Disasm probes (on `corpus/turtle-vm_sim.o`): **`jmp (…,x)` ≥ 1** (jump-table dispatch / JMPIdxIndir)
  **and** **`__call_indir` ≥ 1** (function-pointer opcode table) **and** `rep|sep ≥ 1`. The two indirect
  dispatches are the point; `__mulsi3` (turtle trig) is a bonus.

## Publication

```
/snes-rom-page --rom build/turtle-vm.sfc --slug turtle-vm --site ~/SRC/biohack.net
  --title "Bytecode-VM Turtle" --preview build/turtle-vm-jg.png
  --selfcheck "0x20 2 0x4007 600 vm-dispatch"
```

## Verification steps

1. Host oracle compiles and prints a stable CRC (`-O2` == `-O0`). PASS — `0x4007` at both opt levels;
   the program emits 180 segments, bbox `[14,13]..[116,115]` (centred, in-bounds, no clamp distortion).
2. ROM builds clean; snes-checksum.py exits 0. (Folded into step 4.)
3. Corpus slice host-compiles; exits 0. PASS (loops forever by design after the CRC latch).
4. `dev/run.sh turtle-vm` — host oracle + disasm gate + bsnes-jg PASS.

```
==> host oracle: Bytecode-VM Turtle gate hash = 0x4007
==> built build/turtle-vm.sfc (+mos-a16); corpus_result @ WRAM 0x20
==> disasm gate (jump-table + function-pointer dispatch codegen)
    PASS  jump-table=1  __call_indir=1  __mulsi3=2  rep/sep=155  (indirect dispatch, native-16)
==> bsnes-jg: render + framebuffer dump (build/turtle-vm-jg.png) + assert
SMOKE: PASS off=0x20 len=2 got=0x4007 (ran 600 frames, bsnes-jg)
RESULT: PASS — Bytecode-VM Turtle rendered on SNES; ... corpus hash 0x4007 host == +mos-a16
```
PASS — both indirect dispatches present (`JMP (abs,X)` jump table + `jsr __call_indir`).

5. 5-way on bsnes-jg (MAME SKIP env-wide — no SPC700 IPL, demos-only non-blocker). Built the corpus slice
   in each mode, asserted `0x4007`, `-verify-machineinstrs` clean for the native-16 modes:

```
default  corpus_result@0x200 verify:clean  SMOKE: PASS got=0x4007 (500 frames, bsnes-jg)
a16      corpus_result@0x200 verify:clean  SMOKE: PASS got=0x4007 (500 frames, bsnes-jg)
xy16     corpus_result@0x200 verify:clean  SMOKE: PASS got=0x4007 (500 frames, bsnes-jg)
```
PASS — host == default == +mos-a16 == +mos-xy16. The jump-table dispatch (JMPIdxIndir) and the
function-pointer table dispatch correctly in **every** mode, including xy16 — a live confirmation of the
`requiredXWidth` JMPIdxIndir hardening. No compiler bug surfaced.

6. Title card — `build/turtle-vm-jg.png` copied to `docs/plans/screenshots/turtle-vm.png`, embedded under
   the H1. PASS — a woven multi-colour rosette ring (3 pen hues cycled via the ALU table).

7. /snes-rom-page publishes; the page serves and the deployed ROM renders. PASS — `src/pages/snes/turtle-vm.astro`
   + gallery entry built (30 pages), `/snes/turtle-vm/` serves HTTP 200, and `public/play/roms/turtle-vm.sfc`
   is **sha256-identical** to the `build/turtle-vm.sfc` rendered in bsnes-jg. Committed `2802222`, deployed
   `biohack.net v1.0.130` (tag pushed → Cloudflare Pages).

8. `task md -- docs/plans/2026-06-29-29a-snes-turtle-vm-bytecode.md` renders cleanly (title card resolves). PASS.
