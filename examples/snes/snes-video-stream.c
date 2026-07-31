#include "snes-video-stream.h"

uint8_t svc_segment_cursor_init(SvcSegmentCursor *cursor,
                                const SvcRomSegment *segments,
                                uint8_t segment_count, uint16_t total_bytes,
                                SvcSegmentCopy copy, void *context) {
  uint8_t i;
  uint32_t sum = 0;
  if (!cursor || !segments || !segment_count || !total_bytes || !copy) return SVC_ERR_HEADER;
  for (i = 0; i != segment_count; ++i) {
    if (!segments[i].bytes || (uint32_t)segments[i].address + segments[i].bytes > 0x10000ul)
      return SVC_ERR_OVERFLOW;
    sum += segments[i].bytes;
  }
  if (sum != total_bytes) return SVC_ERR_TRAILING;
  cursor->segments = segments;
  cursor->segment_count = segment_count;
  cursor->segment_index = 0;
  cursor->segment_offset = 0;
  cursor->bytes_left = total_bytes;
  cursor->copy = copy;
  cursor->context = context;
  return SVC_OK;
}

uint8_t svc_segment_cursor_read(SvcSegmentCursor *cursor, uint8_t *destination,
                                uint16_t requested) {
  if (!cursor || !destination || requested > cursor->bytes_left) return SVC_ERR_OVERFLOW;
  while (requested) {
    const SvcRomSegment *segment;
    uint16_t available, chunk;
    if (cursor->segment_index == cursor->segment_count) return SVC_ERR_TRUNCATED;
    segment = &cursor->segments[cursor->segment_index];
    available = segment->bytes - cursor->segment_offset;
    chunk = requested < available ? requested : available;
    if (!cursor->copy(cursor->context, segment->bank,
                      segment->address + cursor->segment_offset,
                      destination, chunk)) return SVC_ERR_TRUNCATED;
    destination += chunk;
    requested -= chunk;
    cursor->bytes_left -= chunk;
    cursor->segment_offset += chunk;
    if (cursor->segment_offset == segment->bytes) {
      ++cursor->segment_index;
      cursor->segment_offset = 0;
    }
  }
  return SVC_OK;
}

uint8_t svx_stage_segments_and_decode_fast(SvcSegmentCursor *cursor,
                                           uint16_t packet_bytes,
                                           uint8_t *staging,
                                           uint16_t staging_capacity,
                                           const uint8_t *previous,
                                           uint8_t *output) {
  uint8_t result;
  if (!cursor || packet_bytes != cursor->bytes_left) return SVC_ERR_TRAILING;
  if (packet_bytes > staging_capacity) return SVC_ERR_OVERFLOW;
  result = svc_segment_cursor_read(cursor, staging, packet_bytes);
  if (result != SVC_OK) return result;
  return svx_decode_contiguous_fast(staging, packet_bytes, previous, output);
}
