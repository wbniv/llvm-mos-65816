/* snesgfx — UploadQueue: the v-blank/force-blank-gated DMA upload queue.
 *
 * INTERNAL collaborator (owned by Display). THE access-window rule lives here and nowhere
 * else: VRAM/CGRAM/OAM are writable only during force-blank or v-blank (handoff §1/§2).
 * Clients (drawables) ENQUEUE typed jobs whenever; upq_flush() runs them all via DMA and is
 * the only code that touches the PPU data ports — and Display only calls it inside a v-blank.
 *
 * Header-only (static inline). Built on the snes.h HAL (DMA + PPU register map). */
#ifndef SNESGFX_UPLOAD_H
#define SNESGFX_UPLOAD_H

#include <snes.h>

#ifndef UPQ_MAX_JOBS
#define UPQ_MAX_JOBS 16
#endif

/* A queued DMA upload. `port` selects which destination-address register to load first.
   UPQ_REG is the odd one out: not a DMA, just a write-twice register poke (scroll latches)
   carried in the queue so it lands in the v-blank window like everything else. */
enum { UPQ_VRAM = 0, UPQ_CGRAM = 1, UPQ_OAM = 2, UPQ_REG = 3 };

typedef struct {
  uint16_t dest;     /* VRAM word addr / CGRAM index / OAM byte addr */
  uint16_t src;      /* A-bus source address (low 16 bits)          */
  uint16_t nbytes;   /* transfer length (0 rejected — DAS=0 = 64KiB) */
  uint8_t  src_bank; /* A-bus source bank                            */
  uint8_t  bbad;     /* B-bus dest: BBAD_VMDATA / BBAD_CGDATA / BBAD_OAMDATA */
  uint8_t  dmap;     /* DMAP_* (direction | step | unit)             */
  uint8_t  vmain;    /* VRAM only: VMAIN value; ignored otherwise    */
  uint8_t  port;     /* UPQ_VRAM / UPQ_CGRAM / UPQ_OAM               */
} UpqJob;

typedef struct {
  UpqJob  job[UPQ_MAX_JOBS];
  uint8_t n;
  uint8_t chan;      /* GP-DMA channel (0..7) */
} UploadQueue;

static inline void upq_init(UploadQueue *q, uint8_t chan) { q->n = 0; q->chan = chan; }

/* Enqueue a VRAM character/tilemap upload to word address `destword`. `vmain` picks the
   auto-increment (VMAIN_INC_HIGH_1 for the usual word stream via $2118/$2119). */
static inline void upq_push_vram(UploadQueue *q, uint16_t destword, const void *src,
                                 uint8_t bank, uint16_t nbytes, uint8_t vmain) {
  if (!nbytes || q->n >= UPQ_MAX_JOBS) return;
  UpqJob *j = &q->job[q->n++];
  j->port = UPQ_VRAM; j->dest = destword; j->vmain = vmain;
  j->bbad = BBAD_VMDATA; j->dmap = (uint8_t)(DMAP_TO_PPU | DMAP_ADDR_INC | DMAP_UNIT_2);
  j->src = (uint16_t)(uintptr_t)src; j->src_bank = bank; j->nbytes = nbytes;
}

/* Enqueue a CGRAM palette upload starting at colour index `cgidx`. */
static inline void upq_push_cgram(UploadQueue *q, uint8_t cgidx, const void *src,
                                  uint8_t bank, uint16_t nbytes) {
  if (!nbytes || q->n >= UPQ_MAX_JOBS) return;
  UpqJob *j = &q->job[q->n++];
  j->port = UPQ_CGRAM; j->dest = cgidx; j->vmain = 0;
  j->bbad = BBAD_CGDATA; j->dmap = (uint8_t)(DMAP_TO_PPU | DMAP_ADDR_INC | DMAP_UNIT_1);
  j->src = (uint16_t)(uintptr_t)src; j->src_bank = bank; j->nbytes = nbytes;
}

/* Enqueue an OAM upload (typically the whole 544-byte shadow from byte 0). */
static inline void upq_push_oam(UploadQueue *q, const void *src, uint8_t bank, uint16_t nbytes) {
  if (!nbytes || q->n >= UPQ_MAX_JOBS) return;
  UpqJob *j = &q->job[q->n++];
  j->port = UPQ_OAM; j->dest = 0; j->vmain = 0;
  j->bbad = BBAD_OAMDATA; j->dmap = (uint8_t)(DMAP_TO_PPU | DMAP_ADDR_INC | DMAP_UNIT_1);
  j->src = (uint16_t)(uintptr_t)src; j->src_bank = bank; j->nbytes = nbytes;
}

/* Enqueue a write-twice PPU register poke — the BGnHOFS/BGnVOFS scroll latches ($210D..$2114).
   It is applied inside upq_flush() (the v-blank/force-blank window), NOT during active display:
   a scroll register written mid-frame shears the picture from that scanline down. `value`'s low
   byte then high byte are written to the register at address `reg` (e.g. &REG_BG3VOFS). */
static inline void upq_push_scroll(UploadQueue *q, uint16_t reg, uint16_t value) {
  if (q->n >= UPQ_MAX_JOBS) return;
  UpqJob *j = &q->job[q->n++];
  j->port = UPQ_REG; j->dest = reg; j->src = value; j->nbytes = 0;
}

/* Run every queued job via DMA, then empty the queue. MUST be called in force-blank or
   v-blank (Display guarantees this). The CPU stalls on each MDMAEN until the copy completes.
   dma_base and mdmaen_bit are hoisted out of the loop so the 65816 never recomputes
   chan*0x10 or 1<<chan on every iteration (those are variable-cost ops). */
static inline void upq_flush(UploadQueue *q) {
  volatile uint8_t *dma_base =
    (volatile uint8_t *)(uintptr_t)(0x4300u + (uint16_t)q->chan * 0x10u);
  uint8_t mdmaen_bit = (uint8_t)(1u << q->chan);
  for (uint8_t i = 0; i < q->n; i++) {
    const UpqJob *j = &q->job[i];
    if (j->port == UPQ_REG) {       /* write-twice register poke (scroll latch) — not a DMA */
      volatile uint8_t *r = (volatile uint8_t *)(uintptr_t)j->dest;
      *r = (uint8_t)j->src;          /* low byte  */
      *r = (uint8_t)(j->src >> 8);   /* high byte */
      continue;
    }
    if (j->port == UPQ_VRAM)       { REG_VMAIN = j->vmain; REG_VMADD = j->dest; }
    else if (j->port == UPQ_CGRAM) { REG_CGADD = (uint8_t)j->dest; }
    else                           { REG_OAMADDL = (uint8_t)j->dest; REG_OAMADDH = (uint8_t)(j->dest >> 8); }
    dma_base[0] = j->dmap;
    dma_base[1] = j->bbad;
    dma_base[2] = (uint8_t)j->src;
    dma_base[3] = (uint8_t)(j->src >> 8);
    dma_base[4] = j->src_bank;
    dma_base[5] = (uint8_t)j->nbytes;
    dma_base[6] = (uint8_t)(j->nbytes >> 8);
    REG_MDMAEN = mdmaen_bit;
  }
  q->n = 0;
}

#endif /* SNESGFX_UPLOAD_H */
