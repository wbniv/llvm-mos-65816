#include <stdint.h>
#include <string.h>
#include "../examples/snes/snes-video-stream.h"

static uint8_t bank40[16], bank41[16];
static uint8_t copy_segment(void *context, uint8_t bank, uint16_t address,
                            uint8_t *destination, uint16_t bytes) {
  const uint8_t *source;
  (void)context;
  if (address < 0xfff8u || (uint32_t)address + bytes > 0x10000ul) return 0;
  source = bank == 0x40u ? bank40 : bank == 0x41u ? bank41 : 0;
  if (!source) return 0;
  memcpy(destination, source + (address - 0xfff8u), bytes);
  return 1;
}

int main(void) {
  static const SvcRomSegment segments[] = {{0x40, 0xfff8, 8}, {0x41, 0xfff8, 8}};
  SvcSegmentCursor cursor;
  uint8_t output[16], i;
  for (i = 0; i != 16; ++i) { bank40[i] = i; bank41[i] = i + 8; }
  if (svc_segment_cursor_init(&cursor, segments, 2, 16, copy_segment, 0) != SVC_OK) return 1;
  if (svc_segment_cursor_read(&cursor, output, 16) != SVC_OK || cursor.bytes_left) return 2;
  for (i = 0; i != 16; ++i) if (output[i] != i) return 3;
  return 0;
}
