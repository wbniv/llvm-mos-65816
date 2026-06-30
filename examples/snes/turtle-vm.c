// #29a — Bytecode-VM Turtle on the SNES.
//
// A tiny stack-machine bytecode interpreter (examples/65816/turtle_vm.h) draws LOGO-style turtle
// graphics into a NEAR 2bpp bitmap canvas (BG3). The interpreter is the whole point: its main switch(op)
// over a dense opcode range lowers to a JMP (abs,X) jump-table dispatch (the JMPIdxIndir pseudo the xy16
// requiredXWidth hardening singled out), and the binary ALU ops dispatch through a function-pointer
// opcode table (jsr __call_indir) — the indirect / computed control-flow corners no other demo runs.
//
// The picture IS the proof: a correct VM walks the bytecode into a coherent multi-colour spiral rosette;
// a jump-table or indirect-call miscompile dispatches a wrong opcode and the turtle scrawls garbage (or
// the gate CRC freezes). No far pointers (bytecode/stacks/turtle in bank-0 WRAM, near function pointers)
// so the corpus slice (turtle-vm_sim.c) is a full 5-way differential: corpus_result = vm_gate_crc() ==
// the host oracle (tools/turtle-vm-sim.c) == 0x4007, bit-for-bit, across default / +mos-a16 / +mos-xy16.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/title_layer.h"
#include "../65816/turtle_vm.h"

#define CANVAS_CHR     0x0000   // BG3 char base (word) — canvas tiles 0..255
#define CANVAS_MAP     0x4000   // BG3 tilemap base (word)
#define BOX_COL        8        // 16-tile (128 px) canvas box at cols 8..23  (screen px 64..191)
#define BOX_ROW        6        // rows 6..21 (screen px 48..175)
#define SEGS_PER_FRAME 2        // turtle draws this many line segments per frame (the "drawing" anim)

volatile uint16_t corpus_result;   // differential proof channel (read from WRAM by the gate)

// BG3 2bpp palette (CGRAM 0..3): 0 = black bg, then the three pen hues the bytecode cycles through.
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(31, 6, 22), SNES_RGB(31, 28, 0), SNES_RGB(4, 26, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  Seg          segs[VM_MAX_SEG];
  uint16_t     nseg;
} App;

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);                    // reserve BG3 (force-blank)
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
}

int main(void) {
  static App a;
  app_init(&a);

  // Title card (BG2). Run the VM behind it: corpus_result = the path CRC (== host oracle == 0x4007), and
  // a->segs gets the line segments the turtle traced (recording does not change the CRC).
  static TitleLayer title;
  title_begin16(&a.screen, &title, "BYTECODE VM", "TURTLE");
  corpus_result = vm_run(VM_PROG, VM_PROG_LEN, a.segs, VM_MAX_SEG, &a.nseg);
  title_end(&a.screen, &title, 110);
  a.screen.bright = INIDISP_ON; a.screen.btgt = INIDISP_ON;          // full brightness from frame 1

  // Replay the recorded path a few segments per frame, so the turtle is seen drawing the rosette.
  uint16_t drawn = 0;
  for (;;) {
    for (uint8_t k = 0; k < SEGS_PER_FRAME && drawn < a.nseg; k++, drawn++) {
      Seg s = a.segs[drawn];
      canvas_line(&a.canvas, (int16_t)s.x0, (int16_t)s.y0, (int16_t)s.x1, (int16_t)s.y1, s.col);
    }
    display_frame(&a.screen);
  }
}
