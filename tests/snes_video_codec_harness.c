#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "../examples/snes/snes-video-stream.h"

typedef struct { const uint8_t *data; size_t size, position; } MemoryInput;
static uint8_t read_byte(void *opaque, uint8_t *value) {
  MemoryInput *input = (MemoryInput *)opaque;
  if (input->position == input->size) return 0;
  *value = input->data[input->position++];
  return 1;
}
typedef struct { const uint8_t *packet; uint16_t split; } SplitPacket;
static uint8_t copy_segment(void *opaque, uint8_t bank, uint16_t address,
                            uint8_t *destination, uint16_t bytes) {
  SplitPacket *split = (SplitPacket *)opaque;
  const uint8_t *source;
  if (bank == 0x40u && address == 0xfff9u) source = split->packet;
  else if (bank == 0x41u && address == 0x8000u) source = split->packet + split->split;
  else return 0;
  __builtin_memcpy(destination, source, bytes);
  return 1;
}
int main(void) {
  uint8_t *packet, *previous, *output, *staging;
  uint16_t packet_size, crc;
  MemoryInput memory;
  SvcInput input;
  if (fread(&packet_size, 2, 1, stdin) != 1) return 2;
  packet = malloc(packet_size); staging = malloc(packet_size);
  previous = malloc(SVC_FRAME_SIZE); output = malloc(SVC_FRAME_SIZE);
  if (!packet || !staging || !previous || !output || fread(previous, SVC_FRAME_SIZE, 1, stdin) != 1 ||
      fread(packet, packet_size, 1, stdin) != 1) return 2;
  memory.data = packet; memory.size = packet_size; memory.position = 0;
  input.read = read_byte; input.context = &memory; input.packet_bytes = packet_size;
  if (packet[2] == 'X') {
    const uint8_t *old = packet[4] & 1 ? 0 : previous;
    SvcRomSegment segments[2];
    SvcSegmentCursor cursor;
    SplitPacket split = {packet, 7u};
    if (svx_decode_contiguous_fast(packet, packet_size, old, output) != SVC_OK) return 1;
    memory.position = 0;
    if (svx_stage_and_decode_fast(&input, staging, packet_size, old, output) != SVC_OK) return 1;
    segments[0].bank = 0x40u; segments[0].address = 0xfff9u; segments[0].bytes = split.split;
    segments[1].bank = 0x41u; segments[1].address = 0x8000u;
    segments[1].bytes = packet_size - split.split;
    if (svc_segment_cursor_init(&cursor, segments, 2, packet_size, copy_segment, &split) != SVC_OK)
      return 1;
    if (svx_stage_segments_and_decode_fast(&cursor, packet_size, staging, packet_size, old, output)
        != SVC_OK) return 1;
  } else if (svc_decode_frame(&input, packet[4] & 1 ? 0 : previous, output, &crc) != SVC_OK)
    return 1;
  if (fwrite(output, SVC_FRAME_SIZE, 1, stdout) != 1) return 2;
  free(packet); free(staging); free(previous); free(output);
  return 0;
}
