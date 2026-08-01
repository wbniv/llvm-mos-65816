#ifndef SNES_VIDEO_CODEC_H
#define SNES_VIDEO_CODEC_H

#include <stdint.h>

#define SVC_BLOCK_SIZE 64u
#define SVC_BLOCK_COUNT 70u
#define SVC_FRAME_SIZE (SVC_BLOCK_SIZE * SVC_BLOCK_COUNT)

enum {
  SVC_OK = 0,
  SVC_ERR_TRUNCATED = 1,
  SVC_ERR_HEADER = 2,
  SVC_ERR_COMMAND = 3,
  SVC_ERR_PREVIOUS = 4,
  SVC_ERR_OVERFLOW = 5,
  SVC_ERR_CRC = 6,
  SVC_ERR_TRAILING = 7
};

/* Return nonzero and store one byte in *value, or return zero at EOF/error. */
typedef uint8_t (*SvcReadByte)(void *context, uint8_t *value);

typedef struct {
  SvcReadByte read;
  void *context;
  uint16_t packet_bytes;
} SvcInput;

/* `output` and `previous` must be distinct 4480-byte buffers for delta frames. */
uint8_t svc_decode_frame(SvcInput *input, const uint8_t *previous,
                         uint8_t *output, uint16_t *decoded_crc);

/* SVX2: PackBits keyframes plus absolute-replacement/previous-copy delta spans. */
uint8_t svx_decode_frame(SvcInput *input, const uint8_t *previous,
                         uint8_t *output, uint16_t *decoded_crc);
/* Playback path: retains all bounds/format checks but skips the per-byte CRC pass. */
uint8_t svx_decode_frame_fast(SvcInput *input, const uint8_t *previous, uint8_t *output);
/* Direct playback kernel after mapper-aware refill has staged one bounded packet in WRAM. */
uint8_t svx_decode_contiguous_fast(const uint8_t *packet, uint16_t packet_bytes,
                                   const uint8_t *previous, uint8_t *output);
/* Mapper-neutral playback boundary: stage one packet through SvcInput, then decode it. */
uint8_t svx_stage_and_decode_fast(SvcInput *input, uint8_t *staging,
                                  uint16_t staging_capacity,
                                  const uint8_t *previous, uint8_t *output);
/* Trusted hot loop for a packet already accepted by the checked decoder/host gates. */
void svx_decode_payload_fast(const uint8_t *payload, uint8_t keyframe,
                             const uint8_t *previous, uint8_t *output);
#ifdef __mos__
void svx_decode_payload_wram_fast(uint16_t source_address, uint8_t keyframe,
                                  const uint8_t *previous, uint8_t *output);
#endif
/* Native block-move control used to establish the no-codec CPU-copy ceiling. */
void svc_copy_frame_fast(const uint8_t *source, uint8_t *output);

#endif
