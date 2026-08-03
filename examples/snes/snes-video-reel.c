#include <snes.h>
#include <stdint.h>

#include "mode7.h"
#include "snesgfx/m7title.h"
#include "snes-video-codec.h"
#include "snes-video-dma.h"
#include "video_fps.h"
#include "video_hud.h"
#include <snes-video-reel-assets.h>

#define STAGE_ADDRESS 0x2000u
#ifndef VIDEO_REEL_VBLANKS_PER_FRAME
#define VIDEO_REEL_VBLANKS_PER_FRAME 2u
#endif
#define VIDEO_REEL_SOURCE_FPS (60u / VIDEO_REEL_VBLANKS_PER_FRAME)

volatile uint8_t video_reel_result;
volatile uint16_t video_reel_frame;
volatile uint16_t video_reel_decoded;
volatile uint32_t video_reel_presented_total;
volatile uint16_t video_reel_crc_failures;
volatile uint16_t video_reel_deadline_slips;
volatile uint16_t video_reel_last_crc;
volatile uint8_t video_reel_loop_gate;
volatile uint32_t video_reel_vblanks;
volatile uint8_t video_reel_transport_state;
volatile uint8_t video_reel_transport_rate;
volatile uint8_t video_reel_seek_decode_count;
volatile uint8_t video_reel_segment;
volatile uint8_t video_reel_segment_gate;
volatile uint8_t video_reel_time_reset_gate;
volatile uint32_t video_reel_composite_health;

#ifdef VIDEO_REEL_PROFILE
typedef struct {
  uint8_t stage_q1024;
  uint8_t decode_q1024;
  uint8_t present_q1024;
} VideoReelProfile;

volatile VideoReelProfile video_reel_profile[VIDEO_REEL_FRAME_COUNT];
volatile uint16_t video_reel_profile_samples;

typedef struct {
  uint32_t vblank;
  uint32_t raster;
} VideoReelStamp;

static VideoReelStamp profile_stamp(void) {
  VideoReelStamp stamp;
  uint16_t h, v;
  uint8_t lo;
  (void)REG_SLHV;
  lo = REG_OPHCT;
  h = (uint16_t)(lo | ((uint16_t)(REG_OPHCT & 1u) << 8));
  lo = REG_OPVCT;
  v = (uint16_t)(lo | ((uint16_t)(REG_OPVCT & 1u) << 8));
  stamp.vblank = video_reel_vblanks;
  /* video_reel_vblanks advances at the NMI boundary (scanline 225), not at
     raster line zero. Rotate the raster coordinate to the same origin before
     composing an absolute timestamp. */
  v = (uint16_t)((v + 262u - 225u) % 262u);
  stamp.raster = (uint32_t)v * 341u + h;
  return stamp;
}

static uint32_t profile_elapsed(VideoReelStamp begin, VideoReelStamp end) {
  /* NMI occurs once per 262-line NTSC frame. Pairing it with the raster
     position preserves durations when a phase crosses one or more frames. */
  return (end.vblank * (262ul * 341ul) + end.raster) -
         (begin.vblank * (262ul * 341ul) + begin.raster);
}

static uint8_t profile_quantize(uint32_t dots) {
  dots = (dots + 512u) >> 10;
  return dots > 255u ? 255u : (uint8_t)dots;
}
#endif

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
static uint8_t dashboard_frame_tick;
static uint8_t dashboard_seconds;
static uint8_t dashboard_minutes;
static uint16_t transport_pad_previous;
static uint8_t transport_hold;
static uint8_t transport_visible;
static uint8_t transport_hide;
static uint8_t transport_resume;

static uint8_t segment_for_frame(uint16_t frame) {
#ifdef VIDEO_REEL_SEGMENT_COUNT
  uint8_t segment = 0u;
  while ((uint8_t)(segment + 1u) < VIDEO_REEL_SEGMENT_COUNT &&
         frame >= reel_segment_starts[segment + 1u])
    ++segment;
  return segment;
#else
  (void)frame;
  return 0u;
#endif
}

static void dashboard_segment(uint16_t frame, uint8_t force) {
  uint8_t segment = segment_for_frame(frame);
  if (!force && segment == video_reel_segment) return;
  video_reel_segment = segment;
#ifdef VIDEO_REEL_SEGMENT_COUNT
  /* A full sequential loop must visit every Artemis cut in order. This
     target-visible state gives the emulator gate an exact transition proof. */
  if (video_reel_segment_gate == 0xffu && frame == 0u && segment == 0u)
    video_reel_segment_gate = 1u;
  else if (video_reel_segment_gate < VIDEO_REEL_SEGMENT_COUNT &&
           frame == reel_segment_starts[video_reel_segment_gate] &&
           segment == video_reel_segment_gate)
    ++video_reel_segment_gate;
  else if (video_reel_segment_gate == VIDEO_REEL_SEGMENT_COUNT &&
           frame == 0u && segment == 0u)
    video_reel_segment_gate = 0xa5u;
#endif
  if (transport_visible) return;
#ifdef VIDEO_REEL_SEGMENT_COUNT
  {
    char field[19];
    uint8_t i = segment;
    const char *label = &reel_segment_labels[0][0];
    /* Keep the ROM-table walk explicit. This avoids relying on target
       lowering of a variable-indexed pointer-to-array multiplication. */
    while (i--) label += 19u;
    i = 0u;
    while (i != 18u) {
      field[i] = *label ? *label++ : ' ';
      ++i;
    }
    field[18] = 0;
    video_hud_text(25u, 1u, field);
  }
#else
  video_hud_text(25u, 1u, "SVX2 VIDEO         ");
#endif
}

enum {
  TRANSPORT_PLAY = 0u,
  TRANSPORT_PAUSE = 1u,
  TRANSPORT_STEP = 2u,
  TRANSPORT_REVERSE = 3u,
  TRANSPORT_FORWARD = 4u
};

static uint8_t is_keyframe(uint16_t frame) {
  return frame == 0u;
}

static uint16_t wrapped_frame(int16_t frame) {
  while (frame < 0) frame = (int16_t)(frame + VIDEO_REEL_FRAME_COUNT);
  while (frame >= VIDEO_REEL_FRAME_COUNT) frame = (int16_t)(frame - VIDEO_REEL_FRAME_COUNT);
  return (uint16_t)frame;
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
  if (transport_visible) return;
  video_hud_text(26u, 6u, line);
  video_hud_text(26u, 27u, video_fps_text);
  if (video_reel_result != 0u && video_reel_result != 0xffu)
    video_hud_text(25u, 25u, "ERROR  ");
  else if (video_reel_deadline_slips)
    video_hud_text(25u, 25u, "SLIP   ");
}

static void dashboard_normal(void) {
  video_hud_line(25u, "                           PLAY ");
  video_hud_line(26u, " TIME                  FPS     ");
  transport_visible = 0u;
  dashboard_segment(video_reel_frame, 1u);
  update_dashboard_fields();
  video_hud_flush();
}

static void transport_draw(uint8_t state, uint8_t rate) {
  char top[33], bottom[33];
  char *p;
  uint8_t i;
  uint8_t marker = (uint8_t)(((uint32_t)video_reel_frame * 19u) /
                             (VIDEO_REEL_FRAME_COUNT - 1u));
  for (i = 0u; i != 32u; ++i) top[i] = bottom[i] = ' ';
  top[32] = bottom[32] = 0;
  p = top;
  if (state == TRANSPORT_PAUSE) { *p++='P';*p++='A';*p++='U';*p++='S';*p++='E'; }
  else if (state == TRANSPORT_STEP) { *p++='S';*p++='T';*p++='E';*p++='P'; }
  else if (state == TRANSPORT_REVERSE) { *p++='R';*p++='E';*p++='V';*p++=' ';*p++=(char)('0'+rate);*p++='X'; }
  else if (state == TRANSPORT_FORWARD) { *p++='F';*p++='W';*p++='D';*p++=' ';*p++=(char)('0'+rate);*p++='X'; }
  else { *p++='P';*p++='L';*p++='A';*p++='Y'; }
  top[8] = '<'; top[29] = '>';
  for (i = 0u; i != 20u; ++i) top[9u+i] = i == marker ? '|' : (i < marker ? '=' : '-');
  p = bottom;
  p = decimal(p, (uint16_t)(video_reel_frame / (VIDEO_REEL_SOURCE_FPS * 60u)), 2u); *p++ = ':';
  p = decimal(p, (uint16_t)((video_reel_frame / VIDEO_REEL_SOURCE_FPS) % 60u), 2u); *p++ = '.';
  *p++ = (char)('0' + ((video_reel_frame % VIDEO_REEL_SOURCE_FPS) * 10u) /
                       VIDEO_REEL_SOURCE_FPS);
  *p++ = ' '; *p++ = '/'; *p++ = ' '; *p++ = '0'; *p++ = '0'; *p++ = ':';
  p = decimal(p, (uint16_t)(VIDEO_REEL_FRAME_COUNT / VIDEO_REEL_SOURCE_FPS), 2u); *p++ = '.'; *p++ = '0';
  bottom[25] = 'F';
  p = &bottom[27]; decimal(p, video_reel_frame, 4u);
  video_hud_line(25u, top);
  video_hud_line(26u, bottom);
  video_hud_flush();
  transport_visible = 1u;
  transport_hide = state == TRANSPORT_PLAY ? 90u : 0u;
}

/* Formats the dashboard during active display -- VBlank is too short for
   formatting plus both HUD and full-frame video DMA at 60 packets/s. The rate
   itself is sampled by video_fps_sample() AFTER the present, not here: this
   function used to do both, and got the right answer only because sampling one
   VBlank early cancelled reading the presented counter one frame early. Apollo
   inherited that pair, moved this call, and shipped 59.1/60.1 to a live page. */
static void dashboard_prepare(uint16_t frame, uint8_t looped) {
  if (looped) {
    dashboard_frame_tick = 0u;
    dashboard_seconds = 0u;
    dashboard_minutes = 0u;
    if (frame == 0u) video_reel_time_reset_gate = 0xa5u;
  } else if (++dashboard_frame_tick == VIDEO_REEL_SOURCE_FPS) {
    dashboard_frame_tick = 0u;
    if (dashboard_minutes != 99u || dashboard_seconds != 59u) {
      if (++dashboard_seconds == 60u) {
        dashboard_seconds = 0u;
        ++dashboard_minutes;
      }
    }
  }
  dashboard_segment(frame, 0u);
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

static uint8_t reel_stream_bank(uint32_t offset) {
#ifdef VIDEO_REEL_EXHIROM
  /* File bank $C0 is a FastROM mirror of the linked $40 boot/code window.
     Stream offset zero therefore begins at file $010000 / bank $C1.  Its
     continuation skips file $400000-$40FFFF (boot/header) and resumes at
     file $410000 / bank $41.  All boundaries are bank aligned, so the low
     16 address bits remain the logical stream offset's low bits. */
  if (offset >= 0x3f0000ul)
    return (uint8_t)(0x41u + (uint8_t)((offset - 0x3f0000ul) >> 16));
#endif
  return (uint8_t)(VIDEO_REEL_HIROM_BASE_BANK + (uint8_t)(offset >> 16));
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
        reel_stream_bank(offset), address,
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

#ifdef VIDEO_REEL_SEEK_COUNT
static uint8_t stage_seek_keyframe(uint8_t index) {
  SvcSnesDmaContext context = {3u, 1u};
  uint32_t offset = reel_seek_packet_offsets[index];
  uint16_t remaining = (uint16_t)(reel_seek_packet_offsets[index + 1u] - offset);
  uint16_t copied = 0u;
  while (remaining) {
    uint16_t address = (uint16_t)offset;
    uint16_t segment = (uint16_t)(0u - address);
    if (!segment || segment > remaining) segment = remaining;
    if (!svc_snes_dma_copy_segment(&context,
        reel_stream_bank(offset), address,
        (uint8_t *)(uintptr_t)(STAGE_ADDRESS + copied), segment)) return 0u;
    offset += segment;
    copied = (uint16_t)(copied + segment);
    remaining = (uint16_t)(remaining - segment);
  }
  return 1u;
}
#endif

#ifdef VIDEO_REEL_LOOP_DELTA
static uint8_t stage_loop_delta(void) {
  SvcSnesDmaContext context = {3u, 1u};
  uint32_t offset = VIDEO_REEL_LOOP_PACKET_OFFSET;
  uint16_t remaining = VIDEO_REEL_LOOP_PACKET_SIZE;
  uint16_t copied = 0u;
  while (remaining) {
    uint16_t address = (uint16_t)offset;
    uint16_t segment = (uint16_t)(0u - address);
    if (!segment || segment > remaining) segment = remaining;
    if (!svc_snes_dma_copy_segment(&context,
        reel_stream_bank(offset), address,
        (uint8_t *)(uintptr_t)(STAGE_ADDRESS + copied), segment)) return 0u;
    offset += segment;
    copied = (uint16_t)(copied + segment);
    remaining = (uint16_t)(remaining - segment);
  }
  return 1u;
}
#endif

static void decode_frame(uint16_t frame) {
#ifdef VIDEO_REEL_PROFILE
  VideoReelStamp begin = profile_stamp();
  VideoReelStamp staged;
#endif
  if (!stage_frame(frame)) stop(1u);
#ifdef VIDEO_REEL_PROFILE
  staged = profile_stamp();
#endif
  svx_decode_payload_wram_fast((uint16_t)(STAGE_ADDRESS + 9u), is_keyframe(frame),
                               framebuffer, framebuffer);
#ifdef VIDEO_REEL_PROFILE
  video_reel_profile[frame].stage_q1024 = profile_quantize(profile_elapsed(begin, staged));
  video_reel_profile[frame].decode_q1024 =
      profile_quantize(profile_elapsed(staged, profile_stamp()));
  if (video_reel_profile_samples != VIDEO_REEL_FRAME_COUNT) ++video_reel_profile_samples;
#endif
  ++video_reel_decoded;
}

static void decode_sequential_frame(uint16_t frame) {
#ifdef VIDEO_REEL_LOOP_DELTA
  if (frame == 0u) {
#ifdef VIDEO_REEL_PROFILE
    VideoReelStamp begin = profile_stamp();
    VideoReelStamp staged;
#endif
    if (!stage_loop_delta()) stop(1u);
#ifdef VIDEO_REEL_PROFILE
    staged = profile_stamp();
#endif
    svx_decode_payload_wram_fast((uint16_t)(STAGE_ADDRESS + 9u), 0u,
                                 framebuffer, framebuffer);
#ifdef VIDEO_REEL_PROFILE
    video_reel_profile[0].stage_q1024 = profile_quantize(profile_elapsed(begin, staged));
    video_reel_profile[0].decode_q1024 =
        profile_quantize(profile_elapsed(staged, profile_stamp()));
#endif
    ++video_reel_decoded;
    return;
  }
#endif
  decode_frame(frame);
}

static void seek_frame(uint16_t destination) {
  uint16_t frame;
#ifdef VIDEO_REEL_SEEK_INTERVAL
  frame = (uint16_t)(destination - destination % VIDEO_REEL_SEEK_INTERVAL);
  if (!stage_seek_keyframe((uint8_t)(frame / VIDEO_REEL_SEEK_INTERVAL))) stop(1u);
  svx_decode_payload_wram_fast((uint16_t)(STAGE_ADDRESS + 9u), 1u, framebuffer, framebuffer);
  ++video_reel_decoded;
  video_reel_seek_decode_count = 1u;
  if (frame == destination) return;
#else
#ifdef VIDEO_REEL_SECOND_START
  frame = destination >= VIDEO_REEL_SECOND_START ? VIDEO_REEL_SECOND_START : 0u;
#else
  frame = 0u;
#endif
  decode_frame(frame);
  video_reel_seek_decode_count = 1u;
  if (frame == destination) return;
#endif
  while (frame != destination) {
    ++frame;
    decode_frame(frame);
    ++video_reel_seek_decode_count;
  }
}

static void present_frame(uint16_t frame) {
#ifdef VIDEO_REEL_PROFILE
  VideoReelStamp begin = profile_stamp();
#endif
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
#ifdef VIDEO_REEL_PROFILE
  video_reel_profile[frame].present_q1024 =
      profile_quantize(profile_elapsed(begin, profile_stamp()));
#endif
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
  dashboard_normal();
}

static void wait_vblank_fresh(void) {
  (void)REG_RDNMI;
  snes_wait_vblank();
}

static uint8_t transport_seek(int16_t delta, uint8_t state, uint8_t rate) {
  uint16_t destination = wrapped_frame((int16_t)video_reel_frame + delta);
  seek_frame(destination);
  wait_vblank_fresh();
  present_frame(destination);
  video_reel_frame = destination;
  dashboard_segment(destination, 0u);
  video_reel_transport_state = state;
  video_reel_transport_rate = rate;
  transport_draw(state, rate);
  return 1u;
}

static uint8_t transport_poll(void) {
  uint16_t pad = snes_read_pad1_auto();
  uint16_t pressed = (uint16_t)(pad & (uint16_t)~transport_pad_previous);
  uint8_t changed = 0u;
  transport_pad_previous = pad;
  if (pressed & JOY_START) {
    video_reel_transport_state = video_reel_transport_state == TRANSPORT_PLAY
        ? TRANSPORT_PAUSE : TRANSPORT_PLAY;
    video_reel_transport_rate = 0u;
    transport_draw(video_reel_transport_state, 0u);
    changed = 1u;
  } else if (pressed & JOY_A) {
    video_reel_transport_state = TRANSPORT_PLAY;
    video_reel_transport_rate = 0u;
    transport_draw(TRANSPORT_PLAY, 0u);
    changed = 1u;
  } else if (pressed & JOY_L) {
    video_reel_transport_state = TRANSPORT_PAUSE;
    changed = transport_seek(-1, TRANSPORT_STEP, 0u);
  } else if (pressed & JOY_R) {
    video_reel_transport_state = TRANSPORT_PAUSE;
    changed = transport_seek(1, TRANSPORT_STEP, 0u);
  }
  if ((pad & (JOY_LEFT | JOY_RIGHT)) == (JOY_LEFT | JOY_RIGHT)) {
    transport_hold = 0u;
  } else if (pad & (JOY_LEFT | JOY_RIGHT)) {
    uint8_t rate;
    int16_t delta;
    if (transport_hold == 0u)
      transport_resume = video_reel_transport_state == TRANSPORT_PLAY;
    if (transport_hold != 255u) ++transport_hold;
    rate = transport_hold >= 60u ? 8u : transport_hold >= 30u ? 4u : 2u;
    /* A tap is exactly one authored second at either cadence.  Once held,
       advance the advertised 2/4/8 source frames per transport tick. */
    delta = transport_hold == 1u ? (int16_t)VIDEO_REEL_SOURCE_FPS : (int16_t)rate;
    if (pad & JOY_LEFT) delta = (int16_t)-delta;
    changed = transport_seek(delta,
        (pad & JOY_LEFT) ? TRANSPORT_REVERSE : TRANSPORT_FORWARD, rate);
  } else {
    if (transport_hold) {
      video_reel_transport_state = transport_resume ? TRANSPORT_PLAY : TRANSPORT_PAUSE;
      video_reel_transport_rate = 0u;
      transport_draw(video_reel_transport_state, 0u);
      changed = 1u;
    }
    transport_hold = 0u;
  }
  if (video_reel_transport_state == TRANSPORT_PLAY && transport_visible && transport_hide) {
    if (--transport_hide == 0u) dashboard_normal();
  }
  return changed;
}

void video_reel_run(void) {
  uint16_t frame;
  uint16_t deadline;
  snes_ppu_reset_blank();
  video_reel_result = 0xffu;
  video_reel_loop_gate = 0xffu;
  video_reel_deadline_slips = 0u;
  video_reel_transport_state = TRANSPORT_PLAY;
  video_reel_transport_rate = 0u;
  video_reel_seek_decode_count = 0u;
  video_reel_segment = 0xffu;
  video_reel_segment_gate = 0xffu;
  video_reel_time_reset_gate = 0xffu;
  video_reel_composite_health = 0xfffffffful;

  /* Exercise the stream boundaries behind a short animated introduction. */
#if VIDEO_REEL_VBLANKS_PER_FRAME == 1u
  m7splash_begin("FASTROM 60 TEST", "SVX2 VIDEO");
#else
  m7splash_begin("FASTROM 30 FPS", "SVX2 VIDEO");
#endif

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
  seek_frame(VIDEO_REEL_SECOND_START);
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
  REG_NMITIMEN = NMITIMEN_NMI | NMITIMEN_AUTOJOY;
  wait_vblank_fresh();
  present_frame(0u);
  deadline = (uint16_t)video_reel_vblanks + VIDEO_REEL_VBLANKS_PER_FRAME;
  video_reel_frame = 0u;
  video_reel_result = 0u;
  video_fps_reset((uint16_t)video_reel_presented_total,
                  (uint16_t)video_reel_vblanks);
  dashboard_frame_tick = 1u;
  dashboard_seconds = 0u;
  dashboard_minutes = 0u;
  update_dashboard_fields();
  m7_show();

  for (;;) {
    uint8_t palette_cut;
    uint8_t looped;
    if (transport_poll())
      deadline = (uint16_t)video_reel_vblanks + VIDEO_REEL_VBLANKS_PER_FRAME;
    if (video_reel_transport_state != TRANSPORT_PLAY) {
      uint16_t now = (uint16_t)video_reel_vblanks;
      while ((uint16_t)video_reel_vblanks == now) __asm__ volatile("wai");
      continue;
    }
    frame = (uint16_t)(video_reel_frame + 1u);
    looped = frame == VIDEO_REEL_FRAME_COUNT;
    if (looped) frame = 0u;
#ifdef VIDEO_REEL_SECOND_PALETTE
    palette_cut = frame == VIDEO_REEL_SECOND_START || frame == 0u;
#else
    palette_cut = 0u;
#endif
    decode_sequential_frame(frame);
    /* Format the next dashboard during active display. VBlank is too short
       for formatting plus both HUD and full-frame video DMA at 60 packets/s. */
    dashboard_prepare(frame, looped);
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
    video_reel_frame = frame;
    /* Upload the small dashboard first. The full 4,480-byte video DMA uses
       nearly the rest of the VBlank budget; HUD writes after it are too late
       on real timing and were intermittently ignored by the PPU. */
    video_hud_flush();
    present_frame(frame);
    /* AFTER the present: presented_total must already include the frame just
       sent. See video_fps.h for what breaks when it does not. */
    video_fps_sample((uint16_t)video_reel_presented_total,
                     (uint16_t)video_reel_vblanks);
    if (transport_visible)
      transport_draw(video_reel_transport_state, video_reel_transport_rate);
    deadline = (uint16_t)(deadline + VIDEO_REEL_VBLANKS_PER_FRAME);
    if (frame == 0u) {
      static uint8_t loops;
      if (++loops >= 2u) {
        video_reel_loop_gate = 0u;
        video_reel_composite_health = (uint32_t)video_reel_result |
            ((uint32_t)video_reel_crc_failures << 8) |
            ((uint32_t)video_reel_deadline_slips << 16);
      }
    }
  }
}

extern void video_reel_enter_fast(void);

int main(void) {
  REG_MEMSEL = MEMSEL_FASTROM;
  video_reel_enter_fast();
  return 0;
}
