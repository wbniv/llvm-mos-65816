// cartsize-canary.c — the cartridge-size test ROM.
//
// One program, three cartridges: HiROM 4 MiB, ExHiROM 6 MiB, ExHiROM 8 MiB. It
// boots, reads a canary byte from the first and last byte of every decoded CPU
// window and every physical mask ROM, proves each intended mirror reads the same
// byte as its canonical window, and folds byte spans that cross one CPU bank,
// several CPU banks, and — on ExHiROM — the physical 4 MiB device boundary.
// The verdict goes to WRAM for the emulator gates and to the screen backdrop.
//
// Everything it compares against is generated from tools/snes_cartmap.py, the
// authoritative address model, by tools/snes-cartcanary.py: the canary
// addresses, the segment lists, the expected bytes and folds, and the final
// oracle. This file knows no addresses of its own.
//
// Why the spans need a SEGMENT LIST rather than a pointer walk: the SNES DMA
// source address (and, here, the CPU cursor we model on it) increments only its
// 16-bit half — it does not carry into the bank byte. And on ExHiROM the file is
// not even monotonic in CPU space: file $3FFFFF is $FF:FFFF and the very next
// byte, file $400000, is $40:0000. A logical object crossing that boundary can
// only be consumed as an ordered list of bank-bounded segments, which is exactly
// what the model emits and what fold_span() below walks.
//
// +mos-a16 only: a runtime far pointer is a 32-bit value, and 32-bit value
// legalization exists only under +mos-a16 (same reason as examples/65816/far_indir.c).
//
// Built + gated by dev/cartsize-canary.sh (host: dev/run.sh cartsize-canary).
// Plan: docs/plans/2026-07-30-exhirom-video-boundary-test.md, Phase 0 + Phase 1.

#include <snes.h>
#include <stdint.h>


#define FAR __attribute__((address_space(2)))

// Generated: canary_addr/want, probe_canonical/mirror/want, seg_addr/len,
// span_first/nseg/want, CANARY_ORACLE, CANARY_LABEL.
#include "cartsize-canary-data.h"

// Sampled from the $7E WRAM mirror by MAME's smoke.lua and by build/jgxcheck.
volatile uint16_t corpus_result;
// 0 = every check passed; otherwise a code naming the FIRST check that failed.
volatile uint16_t canary_status;

#define ST_CANARY 0x0100u
#define ST_PROBE_CANON 0x0200u
#define ST_PROBE_MIRROR 0x0300u
#define ST_SPAN 0x0400u

// Launders a 24-bit address into a runtime value so the dereference cannot
// constant-fold back to absolute-long; it must stay an indirect-long `lda [dp]`,
// which is the addressing mode a real far cursor uses.
static volatile unsigned long opaque_addr;

static uint8_t far_read(unsigned long a) {
  opaque_addr = a;
  unsigned long v = opaque_addr;
  return *(FAR const uint8_t *)v;
}

// Rotate left 1, then add. The add's carry makes the fold non-linear over
// GF(2): an XOR fold collapses to zero over the padding pattern's
// power-of-two-aligned runs, and collapses identically for a WRONG bank, so it
// would have proved nothing. Kept in lockstep with fold() in
// tools/snes-cartcanary.py.
static uint16_t fold1(uint16_t h, uint8_t b) {
  return (uint16_t)(((h << 1) | (h >> 15)) + b);
}

// Fold one span by walking its ordered, bank-bounded segments. The bank byte is
// re-established from the segment descriptor at every segment start and is never
// derived by incrementing across a boundary.
static uint16_t fold_span(uint8_t first, uint8_t nseg) {
  uint16_t h = 0;
  for (uint8_t s = 0; s < nseg; s++) {
    opaque_addr = seg_addr[first + s];
    unsigned long base = opaque_addr;  // runtime => genuine far cursor
    uint16_t n = seg_len[first + s];
    for (uint16_t i = 0; i < n; i++)
      h = fold1(h, *(FAR const uint8_t *)(base + i));
  }
  return h;
}

// ---------------------------------------------------------------- display
//
// The visible verdict: a full-screen backdrop colour. GREEN = every canary,
// mirror and span read the modelled byte; RED = at least one did not. This is
// the one PPU path the repo has a known-good reference for
// (examples/snes/hello.c).
//
// UNFINISHED: a richer BG1 2bpp text readout (label, expected vs got oracle,
// status word, PASS/FAIL banner) was written against hand-rolled
// BG1SC/BG12NBA/BGMODE setup and rendered as noise, then as solid bars, then as
// nothing. Every snesgfx demo here reaches the screen through the
// Scene/Display/VramAlloc machinery rather than raw registers, and that is the
// path a text readout should reuse -- not a fourth hand-rolled attempt. The
// authoritative verdict is the WRAM pair `canary_status` / `corpus_result`,
// which both emulator gates assert; the backdrop is its human-visible echo.
static void screen(uint8_t ok) {
  uint16_t bg = ok ? SNES_RGB(0, 31, 6) : SNES_RGB(31, 0, 0);
  REG_CGADD = 0;
  REG_CGDATA = bg & 0xFF;
  REG_CGDATA = bg >> 8;
  REG_INIDISP = INIDISP_ON;
}

int main(void) {
  uint16_t h = 0;
  uint16_t status = 0;

  // 1) Canary bytes: first/last byte of every decoded window, every physical
  //    device, each 1 MiB divider, and the 4 MiB device boundary.
  for (uint8_t i = 0; i < CANARY_COUNT; i++) {
    uint8_t got = far_read(canary_addr[i]);
    if (got != canary_want[i] && !status)
      status = (uint16_t)(ST_CANARY | i);
    h = fold1(h, got);
  }

  // 2) Mirror probes: the canonical window and its accepted mirror must return
  //    the SAME byte. The padding pattern is a function of the full 24-bit file
  //    offset, so a decoder that folded these to different offsets is caught.
  for (uint8_t i = 0; i < PROBE_COUNT; i++) {
    uint8_t a = far_read(probe_canonical[i]);
    uint8_t b = far_read(probe_mirror[i]);
    if (a != probe_want[i] && !status)
      status = (uint16_t)(ST_PROBE_CANON | i);
    if (b != probe_want[i] && !status)
      status = (uint16_t)(ST_PROBE_MIRROR | i);
    h = fold1(h, a);
    h = fold1(h, b);
  }

  // 3) Spans crossing one bank, several banks, and the physical device boundary.
  for (uint8_t i = 0; i < SPAN_COUNT; i++) {
    uint16_t got = fold_span(span_first[i], span_nseg[i]);
    if (got != span_want[i] && !status)
      status = (uint16_t)(ST_SPAN | i);
    h = fold1(h, (uint8_t)(got & 0xFF));
    h = fold1(h, (uint8_t)(got >> 8));
  }

  canary_status = status;
  corpus_result = h;

  screen((status == 0) && (h == CANARY_ORACLE));

  // The idle loop has a side effect on purpose: an empty `for (;;) {}` is
  // removable under C11's forward-progress rule, so main() could fall out of
  // crt0. Re-storing the volatile result keeps it, per examples/snes/hello.c.
  // (173 example files here still use the bare empty form.)
  //
  // NOTE: this was tried as the fix for the unstable backdrop described above
  // and did NOT resolve it -- the captured frame still differs per
  // configuration and per frame count. It is kept because it is correct
  // regardless; the display defect's real cause is still unknown.
  for (;;) {
    corpus_result = h;
  }
  return 0;
}
