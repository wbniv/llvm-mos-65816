#include <snes.h>
#include <stdint.h>

#include "mode7.h"
#include "snes-video-codec.h"
#include "snes-video-dma.h"
#include <snes-video-reel-assets.h>

#define STAGE_ADDRESS 0x2000u
#ifndef VIDEO_REEL_VBLANKS_PER_FRAME
#define VIDEO_REEL_VBLANKS_PER_FRAME 2u
#endif

volatile uint8_t video_reel_result;
volatile uint8_t video_reel_frame;
volatile uint16_t video_reel_decoded;
volatile uint16_t video_reel_presented;
volatile uint16_t video_reel_crc_failures;
volatile uint16_t video_reel_deadline_slips;
volatile uint16_t video_reel_last_crc;
volatile uint8_t video_reel_loop_gate;
volatile uint16_t video_reel_vblanks;

/* SVX2's delta spans advance source and destination together. Replacement
   spans overwrite bytes that no later span can reference, so one framebuffer
   is intentionally both previous and output. VRAM retains the visible frame. */
static uint8_t framebuffer[SVC_FRAME_SIZE];
static uint8_t blank_tile = 70u;
static uint8_t blank_pixels[64];

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

static uint8_t stage_frame(uint8_t frame) {
  SvcSnesDmaContext context = {3u, 1u};
  return svc_snes_dma_copy_segment(&context, 0x80u,
      (uint16_t)(uintptr_t)reel_packets[frame],
      (uint8_t *)(uintptr_t)STAGE_ADDRESS, reel_packet_sizes[frame]);
}

static void decode_frame(uint8_t frame) {
  if (!stage_frame(frame)) stop(1u);
  svx_decode_payload_wram_fast((uint16_t)(STAGE_ADDRESS + 9u), frame == 0u,
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
  ++video_reel_presented;
}

static void setup_display(void) {
  uint16_t i;
  m7_begin();
  for (i = 0; i != 64u; ++i) blank_pixels[i] = 224u;
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = 70u * 64u;
  for (i = 0; i != 64u; ++i) REG_VMDATAH = blank_pixels[i];
  m7_tilemap_clear(0u, (uint16_t)(uintptr_t)&blank_tile, M7_TILEMAP_WORDS);
  m7_tilemap_identity(10u, 7u);
  REG_CGADD = 0u;
  for (i = 0; i != 448u; ++i) REG_CGDATA = reel_palette[i];
  REG_CGADD = 224u;
  REG_CGDATA = 0xe0u;
  REG_CGDATA = 0x03u;
  m7_set_matrix(0x0050, 0, 0, 0x0040);
  m7_set_center(0, 0);
  m7_set_scroll(0, 0);
}

static void wait_vblank_fresh(void) {
  (void)REG_RDNMI;
  snes_wait_vblank();
}

void video_reel_run(void) {
  uint8_t frame;
  uint16_t deadline;
  snes_ppu_reset_blank();
  video_reel_result = 0xffu;
  video_reel_loop_gate = 0xffu;
  video_reel_deadline_slips = 0u;

  /* Force-blanked target proof: validate the exact embedded sequence and its
     keyframe reset before allowing any image to be shown. */
  for (frame = 0; frame != VIDEO_REEL_FRAME_COUNT; ++frame) {
    decode_frame(frame);
    video_reel_last_crc = crc16(framebuffer, SVC_FRAME_SIZE);
    if (video_reel_last_crc != reel_frame_crcs[frame]) {
      ++video_reel_crc_failures;
      stop(2u);
    }
  }
  decode_frame(0u);
  if (crc16(framebuffer, SVC_FRAME_SIZE) != reel_frame_crcs[0]) stop(3u);

  setup_display();
  REG_NMITIMEN = NMITIMEN_NMI;
  wait_vblank_fresh();
  present_frame();
  deadline = (uint16_t)(video_reel_vblanks + VIDEO_REEL_VBLANKS_PER_FRAME);
  video_reel_frame = 0u;
  video_reel_result = 0u;
  m7_show();

  for (;;) {
    frame = (uint8_t)(video_reel_frame + 1u);
    if (frame == VIDEO_REEL_FRAME_COUNT) frame = 0u;
    decode_frame(frame);
    while ((int16_t)(video_reel_vblanks - deadline) < 0)
      __asm__ volatile("wai");
    if (video_reel_vblanks != deadline) {
      video_reel_deadline_slips += (uint16_t)(video_reel_vblanks - deadline);
      /* A missed VBlank is no longer a safe VRAM window. Resynchronize on the
         next NMI and resume the requested interval from there. */
      deadline = (uint16_t)(video_reel_vblanks + 1u);
      while (video_reel_vblanks != deadline) __asm__ volatile("wai");
    }
    present_frame();
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
