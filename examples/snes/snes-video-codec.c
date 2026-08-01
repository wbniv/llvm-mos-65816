#include "snes-video-codec.h"

enum {
  SVC_FLAG_KEYFRAME = 1,
  SVC_OP_SAME = 0,
  SVC_OP_COPY = 1,
  SVC_OP_SOLID = 2,
  SVC_OP_TWO_COLOR = 3,
  SVC_OP_XOR_PACKBITS = 4,
  SVC_OP_RAW = 5
};

typedef struct {
  SvcInput *source;
  uint16_t left;
} Reader;

static uint8_t take(Reader *reader, uint8_t *value) {
  if (!reader->left || !reader->source->read(reader->source->context, value))
    return 0;
  --reader->left;
  return 1;
}

static uint8_t take16(Reader *reader, uint16_t *value) {
  uint8_t lo, hi;
  if (!take(reader, &lo) || !take(reader, &hi)) return 0;
  *value = (uint16_t)lo | ((uint16_t)hi << 8);
  return 1;
}

static uint16_t crc_byte(uint16_t crc, uint8_t value) {
  uint8_t bit;
  crc ^= (uint16_t)value << 8;
  for (bit = 0; bit != 8; ++bit)
    crc = crc & 0x8000u ? (uint16_t)((crc << 1) ^ 0x1021u) : (uint16_t)(crc << 1);
  return crc;
}

static uint8_t decode_packbits_xor(Reader *reader, uint8_t encoded_size,
                                   const uint8_t *old, uint8_t *out) {
  uint8_t consumed = 0, produced = 0;
  while (consumed < encoded_size && produced < SVC_BLOCK_SIZE) {
    uint8_t control;
    if (!take(reader, &control)) return SVC_ERR_TRUNCATED;
    ++consumed;
    if (control <= 127u) {
      uint8_t count = (uint8_t)(control + 1u);
      if ((uint16_t)consumed + count > encoded_size ||
          (uint16_t)produced + count > SVC_BLOCK_SIZE) return SVC_ERR_OVERFLOW;
      while (count--) {
        uint8_t value;
        if (!take(reader, &value)) return SVC_ERR_TRUNCATED;
        out[produced] = old[produced] ^ value;
        ++produced;
        ++consumed;
      }
    } else if (control >= 129u) {
      uint8_t value, count = (uint8_t)(257u - control);
      if (++consumed > encoded_size || (uint16_t)produced + count > SVC_BLOCK_SIZE ||
          !take(reader, &value)) return SVC_ERR_TRUNCATED;
      while (count--) {
        out[produced] = old[produced] ^ value;
        ++produced;
      }
    }
  }
  return consumed == encoded_size && produced == SVC_BLOCK_SIZE ? SVC_OK : SVC_ERR_COMMAND;
}

uint8_t svc_decode_frame(SvcInput *input, const uint8_t *previous,
                         uint8_t *output, uint16_t *decoded_crc) {
  Reader reader;
  uint8_t magic[4], flags, blocks, block_index;
  uint16_t payload_size, expected_crc, crc = 0xffffu;
  if (!input || !input->read || !output || input->packet_bytes < 10u) return SVC_ERR_HEADER;
  reader.source = input;
  reader.left = input->packet_bytes;
  for (block_index = 0; block_index != 4; ++block_index)
    if (!take(&reader, &magic[block_index])) return SVC_ERR_TRUNCATED;
  if (!take(&reader, &flags) || !take(&reader, &blocks) ||
      !take16(&reader, &payload_size) || !take16(&reader, &expected_crc)) return SVC_ERR_TRUNCATED;
  if (magic[0] != 'S' || magic[1] != 'V' || magic[2] != 'C' || magic[3] != '1' ||
      flags & (uint8_t)~SVC_FLAG_KEYFRAME || blocks != SVC_BLOCK_COUNT ||
      payload_size != reader.left) return SVC_ERR_HEADER;
  if (!(flags & SVC_FLAG_KEYFRAME) && (!previous || previous == output)) return SVC_ERR_PREVIOUS;

  for (block_index = 0; block_index != SVC_BLOCK_COUNT; ++block_index) {
    uint8_t op, i, value;
    uint8_t *block = output + (uint16_t)block_index * SVC_BLOCK_SIZE;
    const uint8_t *old = previous ? previous + (uint16_t)block_index * SVC_BLOCK_SIZE : 0;
    if (!take(&reader, &op)) return SVC_ERR_TRUNCATED;
    switch (op) {
    case SVC_OP_SAME:
      if (!old || flags & SVC_FLAG_KEYFRAME) return SVC_ERR_PREVIOUS;
      for (i = 0; i != SVC_BLOCK_SIZE; ++i) block[i] = old[i];
      break;
    case SVC_OP_COPY:
      if (!previous || flags & SVC_FLAG_KEYFRAME || !take(&reader, &value) || value >= SVC_BLOCK_COUNT)
        return SVC_ERR_PREVIOUS;
      old = previous + (uint16_t)value * SVC_BLOCK_SIZE;
      for (i = 0; i != SVC_BLOCK_SIZE; ++i) block[i] = old[i];
      break;
    case SVC_OP_SOLID:
      if (!take(&reader, &value)) return SVC_ERR_TRUNCATED;
      for (i = 0; i != SVC_BLOCK_SIZE; ++i) block[i] = value;
      break;
    case SVC_OP_TWO_COLOR: {
      uint8_t low, high, bitmap;
      if (!take(&reader, &low) || !take(&reader, &high) || low >= high) return SVC_ERR_COMMAND;
      for (i = 0; i != 8; ++i) {
        uint8_t bit;
        if (!take(&reader, &bitmap)) return SVC_ERR_TRUNCATED;
        for (bit = 0; bit != 8; ++bit)
          block[(uint8_t)(i * 8u + bit)] = bitmap & (uint8_t)(1u << bit) ? high : low;
      }
      break;
    }
    case SVC_OP_XOR_PACKBITS:
      if (!old || flags & SVC_FLAG_KEYFRAME || !take(&reader, &value)) return SVC_ERR_PREVIOUS;
      value = decode_packbits_xor(&reader, value, old, block);
      if (value != SVC_OK) return value;
      break;
    case SVC_OP_RAW:
      for (i = 0; i != SVC_BLOCK_SIZE; ++i)
        if (!take(&reader, &block[i])) return SVC_ERR_TRUNCATED;
      break;
    default:
      return SVC_ERR_COMMAND;
    }
    for (i = 0; i != SVC_BLOCK_SIZE; ++i) crc = crc_byte(crc, block[i]);
  }
  if (reader.left) return SVC_ERR_TRAILING;
  if (decoded_crc) *decoded_crc = crc;
  return crc == expected_crc ? SVC_OK : SVC_ERR_CRC;
}

static uint8_t svx_decode_impl(SvcInput *input, const uint8_t *previous,
                               uint8_t *output, uint16_t *decoded_crc, uint8_t verify_crc) {
  Reader reader;
  uint8_t magic[4], flags, control, value;
  uint16_t payload_size, expected_crc, produced = 0, crc = 0xffffu;
  if (!input || !input->read || !output || input->packet_bytes < 9u) return SVC_ERR_HEADER;
  reader.source = input; reader.left = input->packet_bytes;
  for (value = 0; value != 4; ++value)
    if (!take(&reader, &magic[value])) return SVC_ERR_TRUNCATED;
  if (!take(&reader, &flags) || !take16(&reader, &payload_size) ||
      !take16(&reader, &expected_crc)) return SVC_ERR_TRUNCATED;
  if (magic[0] != 'S' || magic[1] != 'V' || magic[2] != 'X' || magic[3] != '2' ||
      flags & (uint8_t)~SVC_FLAG_KEYFRAME || payload_size != reader.left)
    return SVC_ERR_HEADER;
  if (!(flags & SVC_FLAG_KEYFRAME) && (!previous || previous == output)) return SVC_ERR_PREVIOUS;
  while (reader.left && produced < SVC_FRAME_SIZE) {
    uint16_t count;
    if (!take(&reader, &control)) return SVC_ERR_TRUNCATED;
    if (!(flags & SVC_FLAG_KEYFRAME)) {
      count = (uint16_t)(control & 127u) + 1u;
      if (produced + count > SVC_FRAME_SIZE) return SVC_ERR_OVERFLOW;
      if (control & 128u) {
        while (count--) {
          output[produced] = previous[produced];
          if (verify_crc) crc = crc_byte(crc, output[produced]);
          ++produced;
        }
      } else {
        if (count > reader.left) return SVC_ERR_TRUNCATED;
        while (count--) {
          if (!take(&reader, &output[produced])) return SVC_ERR_TRUNCATED;
          if (verify_crc) crc = crc_byte(crc, output[produced]);
          ++produced;
        }
      }
      continue;
    }
    if (control <= 127u) {
      count = (uint16_t)control + 1u;
      if (count > reader.left || produced + count > SVC_FRAME_SIZE) return SVC_ERR_OVERFLOW;
      while (count--) {
        if (!take(&reader, &value)) return SVC_ERR_TRUNCATED;
        output[produced] = value;
        if (verify_crc) crc = crc_byte(crc, output[produced]);
        ++produced;
      }
    } else if (control >= 129u) {
      count = 257u - control;
      if (!reader.left || produced + count > SVC_FRAME_SIZE || !take(&reader, &value))
        return SVC_ERR_OVERFLOW;
      while (count--) {
        output[produced] = value;
        if (verify_crc) crc = crc_byte(crc, output[produced]);
        ++produced;
      }
    }
  }
  if (reader.left || produced != SVC_FRAME_SIZE) return SVC_ERR_TRAILING;
  if (!verify_crc) return SVC_OK;
  if (decoded_crc) *decoded_crc = crc;
  return crc == expected_crc ? SVC_OK : SVC_ERR_CRC;
}

uint8_t svx_decode_frame(SvcInput *input, const uint8_t *previous,
                         uint8_t *output, uint16_t *decoded_crc) {
  return svx_decode_impl(input, previous, output, decoded_crc, 1u);
}

uint8_t svx_decode_frame_fast(SvcInput *input, const uint8_t *previous, uint8_t *output) {
  return svx_decode_impl(input, previous, output, 0, 0u);
}

uint8_t svx_decode_contiguous_fast(const uint8_t *packet, uint16_t packet_bytes,
                                   const uint8_t *previous, uint8_t *output) {
  const uint8_t *source, *end;
  uint16_t payload_size, produced = 0;
  uint8_t flags;
  if (!packet || !output || packet_bytes < 9u || packet[0] != 'S' || packet[1] != 'V' ||
      packet[2] != 'X' || packet[3] != '2') return SVC_ERR_HEADER;
  flags = packet[4];
  payload_size = (uint16_t)packet[5] | ((uint16_t)packet[6] << 8);
  if (flags & (uint8_t)~SVC_FLAG_KEYFRAME || payload_size != (uint16_t)(packet_bytes - 9u))
    return SVC_ERR_HEADER;
  if (!(flags & SVC_FLAG_KEYFRAME) && (!previous || previous == output)) return SVC_ERR_PREVIOUS;
  source = packet + 9u;
  end = source + payload_size;
  while (source != end && produced < SVC_FRAME_SIZE) {
    uint8_t control = *source++;
    uint16_t count;
    if (!(flags & SVC_FLAG_KEYFRAME)) {
      count = (uint16_t)(control & 127u) + 1u;
      if (produced + count > SVC_FRAME_SIZE) return SVC_ERR_OVERFLOW;
      if (control & 128u) {
        while (count--) { output[produced] = previous[produced]; ++produced; }
      } else {
        if ((uint16_t)(end - source) < count) return SVC_ERR_OVERFLOW;
        while (count--) output[produced++] = *source++;
      }
      continue;
    }
    if (control <= 127u) {
      count = (uint16_t)control + 1u;
      if ((uint16_t)(end - source) < count || produced + count > SVC_FRAME_SIZE)
        return SVC_ERR_OVERFLOW;
      while (count--) output[produced++] = *source++;
    } else if (control >= 129u) {
      uint8_t value;
      count = 257u - control;
      if (source == end || produced + count > SVC_FRAME_SIZE) return SVC_ERR_OVERFLOW;
      value = *source++;
      while (count--) output[produced++] = value;
    }
  }
  return source == end && produced == SVC_FRAME_SIZE ? SVC_OK : SVC_ERR_TRAILING;
}

uint8_t svx_stage_and_decode_fast(SvcInput *input, uint8_t *staging,
                                  uint16_t staging_capacity,
                                  const uint8_t *previous, uint8_t *output) {
  uint16_t i, payload_size;
  uint8_t flags;
  if (!input || !input->read || !staging || !output || input->packet_bytes < 9u)
    return SVC_ERR_HEADER;
  if (input->packet_bytes > staging_capacity) return SVC_ERR_OVERFLOW;
  for (i = 0; i != input->packet_bytes; ++i)
    if (!input->read(input->context, &staging[i])) return SVC_ERR_TRUNCATED;
  if (staging[0] != 'S' || staging[1] != 'V' || staging[2] != 'X' || staging[3] != '2')
    return SVC_ERR_HEADER;
  flags = staging[4];
  payload_size = (uint16_t)staging[5] | ((uint16_t)staging[6] << 8);
  if (flags & (uint8_t)~SVC_FLAG_KEYFRAME ||
      payload_size != (uint16_t)(input->packet_bytes - 9u)) return SVC_ERR_HEADER;
  if (!(flags & SVC_FLAG_KEYFRAME) && (!previous || previous == output))
    return SVC_ERR_PREVIOUS;
  svx_decode_payload_fast(staging + 9u, flags & SVC_FLAG_KEYFRAME, previous, output);
  return SVC_OK;
}

#ifdef __mos__
const uint8_t *svx_asm_source;
const uint8_t *svx_asm_previous;
uint8_t *svx_asm_output;
uint8_t svx_asm_keyframe;
uint8_t svx_asm_source_bank;
extern void svx_decode_payload_asm(void);
extern void svx_decode_payload_wram_asm(void);
extern void svc_copy_frame_asm(void);

#if 0 /* Defined in snes-video-codec-fast.s so the assembler sees mosw65816. */
asm(
".text\n"
".global svx_decode_payload_asm\n"
"svx_decode_payload_asm:\n"
"  php\n"
"  phb\n"
"  rep #$30\n"
"  phx\n"
"  phy\n"
"  lda svx_asm_source\n"
"  sta __rc0\n"
"  lda svx_asm_previous\n"
"  sta __rc2\n"
"  lda svx_asm_output\n"
"  sta __rc4\n"
"  lda #4480\n"
"  sta __rc6\n"
"  sep #$20\n"
"  lda svx_asm_keyframe\n"
"  beq .Lsvx_delta_token\n"
".Lsvx_key_token:\n"
"  ldy #0\n"
"  lda (__rc0),y\n"
"  cmp #$80\n"
"  beq .Lsvx_key_nop\n"
"  bcs .Lsvx_key_run\n"
"  inc\n"
"  rep #$20\n"
"  and #$00ff\n"
"  sta __rc8\n"
"  dec\n"
"  ldx __rc0\n"
"  inx\n"
"  ldy __rc4\n"
"  mvn $00,$00\n"
"  stx __rc0\n"
"  sty __rc4\n"
"  lda __rc6\n"
"  sec\n"
"  sbc __rc8\n"
"  sta __rc6\n"
"  sep #$20\n"
"  bne .Lsvx_key_token\n"
"  bra .Lsvx_done\n"
".Lsvx_key_run:\n"
"  sta __rc10\n"
"  ldy #1\n"
"  lda (__rc0),y\n"
"  sta __rc11\n"
"  lda #1\n"
"  sec\n"
"  sbc __rc10\n"
"  rep #$20\n"
"  and #$00ff\n"
"  sta __rc8\n"
"  ldy #0\n"
"  sep #$20\n"
"  lda __rc11\n"
".Lsvx_key_run_loop:\n"
"  sta (__rc4),y\n"
"  iny\n"
"  cpy __rc8\n"
"  bne .Lsvx_key_run_loop\n"
"  rep #$20\n"
"  lda __rc0\n"
"  clc\n"
"  adc #2\n"
"  sta __rc0\n"
"  lda __rc4\n"
"  clc\n"
"  adc __rc8\n"
"  sta __rc4\n"
"  lda __rc6\n"
"  sec\n"
"  sbc __rc8\n"
"  sta __rc6\n"
"  sep #$20\n"
"  bne .Lsvx_key_token\n"
"  bra .Lsvx_done\n"
".Lsvx_key_nop:\n"
"  rep #$20\n"
"  inc __rc0\n"
"  sep #$20\n"
"  bra .Lsvx_key_token\n"
".Lsvx_delta_token:\n"
"  ldy #0\n"
"  lda (__rc0),y\n"
"  cmp #$80\n"
"  beq .Lsvx_delta_nop\n"
"  bcs .Lsvx_delta_run\n"
"  inc\n"
"  rep #$20\n"
"  and #$00ff\n"
"  sta __rc8\n"
"  inc __rc0\n"
"  ldy #0\n"
"  sep #$20\n"
".Lsvx_delta_literal_loop:\n"
"  lda (__rc0),y\n"
"  eor (__rc2),y\n"
"  sta (__rc4),y\n"
"  iny\n"
"  cpy __rc8\n"
"  bne .Lsvx_delta_literal_loop\n"
"  bra .Lsvx_delta_advance\n"
".Lsvx_delta_run:\n"
"  sta __rc10\n"
"  ldy #1\n"
"  lda (__rc0),y\n"
"  sta __rc11\n"
"  lda #1\n"
"  sec\n"
"  sbc __rc10\n"
"  rep #$20\n"
"  and #$00ff\n"
"  sta __rc8\n"
"  inc __rc0\n"
"  ldy #0\n"
"  sep #$20\n"
".Lsvx_delta_run_loop:\n"
"  lda (__rc2),y\n"
"  eor __rc11\n"
"  sta (__rc4),y\n"
"  iny\n"
"  cpy __rc8\n"
"  bne .Lsvx_delta_run_loop\n"
".Lsvx_delta_advance:\n"
"  rep #$20\n"
"  lda __rc0\n"
"  clc\n"
"  adc __rc8\n"
"  sta __rc0\n"
"  lda __rc2\n"
"  clc\n"
"  adc __rc8\n"
"  sta __rc2\n"
"  lda __rc4\n"
"  clc\n"
"  adc __rc8\n"
"  sta __rc4\n"
"  lda __rc6\n"
"  sec\n"
"  sbc __rc8\n"
"  sta __rc6\n"
"  sep #$20\n"
"  bne .Lsvx_delta_token\n"
"  bra .Lsvx_done\n"
".Lsvx_delta_nop:\n"
"  rep #$20\n"
"  inc __rc0\n"
"  sep #$20\n"
"  bra .Lsvx_delta_token\n"
".Lsvx_done:\n"
"  rep #$30\n"
"  ply\n"
"  plx\n"
"  plb\n"
"  plp\n"
"  rts\n"
);
#endif
#endif

void svc_copy_frame_fast(const uint8_t *source, uint8_t *output) {
#ifdef __mos__
  svx_asm_source = source;
  svx_asm_output = output;
  svc_copy_frame_asm();
#else
  __builtin_memcpy(output, source, SVC_FRAME_SIZE);
#endif
}

void svx_decode_payload_fast(const uint8_t *source, uint8_t keyframe,
                             const uint8_t *previous, uint8_t *output) {
#if defined(__mos__) && defined(SVC_USE_ASM)
  svx_asm_source = source;
  svx_asm_previous = previous;
  svx_asm_output = output;
  svx_asm_keyframe = keyframe;
  svx_asm_source_bank = 0u;
  svx_decode_payload_asm();
#else
  uint16_t remaining = SVC_FRAME_SIZE;
  if (keyframe) {
    while (remaining) {
      uint8_t control = *source++;
      uint16_t count;
      if (control <= 127u) {
        count = (uint16_t)control + 1u;
        __builtin_memcpy(output, source, count);
        output += count; source += count;
      } else if (control >= 129u) {
        count = 257u - control;
        __builtin_memset(output, *source++, count);
        output += count;
      } else continue;
      remaining -= count;
    }
  } else {
    while (remaining) {
      uint8_t control = *source++;
      uint16_t count = (uint16_t)(control & 127u) + 1u;
      remaining -= count;
      if (!(control & 128u)) {
        while (count--) { *output++ = *source++; ++previous; }
      } else while (count--) *output++ = *previous++;
    }
  }
#endif
}

#ifdef __mos__
void svx_decode_payload_wram_fast(uint16_t source_address, uint8_t keyframe,
                                  const uint8_t *previous, uint8_t *output) {
  svx_asm_source = (const uint8_t *)(uintptr_t)source_address;
  svx_asm_previous = previous;
  svx_asm_output = output;
  svx_asm_keyframe = keyframe;
  svx_asm_source_bank = 0x7fu;
  if (keyframe)
    svx_decode_payload_asm();
  else
    svx_decode_payload_wram_asm();
}
#endif
