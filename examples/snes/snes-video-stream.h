#ifndef SNES_VIDEO_STREAM_H
#define SNES_VIDEO_STREAM_H

#include <stdint.h>
#include "snes-video-codec.h"

typedef struct {
  uint8_t bank;
  uint16_t address;
  uint16_t bytes;
} SvcRomSegment;

/* Copy one bank-contained range from canonical ROM space into near WRAM. */
typedef uint8_t (*SvcSegmentCopy)(void *context, uint8_t bank, uint16_t address,
                                  uint8_t *destination, uint16_t bytes);

typedef struct {
  const SvcRomSegment *segments;
  uint8_t segment_count;
  uint8_t segment_index;
  uint16_t segment_offset;
  uint16_t bytes_left;
  SvcSegmentCopy copy;
  void *context;
} SvcSegmentCursor;

uint8_t svc_segment_cursor_init(SvcSegmentCursor *cursor,
                                const SvcRomSegment *segments,
                                uint8_t segment_count, uint16_t total_bytes,
                                SvcSegmentCopy copy, void *context);
uint8_t svc_segment_cursor_read(SvcSegmentCursor *cursor, uint8_t *destination,
                                uint16_t requested);
uint8_t svx_stage_segments_and_decode_fast(SvcSegmentCursor *cursor,
                                           uint16_t packet_bytes,
                                           uint8_t *staging,
                                           uint16_t staging_capacity,
                                           const uint8_t *previous,
                                           uint8_t *output);

#endif
