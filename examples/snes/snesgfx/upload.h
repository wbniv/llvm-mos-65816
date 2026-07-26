/* snesgfx — UploadQueue: the v-blank-gated DMA upload queue.
 *
 * INTERNAL collaborator (owned by Display). THE access-window rule lives here and nowhere
 * else: VRAM/CGRAM/OAM are writable only during v-blank (or force-blank, which snesgfx uses
 * exactly once, at boot — see display.h). Clients (drawables) ENQUEUE typed jobs whenever;
 * upq_flush() runs them via DMA and is the only code that touches the PPU data ports — and
 * Display only calls it inside a v-blank, spending at most UPQ_VBLANK_BUDGET bytes there.
 *
 * Header-only (static inline). Built on the snes.h HAL (DMA + PPU register map). */
#ifndef SNESGFX_UPLOAD_H
#define SNESGFX_UPLOAD_H

#include <snes.h>

#ifndef UPQ_MAX_JOBS
#define UPQ_MAX_JOBS 16
#endif

/* Bytes of DMA that fit in ONE NTSC v-blank, and therefore the hard cap on what a single flush may
 * transfer. 38 v-blank lines x 1364 master cycles = 51,832; GP-DMA moves a byte per 8 master
 * cycles = 6,479 B theoretical; ~20% is reserved for per-job register setup and for the fact that
 * the flush does not begin exactly at the first v-blank cycle.
 *
 * This is a CORRECTNESS limit, not a performance tweak. snesgfx used to force-blank around the
 * flush so an over-long transfer could not be rejected — but a force-blank released after v-blank
 * has ended blanks the top scanlines of the picture, which is a visible flicker. With that removed,
 * the queue must instead stay inside the window on its own: upq_flush spends at most this many
 * bytes and leaves the remainder queued for the next frame. */
#ifndef UPQ_VBLANK_BUDGET
#define UPQ_VBLANK_BUDGET 5100u
#endif

/* A queued DMA upload. `port` selects which destination-address register to load first.
   UPQ_REG and UPQ_POKE16 are the odd ones out: not DMAs, just register pokes carried in the
   queue so they land in the v-blank window like everything else. UPQ_REG writes both bytes to
   ONE address (a write-twice scroll latch); UPQ_POKE16 writes them to addr and addr+1 (a normal
   16-bit register pair, e.g. an HDMA channel's A1TxL/A1TxH table pointer). */
enum { UPQ_VRAM = 0, UPQ_CGRAM = 1, UPQ_OAM = 2, UPQ_REG = 3, UPQ_POKE16 = 4 };

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

/* Enqueue a 16-bit write to the consecutive register pair at `addr` / `addr+1`, applied inside
   upq_flush() (the v-blank window). The motivating use is re-pointing an HDMA channel's table
   address (A1TxL/A1TxH) at a freshly built double-buffer half: the channel latches A1Tx into its
   internal counter at HDMA-init (start of the next frame), so updating it during v-blank swaps
   tables atomically with respect to the transfer. Returns 1 if queued, 0 if the queue was full —
   callers that must not lose the write (a double-buffer flip) should only advance on 1. */
static inline uint8_t upq_push_poke16(UploadQueue *q, uint16_t addr, uint16_t value) {
  if (q->n >= UPQ_MAX_JOBS) return 0;
  UpqJob *j = &q->job[q->n++];
  j->port = UPQ_POKE16; j->dest = addr; j->src = value; j->nbytes = 0;
  return 1;
}

/* Run queued jobs via DMA until UPQ_VBLANK_BUDGET bytes are spent, then STOP and keep whatever is
   left queued for the next frame. MUST be called inside v-blank (Display guarantees it). The CPU
   stalls on each MDMAEN until the copy completes.

   Stopping early is the point. There is no force-blank around this any more, so a transfer that ran
   past the end of v-blank would be writing VRAM during active display — silently dropped or
   corrupt. Budgeting keeps every transfer inside the window; a batch that does not fit simply takes
   an extra frame, which is invisible, whereas the old force-blank made it a flicker at the top of
   the screen.

   Deferral is per WHOLE JOB, not mid-transfer. Drawables already chunk their own streams to a sane
   per-frame size — bitmap_canvas caps at CANVAS_FLUSH_TILES (1 KB) and streams the remainder next
   frame, the OAM shadow is 544 B, palettes are tens of bytes — so no single job comes close to the
   budget and splitting one would be dead weight. A job that would overrun simply waits for the next
   v-blank. The one exception keeps it deadlock-free: a job bigger than the entire budget is sent
   anyway when nothing else has gone yet, since deferring it forever would stall the queue.

   dma_base and mdmaen_bit are hoisted out of the loop so the 65816 never recomputes chan*0x10 or
   1<<chan on every iteration (those are variable-cost ops). */
__attribute__((noinline)) static void upq_flush(UploadQueue *q) {
  volatile uint8_t *dma_base =
    (volatile uint8_t *)(uintptr_t)(0x4300u + (uint16_t)q->chan * 0x10u);
  uint8_t mdmaen_bit = (uint8_t)(1u << q->chan);
  uint16_t spent = 0;
  uint8_t i = 0;

  while (i < q->n) {
    UpqJob *j = &q->job[i];

    if (j->port == UPQ_REG) {       /* write-twice register poke (scroll latch) — not a DMA */
      volatile uint8_t *r = (volatile uint8_t *)(uintptr_t)j->dest;
      *r = (uint8_t)j->src;          /* low byte  */
      *r = (uint8_t)(j->src >> 8);   /* high byte */
      i++; continue;
    }
    if (j->port == UPQ_POKE16) {    /* 16-bit register pair poke (addr, addr+1) — not a DMA */
      volatile uint8_t *r = (volatile uint8_t *)(uintptr_t)j->dest;
      r[0] = (uint8_t)j->src;
      r[1] = (uint8_t)(j->src >> 8);
      i++; continue;
    }

    /* Would this job run past the end of v-blank? Leave it (and the rest) for the next frame. */
    if (spent && (uint16_t)(spent + j->nbytes) > UPQ_VBLANK_BUDGET) break;

    if (j->port == UPQ_VRAM)       { REG_VMAIN = j->vmain; REG_VMADD = j->dest; }
    else if (j->port == UPQ_CGRAM) { REG_CGADD = (uint8_t)j->dest; }
    else                           { REG_OAMADDL = (uint8_t)j->dest;
                                     REG_OAMADDH = (uint8_t)(j->dest >> 8); }
    dma_base[0] = j->dmap;
    dma_base[1] = j->bbad;
    dma_base[2] = (uint8_t)j->src;
    dma_base[3] = (uint8_t)(j->src >> 8);
    dma_base[4] = j->src_bank;
    dma_base[5] = (uint8_t)j->nbytes;
    dma_base[6] = (uint8_t)(j->nbytes >> 8);
    REG_MDMAEN = mdmaen_bit;

    spent = (uint16_t)(spent + j->nbytes);
    i++;
  }

  /* Keep the tail (the unfinished job, if any, plus everything after it). */
  if (i >= q->n) {
    q->n = 0;
  } else if (i) {
    uint8_t k = 0;
    while (i < q->n) q->job[k++] = q->job[i++];
    q->n = k;
  }
}

#endif /* SNESGFX_UPLOAD_H */
