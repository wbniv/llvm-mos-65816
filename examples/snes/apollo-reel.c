/* Apollo 11 daylight launch — the SVX2 codec's hardest realistic input.
 *
 * A sibling of snes-video-reel.c, not a modification of it. The reel plays
 * Artemis I: a night launch whose mostly-black frames an H.264 derivative had
 * already smoothed. This plays 16 mm KSC tracking-camera film — daylight, heavy
 * grain, bright continuous exhaust against sky — which costs the codec ~22
 * ratio points under Floyd (57.0% -> 78.9%).
 *
 * The corpus is sampled at 29.97 fps from a 59.9401 fps master and presented one
 * frame per VBlank, so playback is true 59.94 fps at 2x real-time speed: 20.02 s
 * of ascent in 10.01 s, 600 frames.
 *
 * This ROM exists to be measured. Its cadence window is reported, never gated:
 * a throughput regression on this content is the finding, not a failure.
 * Correctness is gated, and gated hard — the whole 600-frame loop is checked
 * against the host encoder's oracle before playback is allowed to start.
 */
#include <snes.h>
#include <stdint.h>

#include "mode7.h"
#include "snesgfx/m7title.h"
#include "snes-video-codec.h"
#include "snes-video-dma.h"
#include "video_hud.h"
#include <apollo-reel-assets.h>

#define STAGE_ADDRESS 0x2000u

#ifndef APOLLO_REEL_VBLANKS_PER_FRAME
#define APOLLO_REEL_VBLANKS_PER_FRAME 2u
#endif
#define APOLLO_REEL_SOURCE_FPS (60u / APOLLO_REEL_VBLANKS_PER_FRAME)

/* The cadence metric the 60 fps work established, so this content is directly
   comparable to the Artemis figures: presented frames per 600 VBlanks. */
#ifndef APOLLO_REEL_WINDOW_VBLANKS
#define APOLLO_REEL_WINDOW_VBLANKS 600u
#endif

#if !defined(VIDEO_REEL_PACKED_FAR) || !defined(VIDEO_REEL_LOOP_DELTA)
#error "apollo-reel requires a --packed-far asset header with a loop delta"
#endif
#if !defined(VIDEO_REEL_FRAME_CHECKS)
#error "apollo-reel requires --frame-checks; the whole-loop gate is not optional"
#endif

/* Correctness state. video_reel_* names are deliberately not reused: both ROMs
   can then be linked or symbol-dumped in the same session without collision. */
volatile uint8_t apollo_reel_result;
volatile uint8_t apollo_reel_corpus_result;
volatile uint16_t apollo_reel_check_failures;
volatile uint16_t apollo_reel_failing_frame;
volatile uint32_t apollo_reel_health;

/* Playback and measurement state. */
volatile uint32_t apollo_reel_vblanks;
volatile uint16_t apollo_reel_frame;
volatile uint16_t apollo_reel_decoded;
volatile uint32_t apollo_reel_presented_total;
volatile uint16_t apollo_reel_deadline_slips;
volatile uint16_t apollo_reel_window_presented;
volatile uint16_t apollo_reel_window_vblanks;
volatile uint8_t apollo_reel_window_state;
volatile uint8_t apollo_reel_loop_gate;

/* SVX2 delta spans advance source and destination together, and replacement
   spans overwrite bytes no later span can reference, so one framebuffer is
   intentionally both previous and output. VRAM retains the visible frame. */
static uint8_t framebuffer[SVC_FRAME_SIZE];
static uint8_t blank_tile = 70u;
static uint8_t blank_pixels[64];

static uint16_t window_base_presented;
static uint16_t window_start_vblank;
static uint16_t fps_presented_sample;
static uint16_t fps_vblank_sample;
static char dashboard_fps[5] = "00.0";
static uint8_t dashboard_frame_tick;
static uint8_t dashboard_seconds;

static void stop(uint8_t result) {
  apollo_reel_result = result;
  REG_INIDISP = INIDISP_FORCE_BLANK;
  for (;;) __asm__ volatile("wai");
}

#ifdef APOLLO_REEL_SELFTEST
/* Mirrors frame_check() in tools/snes-video-reel-assets.py byte for byte. */
static uint16_t frame_check(const uint8_t *frame) {
  uint16_t a = 0u, b = 0u, i;
  for (i = 0; i != SVC_FRAME_SIZE; ++i) {
    a = (uint16_t)(a + frame[i]);
    b = (uint16_t)(b + a);
  }
  return (uint16_t)(a ^ b);
}
#endif

static char *decimal(char *out, uint16_t value, uint8_t width) {
  char digits[5];
  uint8_t used = 0u;
  do { digits[used++] = (char)('0' + value % 10u); value /= 10u; } while (value);
  while (width > used) { *out++ = '0'; --width; }
  while (used) *out++ = digits[--used];
  return out;
}

static uint8_t stream_bank(uint32_t offset) {
  return (uint8_t)(VIDEO_REEL_HIROM_BASE_BANK + (uint8_t)(offset >> 16));
}

/* Copy one packed packet from ROM into high WRAM, splitting at A-bus bank
   boundaries. `segment` of zero means the transfer starts bank-aligned and
   65,536 bytes remain, which cannot be held in a uint16_t. */
static uint8_t stage_range(uint32_t offset, uint16_t remaining) {
  SvcSnesDmaContext context = {3u, 1u};
  uint16_t copied = 0u;
  while (remaining) {
    uint16_t address = (uint16_t)offset;
    uint16_t segment = (uint16_t)(0u - address);
    if (!segment || segment > remaining) segment = remaining;
    if (!svc_snes_dma_copy_segment(&context, stream_bank(offset), address,
        (uint8_t *)(uintptr_t)(STAGE_ADDRESS + copied), segment)) return 0u;
    offset += segment;
    copied = (uint16_t)(copied + segment);
    remaining = (uint16_t)(remaining - segment);
  }
  return 1u;
}

static uint8_t stage_frame(uint16_t frame) {
  uint32_t offset = reel_packet_offsets[frame];
  return stage_range(offset, (uint16_t)(reel_packet_offsets[frame + 1u] - offset));
}

static uint8_t stage_loop_delta(void) {
  return stage_range(VIDEO_REEL_LOOP_PACKET_OFFSET, VIDEO_REEL_LOOP_PACKET_SIZE);
}

/* Only frame zero is independent in the sequential stream; the seek keyframe
   table is separate and is not used by straight-line playback. */
static void decode_frame(uint16_t frame) {
  if (!stage_frame(frame)) stop(1u);
  svx_decode_payload_wram_fast((uint16_t)(STAGE_ADDRESS + 9u), frame == 0u,
                               framebuffer, framebuffer);
  ++apollo_reel_decoded;
}

/* Wrapping to frame zero uses the loop delta against frame 599, so a running
   loop never re-pays for a keyframe. */
static void decode_sequential_frame(uint16_t frame) {
  if (frame == 0u) {
    if (!stage_loop_delta()) stop(1u);
    svx_decode_payload_wram_fast((uint16_t)(STAGE_ADDRESS + 9u), 0u,
                                 framebuffer, framebuffer);
    ++apollo_reel_decoded;
    return;
  }
  decode_frame(frame);
}

#ifdef APOLLO_REEL_SELFTEST
/* The whole-loop byte-correctness gate. Every one of the 600 frames is checked
   against the host encoder's oracle, so the complete delta chain is pinned --
   a frame-zero-only check would pass on a decoder that corrupted every delta.
   The final frame is additionally compared byte for byte, because a Fletcher
   check is a summary and the last link in the chain deserves the real thing. */
static void validate_loop(void) {
  uint16_t frame, i;
  for (frame = 0u; frame != VIDEO_REEL_FRAME_COUNT; ++frame) {
    decode_frame(frame);
    if (frame_check(framebuffer) != reel_frame_checks[frame]) {
      ++apollo_reel_check_failures;
      apollo_reel_failing_frame = frame;
      apollo_reel_corpus_result = 2u;
      stop(2u);
    }
  }
  for (i = 0u; i != SVC_FRAME_SIZE; ++i) {
    if (framebuffer[i] != reel_final_frame[i]) {
      apollo_reel_failing_frame = i;
      apollo_reel_corpus_result = 4u;
      stop(4u);
    }
  }
  /* Prove the loop closes too: the delta that takes frame 599 back to frame 0
     is the one packet straight-line playback depends on every lap. */
  decode_sequential_frame(0u);
  if (frame_check(framebuffer) != reel_frame_checks[0]) {
    ++apollo_reel_check_failures;
    apollo_reel_failing_frame = 0u;
    apollo_reel_corpus_result = 8u;
    stop(8u);
  }
  apollo_reel_corpus_result = 0u;
}
#endif

static void present_frame(void) {
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = 0u;
  REG_DMAP0 = 0u;
  REG_BBAD0 = 0x19u;
  REG_A1T0L = (uint8_t)(uintptr_t)framebuffer;
  REG_A1T0H = (uint8_t)((uint16_t)(uintptr_t)framebuffer >> 8);
  REG_A1B0 = 0u;
  REG_DAS0L = (uint8_t)SVC_FRAME_SIZE;
  REG_DAS0H = (uint8_t)(SVC_FRAME_SIZE >> 8);
  REG_MDMAEN = 1u;
  ++apollo_reel_presented_total;
}

static void dashboard_static(void) {
  video_hud_line(25u, "APOLLO 11 / KSC 16MM       PLAY ");
  video_hud_line(26u, " TIME                  FPS     ");
}

static void dashboard_update(uint8_t looped) {
  uint16_t now_vblank = (uint16_t)apollo_reel_vblanks;
  uint16_t dv = (uint16_t)(now_vblank - fps_vblank_sample);
  char line[8];
  char *p = line;
  if (looped) {
    dashboard_frame_tick = 0u;
    dashboard_seconds = 0u;
  } else if (++dashboard_frame_tick == APOLLO_REEL_SOURCE_FPS) {
    dashboard_frame_tick = 0u;
    if (dashboard_seconds != 99u) ++dashboard_seconds;
  }
  if (dv >= 60u) {
    uint16_t now_presented = (uint16_t)apollo_reel_presented_total;
    uint16_t dp = (uint16_t)(now_presented - fps_presented_sample);
    uint16_t measured = (uint16_t)((dp * 601u + dv / 2u) / dv);
    dashboard_fps[0] = (char)('0' + measured / 100u);
    measured %= 100u;
    dashboard_fps[1] = (char)('0' + measured / 10u);
    dashboard_fps[3] = (char)('0' + measured % 10u);
    fps_presented_sample = now_presented;
    fps_vblank_sample = now_vblank;
  }
  p = decimal(p, 0u, 2u); *p++ = ':';
  p = decimal(p, dashboard_seconds, 2u);
  *p = 0;
  video_hud_text(26u, 6u, line);
  video_hud_text(26u, 27u, dashboard_fps);
  if (apollo_reel_deadline_slips) video_hud_text(25u, 27u, "SLIP");
  video_hud_flush();
}

static void setup_display(void) {
  uint16_t i;
  m7_begin();
  for (i = 0; i != 64u; ++i) blank_pixels[i] = 0u;
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = 70u * 64u;
  for (i = 0; i != 64u; ++i) REG_VMDATAH = blank_pixels[i];
  m7_tilemap_clear(0u, (uint16_t)(uintptr_t)&blank_tile, M7_TILEMAP_WORDS);
  m7_tilemap_identity(10u, 7u);
  REG_CGADD = 0u;
  for (i = 0; i != 448u; ++i) REG_CGDATA = reel_palette[i];
  m7_set_matrix(0x0050, 0, 0, 0x004bu);
  m7_set_center(0, 0);
  m7_set_scroll(0, 0);
  video_hud_begin();
  dashboard_static();
  video_hud_flush();
}

static void wait_vblank_fresh(void) {
  (void)REG_RDNMI;
  snes_wait_vblank();
}

/* Count presents across a fixed VBlank window and latch the result. The actual
   elapsed VBlanks are latched alongside, because the window can only close on a
   presented frame and so overshoots the target by up to one frame interval.
   Reporting both keeps the published cadence honest rather than rounded. */
static void cadence_window(void) {
  if (apollo_reel_window_state == 0u) {
    window_start_vblank = (uint16_t)apollo_reel_vblanks;
    window_base_presented = (uint16_t)apollo_reel_presented_total;
    apollo_reel_window_state = 1u;
  } else if (apollo_reel_window_state == 1u) {
    uint16_t elapsed = (uint16_t)((uint16_t)apollo_reel_vblanks - window_start_vblank);
    if (elapsed >= APOLLO_REEL_WINDOW_VBLANKS) {
      apollo_reel_window_presented =
          (uint16_t)((uint16_t)apollo_reel_presented_total - window_base_presented);
      apollo_reel_window_vblanks = elapsed;
      apollo_reel_window_state = 2u;
    }
  }
}

void apollo_reel_run(void) {
  uint16_t frame;
  uint16_t deadline;

  snes_ppu_reset_blank();
  apollo_reel_result = 0xffu;
  apollo_reel_corpus_result = 0xffu;
  apollo_reel_health = 0xfffffffful;
  apollo_reel_loop_gate = 0xffu;
  apollo_reel_window_state = 0u;

#ifdef APOLLO_REEL_SELFTEST
  /* Whole-loop validation is a bit-serial sweep over 601 decoded frames and
     costs ~4,400 VBlanks (~73 s) with the screen force-blanked. That belongs to
     the build gate, NOT to the shipped cartridge: running it ahead of the title
     turns the boot into over a minute of black screen, which is exactly what
     snes-video-reel.c warns about ("...so the title remains an introduction
     rather than a loading screen"). dev/apollo-reel.sh builds this variant and
     gates it; the published ROM goes straight to the title. */
  validate_loop();
#endif

  m7splash_begin("DAYLIGHT LAUNCH", "APOLLO 11");
  m7splash_end(30u);

  /* Reset to the independent keyframe so playback starts from a known frame
     rather than inheriting whatever validation left behind. */
  decode_frame(0u);

  setup_display();
  REG_NMITIMEN = NMITIMEN_NMI;
  wait_vblank_fresh();
  present_frame();
  deadline = (uint16_t)apollo_reel_vblanks + APOLLO_REEL_VBLANKS_PER_FRAME;
  apollo_reel_frame = 0u;
  apollo_reel_result = 0u;
  /* apollo_reel_health is deliberately NOT cleared here. It stays 0xFFFFFFFF
     until two full playback loops have completed, so a gate that reads it is
     asserting "the loop ran twice cleanly", not merely "playback started". */
  fps_presented_sample = (uint16_t)apollo_reel_presented_total;
  fps_vblank_sample = (uint16_t)apollo_reel_vblanks;
  dashboard_frame_tick = 1u;
  m7_show();

  for (;;) {
    uint8_t looped;
    frame = (uint16_t)(apollo_reel_frame + 1u);
    looped = frame == VIDEO_REEL_FRAME_COUNT;
    if (looped) frame = 0u;

    decode_sequential_frame(frame);

    while ((int16_t)((uint16_t)apollo_reel_vblanks - deadline) < 0)
      __asm__ volatile("wai");
    if ((uint16_t)apollo_reel_vblanks != deadline) {
      /* A missed VBlank is no longer a safe VRAM window. Resynchronize on the
         next NMI and resume the requested interval from there. This is counted
         and reported, never gated: on this content a slip is the measurement. */
      apollo_reel_deadline_slips += (uint16_t)apollo_reel_vblanks - deadline;
      deadline = (uint16_t)apollo_reel_vblanks + 1u;
      while ((uint16_t)apollo_reel_vblanks != deadline) __asm__ volatile("wai");
    }

    apollo_reel_frame = frame;
    /* Upload the small dashboard first. The full 4,480-byte video DMA uses
       nearly the rest of the VBlank budget; HUD writes after it are too late on
       real timing and are intermittently ignored by the PPU. */
    dashboard_update(looped);
    present_frame();
    cadence_window();
    deadline = (uint16_t)(deadline + APOLLO_REEL_VBLANKS_PER_FRAME);

    if (frame == 0u && apollo_reel_loop_gate != 0u) {
      static uint8_t loops;
      if (++loops == 2u) {
        apollo_reel_loop_gate = 0u;
        /* corpus_result is deliberately NOT folded in: it is 0xFF in the
           published build, which never runs the boot validation. The gate
           asserts it separately on the -DAPOLLO_REEL_SELFTEST build. */
        apollo_reel_health = (uint32_t)apollo_reel_result |
            ((uint32_t)apollo_reel_check_failures << 8);
      }
    }
  }
}

#if defined(APOLLO_REEL_FASTROM)
extern void apollo_reel_enter_fast(void);
#endif

int main(void) {
#if defined(APOLLO_REEL_FASTROM)
  /* FastROM needs both MEMSEL=1 and instruction fetches from banks $80+; the
     trampoline JMLs to bank $80's mirror of apollo_reel_run. */
  REG_MEMSEL = MEMSEL_FASTROM;
  apollo_reel_enter_fast();
#else
  apollo_reel_run();
#endif
  return 0;
}
