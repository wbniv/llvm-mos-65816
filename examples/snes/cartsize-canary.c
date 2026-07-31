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

// --- reset/progress instrumentation (diagnosing the unstable backdrop) -------
// In .noinit so crt0 does NOT clear them: they survive a CPU reset, which is
// exactly what makes them able to detect one. `boot_magic` distinguishes a cold
// power-on (random/zero WRAM) from a re-entry into main().
__attribute__((section(".noinit"))) volatile uint16_t boot_magic;
__attribute__((section(".noinit"))) volatile uint16_t boot_count;
__attribute__((section(".noinit"))) volatile uint16_t progress;
#define BOOT_MAGIC 0xC0DEu

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
// mirror and span read the modelled byte; RED = at least one did not.
//
// Two real bugs were fixed getting here, and one red herring resolved:
//
//   1. Layers were never disabled. This ROM uploads no tiles, so whatever the
//      PPU still had enabled composited uninitialised VRAM over the backdrop --
//      the tan-and-green tile field the first screenshots showed.
//   2. CGRAM was written during active display. It is only writable in v-blank
//      or force-blank (the repo's standing rule), so the palette landed
//      half-applied and the picture came out split.
//   3. RED HERRING: the picture still differed per capture frame afterwards.
//      That is NOT this ROM. jgxcheck dumps whatever is in its video buffer
//      after N Bsnes::run() calls, which for a ROM holding a static picture can
//      be a stale or partially rendered frame. examples/snes/hello.c -- 25
//      lines, known good, its published page solid green -- shows the same
//      thing: green at 700 frames, mixed at 1100, 100% black at 1800. A browser
//      renders continuously and shows a steady picture, which is why nobody had
//      noticed. Do not "fix" a ROM against a single jgxcheck screenshot.
//
// The authoritative verdict remains the WRAM pair `canary_status` /
// `corpus_result`, which both emulator gates assert directly; the backdrop is
// its human-visible echo.
//
// A richer BG1 2bpp text readout (label, expected vs got oracle, PASS/FAIL
// banner) is still worth having and should reuse the snesgfx
// Scene/Display/VramAlloc path rather than hand-rolled registers.
// Wait for the start of v-blank WITHOUT needing NMI enabled (this ROM never
// enables NMITIMEN, so snes_wait_vblank()'s RDNMI flag would never latch):
// poll HVBJOY down to active display, then up into the next v-blank.
static void wait_vblank_poll(void) {
  while (REG_HVBJOY & HVBJOY_VBLANK) {
  }
  while (!(REG_HVBJOY & HVBJOY_VBLANK)) {
  }
}

// Paint the backdrop. CGRAM is only writable during force-blank or v-blank --
// the repo's standing rule -- and this call happens long after boot released
// force-blank, so it MUST sync to v-blank first. Writing it during active
// display is what left the picture half one colour and half another.
static void paint(uint16_t bg) {
  wait_vblank_poll();
  // Disable every layer. This ROM uploads no tiles, so anything the PPU still
  // has enabled composites uninitialised VRAM over the backdrop -- which is
  // what the tan/green tile field was. Never rely on a register's power-on
  // value when you depend on it.
  REG_TM = 0;  // main screen: no BG, no OBJ
  REG_TS = 0;  // sub screen likewise
  REG_BGMODE = 0;
  REG_CGADD = 0;
  REG_CGDATA = bg & 0xFF;
  REG_CGDATA = bg >> 8;
  REG_INIDISP = INIDISP_ON;
}

// Called before the ~15 s of canary work so the screen is never undefined: the
// display is a solid "running" blue until the verdict replaces it. Without this
// the ROM sat force-blanked (black) for the whole run and the gate's capture
// landed on the exact frame the verdict appeared.
static void screen_running(void) {
  // Still inside the boot force-blank window here, so no v-blank sync is needed
  // -- but paint() does it anyway and costs one frame, which is irrelevant
  // against ~10 s of canary work.
  paint(SNES_RGB(2, 4, 14));
}

int main(void) {
  uint16_t h = 0;
  uint16_t status = 0;

  // Reset detector: if main() is re-entered, boot_magic already holds the magic
  // and boot_count climbs. progress records how far the previous pass got.
  if (boot_magic != BOOT_MAGIC) {
    boot_magic = BOOT_MAGIC;
    boot_count = 0;
  }
  boot_count = (uint16_t)(boot_count + 1u);
  progress = 1;

  screen_running();

  // 1) Canary bytes: first/last byte of every decoded window, every physical
  //    device, each 1 MiB divider, and the 4 MiB device boundary.
  for (uint8_t i = 0; i < CANARY_COUNT; i++) {
    uint8_t got = far_read(canary_addr[i]);
    if (got != canary_want[i] && !status)
      status = (uint16_t)(ST_CANARY | i);
    h = fold1(h, got);
  }

  progress = 2;

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

  progress = 3;

  // 3) Spans crossing one bank, several banks, and the physical device boundary.
  for (uint8_t i = 0; i < SPAN_COUNT; i++) {
    uint16_t got = fold_span(span_first[i], span_nseg[i]);
    if (got != span_want[i] && !status)
      status = (uint16_t)(ST_SPAN | i);
    h = fold1(h, (uint8_t)(got & 0xFF));
    h = fold1(h, (uint8_t)(got >> 8));
  }

  progress = 4;

  canary_status = status;
  corpus_result = h;

  progress = 5;
  uint16_t verdict = ((status == 0) && (h == CANARY_ORACLE)) ? SNES_RGB(0, 31, 6)
                                                             : SNES_RGB(31, 0, 0);
  progress = 6;

  // Re-assert the verdict every frame rather than painting once and idling: it
  // keeps the picture correct after any stray register write, matches how every
  // other demo here drives the screen (a per-frame display loop), and gives the
  // idle loop a side effect so C11 forward-progress cannot remove it. It does
  // NOT make jgxcheck's single-frame dump deterministic -- see note 3 above,
  // that is a harness property, not something a ROM can fix.
  for (;;) {
    paint(verdict);
    corpus_result = h;
  }
  return 0;
}
