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

#if defined(VIDEO_BENCH_STREAM)
/* Functional multi-packet refill. Packets live in the separately packed HiROM
   stream and are reached through a 32-bit offset table, so every frame pays the
   real table lookup, the A-bus 64 KiB bank split, and the ring bookkeeping.

   The ring is no-split by construction: svx_decode_payload_wram_asm walks its
   staged cursor with a 16-bit X and has no wrap handling, so a packet that would
   straddle VIDEO_BENCH_RING_END restarts at VIDEO_BENCH_RING_BASE instead. */
#define VIDEO_BENCH_RING_BASE 0x2000u
#define VIDEO_BENCH_RING_END 0xf000u

volatile uint8_t video_bench_stage_result;
/* Target-readable proof that the no-split wrap is actually taken, rather than
   the ring being a straight buffer that never reaches its end. */
volatile uint16_t video_bench_ring_wraps;
static uint16_t ring_write = VIDEO_BENCH_RING_BASE;

/* Returns the bank-$7F address the packet was staged at, or 0 on failure. */
static uint16_t stage_stream_frame(uint16_t frame) {
  SvcSnesDmaContext dma_context = {3u, 1u};
  uint32_t offset = bench_stream_offsets[frame];
  uint16_t remaining = (uint16_t)(bench_stream_offsets[frame + 1u] - offset);
  uint16_t start;
  uint16_t copied = 0u;
  if ((uint32_t)ring_write + remaining > VIDEO_BENCH_RING_END) {
    ring_write = VIDEO_BENCH_RING_BASE;
    ++video_bench_ring_wraps;
  }
  start = ring_write;
  while (remaining) {
    uint16_t address = (uint16_t)offset;
    /* Bytes left in this A-bus bank; 0 means the transfer starts bank-aligned
       and 65,536 bytes remain, which cannot be a uint16_t. */
    uint16_t segment = (uint16_t)(0u - address);
    if (!segment || segment > remaining) segment = remaining;
    if (!svc_snes_dma_copy_segment(&dma_context,
            (uint8_t)(VIDEO_BENCH_STREAM_BASE_BANK + (uint8_t)(offset >> 16)),
            address, (uint8_t *)(uintptr_t)(start + copied), segment)) {
      video_bench_stage_result = SVC_ERR_TRUNCATED;
      return 0u;
    }
    offset += segment;
    copied = (uint16_t)(copied + segment);
    remaining = (uint16_t)(remaining - segment);
  }
  ring_write = (uint16_t)(start + copied);
  video_bench_stage_result = SVC_OK;
  return start;
}

/* Mirrors frame_check() in tools/snes-video-bench-assets.py byte for byte. */
static uint16_t frame_check(const uint8_t *frame) {
  uint16_t a = 0u, b = 0u, i;
  for (i = 0; i != SVC_FRAME_SIZE; ++i) {
    a = (uint16_t)(a + frame[i]);
    b = (uint16_t)(b + a);
  }
  return (uint16_t)(a ^ b);
}
#endif

#if defined(VIDEO_BENCH_PIPELINE) || defined(VIDEO_BENCH_STREAM)
#if !defined(VIDEO_BENCH_STREAM)
volatile uint8_t video_bench_stage_result;
#endif
#if !defined(VIDEO_BENCH_STREAM)
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
#endif

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

#if defined(VIDEO_BENCH_STREAM)
static uint16_t stream_frame;

/* One complete player step: refill this frame's packet through the ring, decode
   it in place from high WRAM, present it. SVX2 delta spans advance source and
   destination together, so `output` is legitimately both previous and output. */
static uint8_t decode_once(void) {
  uint16_t staged = stage_stream_frame(stream_frame);
  if (!staged) return 0;
  svx_decode_payload_wram_fast((uint16_t)(staged + 9u),
                               bench_stream_keyframes[stream_frame],
                               output, output);
  present_frame();
  if (++stream_frame == VIDEO_BENCH_STREAM_FRAMES) stream_frame = 0u;
  return 1u;
}
#else
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
#endif

#if defined(VIDEO_BENCH_STREAM)
/* Byte-correctness gate for the whole loop, run once before timing starts.
   Every frame's decode is checked; the final frame is additionally compared
   byte for byte, so the complete delta chain is pinned to the host oracle. */
static void validate_stream(void) {
  uint16_t frame, i;
  for (frame = 0; frame != VIDEO_BENCH_STREAM_FRAMES; ++frame) {
    if (!decode_once()) { corpus_result = 1u; for (;;) __asm__ volatile("wai"); }
    if (frame_check(output) != bench_stream_checks[frame]) {
      corpus_result = 2u;
      for (;;) __asm__ volatile("wai");
    }
  }
  for (i = 0; i != SVC_FRAME_SIZE; ++i)
    if (output[i] != bench_stream_final[i]) {
      corpus_result = 4u;
      for (;;) __asm__ volatile("wai");
    }
  /* decode_once() wrapped stream_frame back to 0, so the timed loop restarts on
     the independent keyframe and never depends on the final frame. */
}
#endif

void video_bench_run(void) {
  uint16_t i;
#if defined(VIDEO_BENCH_VISIBLE)
  snes_ppu_reset_blank();
#endif
  corpus_result = 0xffu;
  video_bench_iters = 0;
#if defined(VIDEO_BENCH_STREAM)
  (void)i;
  validate_stream();
#else
  if (!decode_once()) { corpus_result = 1u; for (;;) __asm__ volatile("wai"); }
  for (i = 0; i != SVC_FRAME_SIZE; ++i)
    if (output[i] != bench_expected[i]) { corpus_result = 2u; for (;;) __asm__ volatile("wai"); }
#endif
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
