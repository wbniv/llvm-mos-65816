#include <snes.h>
#include <stdint.h>

#include "mode7.h"
#include "snesgfx/m7title.h"
#include "snes-video-codec.h"
#include "snes-video-dma.h"
#include "video_hud.h"
#include <snes-video-reel-assets.h>

#define STAGE_ADDRESS 0x2000u
#ifndef VIDEO_REEL_VBLANKS_PER_FRAME
#define VIDEO_REEL_VBLANKS_PER_FRAME 2u
#endif

volatile uint8_t video_reel_result;
volatile uint16_t video_reel_frame;
volatile uint16_t video_reel_decoded;
volatile uint32_t video_reel_presented_total;
volatile uint16_t video_reel_crc_failures;
volatile uint16_t video_reel_deadline_slips;
volatile uint16_t video_reel_last_crc;
volatile uint8_t video_reel_loop_gate;
volatile uint32_t video_reel_vblanks;

/* SVX2's delta spans advance source and destination together. Replacement
   spans overwrite bytes that no later span can reference, so one framebuffer
   is intentionally both previous and output. VRAM retains the visible frame. */
static uint8_t framebuffer[SVC_FRAME_SIZE];
static uint8_t blank_tile = 70u;
static uint8_t blank_pixels[64];
#ifdef VIDEO_REEL_SECOND_PALETTE
static uint8_t active_palette_first[448];
static uint8_t active_palette_second[448];
#endif
static uint16_t fps_presented_sample;
static uint16_t fps_vblank_sample;
static volatile uint16_t fps_tenths;
static uint8_t dashboard_frame_tick;
static uint8_t dashboard_seconds;
static uint8_t dashboard_minutes;
static char dashboard_fps[5] = "00.0";

static uint8_t is_keyframe(uint16_t frame) {
#ifdef VIDEO_REEL_SECOND_START
  return frame == 0u || frame == VIDEO_REEL_SECOND_START;
#else
  return frame == 0u;
#endif
}

static char *decimal(char *out, uint16_t value, uint8_t width) {
  char digits[5];
  uint8_t used = 0u;
  do { digits[used++] = (char)('0' + value % 10u); value /= 10u; } while (value);
  while (width > used) { *out++ = '0'; --width; }
  while (used) *out++ = digits[--used];
  return out;
}

static void update_dashboard_fields(void) {
  char line[33];
  char *p = line;
  p = decimal(p, dashboard_minutes, 2u); *p++ = ':';
  p = decimal(p, dashboard_seconds, 2u);
  *p = 0;
  video_hud_text(26u, 6u, line);
  video_hud_text(26u, 27u, dashboard_fps);
  if (video_reel_result != 0u && video_reel_result != 0xffu)
    video_hud_text(25u, 25u, "ERROR  ");
  else if (video_reel_deadline_slips)
    video_hud_text(25u, 25u, "SLIP   ");
}

static void dashboard_presented(void) {
  uint16_t now_vblank = (uint16_t)video_reel_vblanks;
  uint16_t dv = (uint16_t)(now_vblank - fps_vblank_sample);
  if (++dashboard_frame_tick == 30u) {
    dashboard_frame_tick = 0u;
    if (dashboard_minutes != 99u || dashboard_seconds != 59u) {
      if (++dashboard_seconds == 60u) {
        dashboard_seconds = 0u;
        ++dashboard_minutes;
      }
    }
  }
  if (dv >= 60u) {
    uint16_t now_presented = (uint16_t)video_reel_presented_total;
    uint16_t dp = (uint16_t)(now_presented - fps_presented_sample);
    uint16_t measured = (uint16_t)((dp * 601u + dv / 2u) / dv);
    fps_tenths = measured;
    dashboard_fps[0] = (char)('0' + measured / 100u);
    measured %= 100u;
    dashboard_fps[1] = (char)('0' + measured / 10u);
    dashboard_fps[3] = (char)('0' + measured % 10u);
    fps_presented_sample = now_presented;
    fps_vblank_sample = now_vblank;
  }
  update_dashboard_fields();
}

static void stop(uint8_t result) {
  video_reel_result = result;
  REG_INIDISP = INIDISP_FORCE_BLANK;
  for (;;) __asm__ volatile("wai");
}

static uint16_t crc16(const uint8_t *data, uint16_t bytes) {
  uint16_t crc = 0xffffu;
  while (bytes--) {
    uint8_t bit = 8u;
    crc ^= (uint16_t)((uint16_t)*data++ << 8);
    while (bit--)
      crc = (crc & 0x8000u) ? (uint16_t)((crc << 1) ^ 0x1021u) : (uint16_t)(crc << 1);
  }
  return crc;
}

static uint8_t stage_frame(uint16_t frame) {
  SvcSnesDmaContext context = {3u, 1u};
#ifdef VIDEO_REEL_PACKED_FAR
  uint32_t offset = reel_packet_offsets[frame];
  uint16_t remaining = (uint16_t)(reel_packet_offsets[frame + 1u] - offset);
  uint16_t copied = 0u;
  while (remaining) {
    uint16_t address = (uint16_t)offset;
    uint16_t segment = (uint16_t)(0u - address);
    if (!segment || segment > remaining) segment = remaining;
    if (!svc_snes_dma_copy_segment(&context,
        (uint8_t)(VIDEO_REEL_HIROM_BASE_BANK + (uint8_t)(offset >> 16)), address,
        (uint8_t *)(uintptr_t)(STAGE_ADDRESS + copied), segment)) return 0u;
    offset += segment;
    copied = (uint16_t)(copied + segment);
    remaining = (uint16_t)(remaining - segment);
  }
  return 1u;
#else
  return svc_snes_dma_copy_segment(&context, 0x80u,
      (uint16_t)(uintptr_t)reel_packets[frame],
      (uint8_t *)(uintptr_t)STAGE_ADDRESS, reel_packet_sizes[frame]);
#endif
}

static void decode_frame(uint16_t frame) {
  if (!stage_frame(frame)) stop(1u);
  svx_decode_payload_wram_fast((uint16_t)(STAGE_ADDRESS + 9u), is_keyframe(frame),
                               framebuffer, framebuffer);
  ++video_reel_decoded;
}

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
  ++video_reel_presented_total;
}

#ifdef VIDEO_REEL_SECOND_PALETTE
static void prepare_palettes(void) {
  uint16_t i;
  for (i = 0; i != 448u; ++i) {
    active_palette_first[i] = reel_palette[i];
    active_palette_second[i] = reel_palette_second[i];
  }
}

static void upload_palette(uint8_t second) {
  REG_HDMAEN = 0u;
  REG_CGADD = 0u;
  REG_DMAP3 = 0u; REG_BBAD3 = 0x22u;
  if (second) {
    REG_A1T3L = (uint8_t)(uintptr_t)active_palette_second;
    REG_A1T3H = (uint8_t)((uint16_t)(uintptr_t)active_palette_second >> 8);
  } else {
    REG_A1T3L = (uint8_t)(uintptr_t)active_palette_first;
    REG_A1T3H = (uint8_t)((uint16_t)(uintptr_t)active_palette_first >> 8);
  }
  REG_A1B3 = 0u; REG_DAS3L = 0xc0u; REG_DAS3H = 0x01u;
  REG_MDMAEN = 8u;
  video_hud_arm();
}
#endif

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
#ifdef VIDEO_REEL_SECOND_PALETTE
  prepare_palettes();
#endif
  m7_set_matrix(0x0050, 0, 0, 0x004bu);
  m7_set_center(0, 0);
  m7_set_scroll(0, 0);
  video_hud_begin();
  video_hud_text(25u, 1u, "SVX2 VIDEO");
  video_hud_text(25u, 28u, "PLAY");
  video_hud_text(26u, 1u, "TIME");
  video_hud_text(26u, 23u, "FPS");
}

static void wait_vblank_fresh(void) {
  (void)REG_RDNMI;
  snes_wait_vblank();
}

void video_reel_run(void) {
  uint16_t frame;
  uint16_t deadline;
  snes_ppu_reset_blank();
  video_reel_result = 0xffu;
  video_reel_loop_gate = 0xffu;
  video_reel_deadline_slips = 0u;

  /* Exercise the stream boundaries behind a short animated introduction. */
  m7splash_begin("FASTROM 30 FPS", "SVX2 VIDEO");

  /* Target proof: validate the exact embedded sequence and its keyframe reset
     behind the title before allowing video playback to begin. */
#if VIDEO_REEL_FRAME_COUNT <= 4u
  for (frame = 0; frame != VIDEO_REEL_FRAME_COUNT; ++frame) {
    decode_frame(frame);
    video_reel_last_crc = crc16(framebuffer, SVC_FRAME_SIZE);
    if (video_reel_last_crc != reel_frame_crcs[frame]) {
      ++video_reel_crc_failures;
      stop(2u);
    }
  }
#else
  /* Exhaustive round-trip and target CRC validation belongs to the build
     gate. Exercise both independent keyframes here without the bit-serial CRC
     so the title remains an introduction rather than a loading screen. */
  decode_frame(0u);
#ifdef VIDEO_REEL_SECOND_START
  decode_frame(VIDEO_REEL_SECOND_START);
#endif
#endif
  decode_frame(0u);
#if VIDEO_REEL_FRAME_COUNT <= 4u
  if (crc16(framebuffer, SVC_FRAME_SIZE) != reel_frame_crcs[0]) {
    ++video_reel_crc_failures;
    stop(3u);
  }
#endif
  m7splash_end(30u);

  setup_display();
  REG_NMITIMEN = NMITIMEN_NMI;
  wait_vblank_fresh();
  present_frame();
  deadline = (uint16_t)video_reel_vblanks + VIDEO_REEL_VBLANKS_PER_FRAME;
  video_reel_frame = 0u;
  video_reel_result = 0u;
  fps_presented_sample = (uint16_t)video_reel_presented_total;
  fps_vblank_sample = (uint16_t)video_reel_vblanks;
  fps_tenths = 0u;
  dashboard_frame_tick = 1u;
  dashboard_seconds = 0u;
  dashboard_minutes = 0u;
  update_dashboard_fields();
  m7_show();

  for (;;) {
    uint8_t palette_cut;
    frame = (uint16_t)(video_reel_frame + 1u);
    if (frame == VIDEO_REEL_FRAME_COUNT) frame = 0u;
#ifdef VIDEO_REEL_SECOND_PALETTE
    palette_cut = frame == VIDEO_REEL_SECOND_START || frame == 0u;
#else
    palette_cut = 0u;
#endif
    decode_frame(frame);
    while ((int16_t)((uint16_t)video_reel_vblanks - deadline) < 0)
      __asm__ volatile("wai");
    if ((uint16_t)video_reel_vblanks != deadline) {
      video_reel_deadline_slips += (uint16_t)video_reel_vblanks - deadline;
      /* A missed VBlank is no longer a safe VRAM window. Resynchronize on the
         next NMI and resume the requested interval from there. */
      deadline = (uint16_t)video_reel_vblanks + 1u;
      while ((uint16_t)video_reel_vblanks != deadline) __asm__ volatile("wai");
    }
#ifdef VIDEO_REEL_SECOND_PALETTE
    if (palette_cut) {
      upload_palette(frame == VIDEO_REEL_SECOND_START);
    }
#endif
    present_frame();
    dashboard_presented();
    video_reel_frame = frame;
    deadline = (uint16_t)(deadline + VIDEO_REEL_VBLANKS_PER_FRAME);
    if (frame == 0u && video_reel_loop_gate != 0u) {
      static uint8_t loops;
      if (++loops == 2u) video_reel_loop_gate = 0u;
    }
  }
}

extern void video_reel_enter_fast(void);

int main(void) {
  REG_MEMSEL = MEMSEL_FASTROM;
  video_reel_enter_fast();
  return 0;
}
