#include <snes.h>
#include <stdint.h>
#include "../65816/lzss.h"
#include "snes-video-codec.h"
#include "snes-video-dma.h"
#include "snes-video-stream.h"
#include "snes-video-bench-assets.h"
#if defined(VIDEO_BENCH_VISIBLE)
#include "mode7.h"
#endif

volatile uint8_t corpus_result;
volatile uint32_t video_bench_iters;
static uint8_t output[SVC_FRAME_SIZE];

#if defined(VIDEO_BENCH_VISIBLE)
static uint8_t blank_tile = 70u;
static uint8_t blank_pixels[64];

static void show_decoded_frame(void) {
  uint16_t i;
#if !defined(VIDEO_BENCH_HAS_PALETTE)
#error "VIDEO_BENCH_VISIBLE requires a generated palette"
#endif
  m7_begin();
  /* Tile 70 is outside the 70-tile image and uses reserved palette index 224,
     giving the proof ROM an unmistakable green surround. */
  for (i = 0; i != 64u; ++i) blank_pixels[i] = 224u;
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = 70u * 64u;
  for (i = 0; i != 64u; ++i) REG_VMDATAH = blank_pixels[i];
  m7_tilemap_clear(0u, (uint16_t)(uintptr_t)&blank_tile, M7_TILEMAP_WORDS);
  m7_tilemap_identity(10u, 7u);
  REG_CGADD = 0u;
  for (i = 0; i != 448u; ++i) REG_CGDATA = bench_palette[i];
  REG_CGADD = 224u;
  REG_CGDATA = 0xe0u; /* BGR555 $03E0: bright green. */
  REG_CGDATA = 0x03u;
  /* Exact full-screen mapping: 80/256 horizontally and 56/224 vertically. */
  m7_set_matrix(0x0050, 0, 0, 0x0040);
  m7_set_center(0, 0);
  m7_set_scroll(0, 0);
  m7_show();
}
#endif

#if defined(VIDEO_BENCH_PIPELINE)
volatile uint8_t video_bench_stage_result;
static uint8_t stage_packet(void) {
  SvcRomSegment segment;
  SvcSegmentCursor cursor;
  SvcSnesDmaContext dma_context = {3u, 1u};
#if defined(VIDEO_BENCH_FASTROM)
  segment.bank = 0x80u;
#else
  segment.bank = 0u;
#endif
  segment.address = (uint16_t)(uintptr_t)bench_packet;
  segment.bytes = VIDEO_BENCH_PACKET_SIZE;
  video_bench_stage_result = svc_segment_cursor_init(
      &cursor, &segment, 1u, VIDEO_BENCH_PACKET_SIZE,
      svc_snes_dma_copy_segment, &dma_context);
  if (video_bench_stage_result != SVC_OK)
    return 0;
  /* Stage the complete packet into otherwise-unused high WRAM at $7F:2000. */
  video_bench_stage_result = svc_segment_cursor_read(
      &cursor, (uint8_t *)(uintptr_t)0x2000u, VIDEO_BENCH_PACKET_SIZE);
  return video_bench_stage_result == SVC_OK;
}

static void present_frame(void) {
  REG_VMAIN = VMAIN_INC_HIGH_1;
  REG_VMADD = 0u;
  REG_DMAP0 = 0u; /* A->B, increment source, one-register write pattern. */
  REG_BBAD0 = 0x19u;
  REG_A1T0L = (uint8_t)(uintptr_t)output;
  REG_A1T0H = (uint8_t)((uint16_t)(uintptr_t)output >> 8);
  REG_A1B0 = 0u;
  REG_DAS0L = (uint8_t)SVC_FRAME_SIZE;
  REG_DAS0H = (uint8_t)(SVC_FRAME_SIZE >> 8);
  REG_MDMAEN = 1u;
}
#endif

typedef struct { const uint8_t *data; uint16_t position, size; } MemoryInput;
static uint8_t read_byte(void *opaque, uint8_t *value) {
  MemoryInput *input = (MemoryInput *)opaque;
  if (input->position == input->size) return 0;
  *value = input->data[input->position++];
  return 1;
}

static uint8_t decode_once(void) {
#if defined(VIDEO_BENCH_PIPELINE)
  if (!stage_packet()) return 0;
#endif
#if defined(VIDEO_BENCH_CODEC_RAW)
  svc_copy_frame_fast(bench_packet, output);
  goto decoded;
#elif defined(VIDEO_BENCH_CODEC_LZSS)
  if (lzss_decode(bench_packet, VIDEO_BENCH_PACKET_SIZE, output, SVC_FRAME_SIZE) != SVC_FRAME_SIZE)
    return 0;
  goto decoded;
#else
  MemoryInput memory = {bench_packet, 0, VIDEO_BENCH_PACKET_SIZE};
  SvcInput input = {read_byte, &memory, VIDEO_BENCH_PACKET_SIZE};
  uint16_t crc;
#if defined(VIDEO_BENCH_CODEC_SVX)
#if defined(VIDEO_BENCH_PIPELINE)
  svx_decode_payload_wram_fast(0x2009u, bench_packet[4] & 1u,
                               VIDEO_BENCH_PREVIOUS, output);
#else
  svx_decode_payload_fast(bench_packet + 9u, bench_packet[4] & 1u,
                          VIDEO_BENCH_PREVIOUS, output);
#endif
  goto decoded;
#else
  if (svc_decode_frame(&input, VIDEO_BENCH_PREVIOUS, output, &crc) != SVC_OK) return 0;
  goto decoded;
#endif
#endif
decoded:
#if defined(VIDEO_BENCH_PIPELINE)
  present_frame();
#endif
  return 1u;
}

void video_bench_run(void) {
  uint16_t i;
#if defined(VIDEO_BENCH_VISIBLE)
  snes_ppu_reset_blank();
#endif
  corpus_result = 0xffu;
  video_bench_iters = 0;
  if (!decode_once()) { corpus_result = 1u; for (;;) __asm__ volatile("wai"); }
  for (i = 0; i != SVC_FRAME_SIZE; ++i)
    if (output[i] != bench_expected[i]) { corpus_result = 2u; for (;;) __asm__ volatile("wai"); }
#if defined(VIDEO_BENCH_VISIBLE)
  show_decoded_frame();
#endif
  corpus_result = 0u;
#if defined(VIDEO_BENCH_VISIBLE)
  /* This proof ROM holds the verified frame. The throughput build remains
     force-blanked because its tight loop intentionally is not VBlank-paced. */
  for (;;) __asm__ volatile("wai");
#endif
  for (;;) {
    if (!decode_once()) { corpus_result = 3u; for (;;) __asm__ volatile("wai"); }
    ++video_bench_iters;
  }
}

#if defined(VIDEO_BENCH_FASTROM)
extern void video_bench_enter_fast(void);
#endif

int main(void) {
#if defined(VIDEO_BENCH_FASTROM)
  /* FastROM requires both MEMSEL=1 and instruction fetches from banks $80+.
     The assembly trampoline JMLs to bank $80's mirror of video_bench_run. */
  REG_MEMSEL = MEMSEL_FASTROM;
  video_bench_enter_fast();
#else
  video_bench_run();
#endif
  return 0;
}
