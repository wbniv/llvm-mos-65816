// examples/65816/seamdemo_atlas.h — Act 3's atlas flyover traversal, shared by
// the SNES ROM and the host harness.
//
// One 64x64 8bpp data page + a 16x16 heightmap + self-describing metadata per
// 32 KiB slot, so the atlas spans the whole 6 MiB cartridge. A scripted
// boustrophedon camera sweeps every available page; the fold takes, per sample,
// the page index, the texel under the camera, the height sample under it, and
// the page metadata's first byte (the low byte of the page's own file offset,
// which is what catches a mis-decoded page).
//
// The path is SCRIPTED, not data-driven -- this is a camera, not a walk -- so it
// is regenerated identically here, in the Python oracle and in the generator from
// four numbers plus the reserved-slot skip list. Only the DATA it reads comes off
// the cartridge.
//
// The includer must define, before including:
//   SEAMATLAS_FILE8(off)  -> uint8_t, read one cartridge byte at a FILE offset
//   SEAMATLAS_PAGE(ctx, slot)  -> void, called once when the camera enters a new
//                                 page (the ROM streams its texture to VRAM here)
// and must have included the generated seamdemo-data.h and seamdemo_vm.h (for
// seamvm_fold).
//
// Traversal order is the contract the Python oracle's run_act3() already computes
// SEAMDEMO_ACT3_CRC for.
#ifndef SEAMDEMO_ATLAS_H
#define SEAMDEMO_ATLAS_H

#include <stdint.h>

#ifndef SEAMDEMO_VM_H
#error "include seamdemo_vm.h before seamdemo_atlas.h (seamvm_fold lives there)"
#endif
#ifndef SEAMATLAS_FILE8
#error "define SEAMATLAS_FILE8(off) before including seamdemo_atlas.h"
#endif
#ifndef SEAMATLAS_PAGE
#define SEAMATLAS_PAGE(ctx, slot) ((void)0)
#endif

#define SEAMATLAS_ST_CRC 0x0400u    // the sweep folded to something other than the oracle
#define SEAMATLAS_ST_PAGES 0x0800u  // the sweep did not visit every available page

typedef struct {
  uint16_t crc;
  uint16_t slot;      // page currently under the camera
  uint16_t samples;   // samples taken so far
  uint16_t pages;     // distinct pages entered
  uint16_t status;
  uint8_t gx, gy;     // page's grid position
  uint8_t u, v;       // texel under the camera, within the page
  uint8_t k;          // sample index within the page
  uint8_t right;      // sweep direction on this grid row
  uint8_t done;
} SeamAtlas;

// Is this slot reserved (linked code / the far arena)? The skip list is generated
// from the same model that reserved them.
static uint8_t seamatlas_skipped(uint16_t slot) {
  for (uint8_t i = 0; i < SEAMDEMO_ACT3_SKIP_COUNT; i++)
    if (seamdemo_act3_skip[i] == slot) return 1;
  return 0;
}

// Advance (gx, gy) to the next page the boustrophedon sweep should visit.
// Returns 0 when the sweep is finished.
static uint8_t seamatlas_next_page(SeamAtlas *a) {
  for (;;) {
    if (a->right) {
      if (a->gx + 1u < SEAMDEMO_GRID_W) {
        a->gx++;
      } else {
        // End of a rightward row: the next row runs LEFTWARD and therefore
        // starts at the last column, not one step back from it.
        a->gy++;
        a->right = 0;
        a->gx = (uint8_t)(SEAMDEMO_GRID_W - 1u);
      }
    } else {
      if (a->gx > 0u) {
        a->gx--;
      } else {
        a->gy++;
        a->right = 1;
        a->gx = 0;
      }
    }
    if (a->gy >= SEAMDEMO_GRID_H) return 0;
    uint16_t slot = (uint16_t)((uint16_t)a->gy * SEAMDEMO_GRID_W + a->gx);
    if (slot < SEAMDEMO_SLOTS && !seamatlas_skipped(slot)) {
      a->slot = slot;
      return 1;
    }
  }
}

static void seamatlas_init(SeamAtlas *a) {
  a->crc = 0;
  a->samples = 0;
  a->pages = 0;
  a->k = 0;
  a->done = 0;
  a->gx = 0;
  a->gy = 0;
  a->right = 1;
  a->slot = 0;
  // Row 0 sweeps right from gx = 0; if slot 0 itself is reserved, walk forward
  // to the first page that is not.
  if (seamatlas_skipped(0) || SEAMDEMO_SLOTS == 0) {
    if (!seamatlas_next_page(a)) a->done = 1;
  }
  a->u = 2;
  a->v = (uint8_t)((0u * 13u + 0u * 7u) & (SEAMDEMO_TEX_H - 1u));
  // `status` is deliberately NOT cleared -- it accumulates across a lap.
}

// Take one sample. The ROM calls SEAMATLAS_PAGE once per page entry to stream
// that page's texture into Mode 7 character memory.
__attribute__((noinline)) static void seamatlas_step(SeamAtlas *a, void *ctx) {
  (void)ctx;
  if (a->done) return;

  if (a->k == 0) {
    a->pages++;
    SEAMATLAS_PAGE(ctx, a->slot);
  }

  // The sample's texel, exactly as act3_path() computes it.
  a->u = a->right ? (uint8_t)(a->k * 4u + 2u)
                  : (uint8_t)(SEAMDEMO_TEX_W - 2u - a->k * 4u);
  a->v = (uint8_t)(((uint16_t)a->gy * 13u + (uint16_t)a->k * 7u) & (SEAMDEMO_TEX_H - 1u));

  const unsigned long base = (unsigned long)a->slot * (unsigned long)SEAMDEMO_SLOT;
  a->crc = seamvm_fold(a->crc, (uint8_t)(a->slot & 0xFFu));
  a->crc = seamvm_fold(a->crc, (uint8_t)(a->slot >> 8));
  a->crc = seamvm_fold(a->crc,
                       SEAMATLAS_FILE8(base + SEAMDEMO_DATA_OFF
                                       + (unsigned long)a->v * SEAMDEMO_TEX_W + a->u));
  a->crc = seamvm_fold(a->crc,
                       SEAMATLAS_FILE8(base + SEAMDEMO_HGT_OFF
                                       + (unsigned long)(a->v >> 2) * SEAMDEMO_HGT_W
                                       + (a->u >> 2)));
  a->crc = seamvm_fold(a->crc, SEAMATLAS_FILE8(base + SEAMDEMO_META_OFF));
  a->samples++;

  a->k++;
  if (a->k >= SEAMDEMO_SAMPLES_PER_PAGE) {
    a->k = 0;
    if (!seamatlas_next_page(a)) a->done = 1;
  }
}

static uint16_t seamatlas_final_crc(const SeamAtlas *a) { return a->crc; }

#endif /* SEAMDEMO_ATLAS_H */
