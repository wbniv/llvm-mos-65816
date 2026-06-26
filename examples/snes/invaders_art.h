/* Space Invaders sprite art — linked from ROM, NOT a compiled C array (Option B).
 *
 * dev/build.sh objcopies the committed examples/snes/invaders.{pic,pal} (raw gfx4snes output) into
 * bank-$00 .rodata objects with `_binary_invaders_<ext>_*` symbols and links them with invaders.c.
 * Regenerate the binaries from art/invaders/sprites.png via dev/gen-invaders-art.sh (needs gfx4snes
 * from the foundry pvsneslib-core). This header is the thin, hand-written glue (no generated array).
 *
 *   invaders.pic : 16 tiles x 32 B 4bpp (cells 0..9 = squidA,squidB,crabA,crabB,octoA,octoB,
 *                  player,bullet,bomb,ufo — matching the T_* enum in invaders.c)
 *   invaders.pal : 16-colour BGR555 sprite palette (-> CGRAM 128, group 0)
 */
#ifndef INVADERS_ART_H
#define INVADERS_ART_H

#include <stdint.h>

extern const uint8_t _binary_invaders_pic_start[];
extern const uint8_t _binary_invaders_pic_end[];
extern const uint8_t _binary_invaders_pic_size[];   /* ABS symbol: its ADDRESS is the byte count */
extern const uint8_t _binary_invaders_pal_start[];
extern const uint8_t _binary_invaders_pal_end[];
extern const uint8_t _binary_invaders_pal_size[];

#define INV_TILES      _binary_invaders_pic_start
#define INV_TILES_LEN  ((uint16_t)(uintptr_t)_binary_invaders_pic_size)
#define INV_PAL        _binary_invaders_pal_start
#define INV_PAL_LEN    ((uint16_t)(uintptr_t)_binary_invaders_pal_size)

#endif /* INVADERS_ART_H */
