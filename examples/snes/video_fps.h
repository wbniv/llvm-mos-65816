/* The on-screen frame-rate gauge, shared by every video cartridge that draws one.
 *
 * WHY THIS IS A COMPONENT AND NOT FOUR LINES INLINE
 * -------------------------------------------------
 * It used to be four lines inline, copied between ROMs, and that is exactly how
 * it broke. The sampler must read the presented-frame counter AFTER the present
 * it is counting; snes-video-reel.c read it before, and got the right answer
 * anyway because it also sampled the VBlank counter one frame early, so two
 * off-by-ones cancelled. apollo-reel.c was copied from it, moved the call after
 * the deadline wait for a good and unrelated reason (formatting must not
 * straddle the wait), and the cancellation silently broke: the shipped cartridge
 * displayed 59.1 for its first window and then 60.1 forever.
 *
 * So the contract is stated once, here, and both ROMs obey it:
 *
 *   video_fps_reset()  immediately after the FIRST present_frame()
 *   video_fps_sample() every frame, AFTER present_frame() -- never before
 *
 * UNITS
 * -----
 * Presented frames per 600 VBlanks, displayed with one decimal. This is
 * deliberately the same measurement the build gates' cadence tables publish, so
 * the number on the screen and the number in the docs cannot disagree. One frame
 * per VBlank reads "60.0"; a 2-VBlank cadence reads "30.0".
 *
 * Scaling by the true NTSC VBlank rate (60.0988 Hz) instead -- which is what
 * apollo-reel.c's stray 601 did -- is arithmetically honest and the wrong number
 * to show: one frame per VBlank really is 60.1 presents per wall second, and it
 * invites "why does the 59.94 fps demo say 60.1?" from every viewer forever. The
 * source rate is a property of the source; this gauge measures the presentation.
 *
 * "00.0" BEFORE THE FIRST WINDOW CLOSES IS DELIBERATE
 * ---------------------------------------------------
 * It means "not measured yet" and lasts about a second. Seeding the gauge with a
 * plausible number the ROM has not measured is the decorative-gauge failure mode
 * this project keeps catching; a gauge that cannot read wrong proves nothing.
 */
#ifndef VIDEO_FPS_H
#define VIDEO_FPS_H
#include <stdint.h>

/* Sample window. 60 VBlanks is one NTSC second, which is also the shortest
   window that resolves a single dropped frame as one tenth. */
#define VIDEO_FPS_WINDOW_VBLANKS 60u
/* Frames per this many VBlanks == the displayed value, x10. */
#define VIDEO_FPS_SCALE 600u

static char video_fps_text[5] = "00.0";
/* Volatile and separate from the string: this is what a build gate reads out of
   WRAM to assert the gauge, which nothing did until the 59.1/60.1 defect. */
static volatile uint16_t video_fps_tenths;

static uint16_t video_fps_presented_mark;
static uint16_t video_fps_vblank_mark;

/* Call once, immediately after the first present_frame(), with the same two
   counters that will be passed to video_fps_sample() thereafter. */
static inline void video_fps_reset(uint16_t presented, uint16_t vblank) {
  video_fps_presented_mark = presented;
  video_fps_vblank_mark = vblank;
  video_fps_tenths = 0u;
  video_fps_text[0] = '0';
  video_fps_text[1] = '0';
  video_fps_text[3] = '0';
}

/* Call every frame, AFTER present_frame(). `presented` must already include the
   frame just sent -- that is the whole point. Cheap: a subtract and a compare on
   every frame, the divide only once per window. */
static inline void video_fps_sample(uint16_t presented, uint16_t vblank) {
  uint16_t dv = (uint16_t)(vblank - video_fps_vblank_mark);
  if (dv >= VIDEO_FPS_WINDOW_VBLANKS) {
    uint16_t dp = (uint16_t)(presented - video_fps_presented_mark);
    /* 32-bit intermediate: a transport that pauses or single-steps can leave a
       long window behind, and dp * 600 overflows 16 bits past dp = 109. The
       divide runs once per window, so the width costs nothing that matters. */
    uint16_t measured = (uint16_t)(((uint32_t)dp * VIDEO_FPS_SCALE + dv / 2u) / dv);
    if (measured > 999u) measured = 999u;   /* three digits, never garbled */
    video_fps_tenths = measured;
    video_fps_text[0] = (char)('0' + measured / 100u);
    measured %= 100u;
    video_fps_text[1] = (char)('0' + measured / 10u);
    video_fps_text[3] = (char)('0' + measured % 10u);
    video_fps_presented_mark = presented;
    video_fps_vblank_mark = vblank;
  }
}

#endif /* VIDEO_FPS_H */
