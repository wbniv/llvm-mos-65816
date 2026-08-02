// examples/65816/seamdemo_graph.h — Act 2's boundary-hostile graph walk,
// shared by the SNES ROM and the host harness.
//
// One 16-byte node per DECODE CELL of the cartridge — mirrors included — chained
// into a single covering cycle. Following `next` from the entry visits every
// decode cell exactly once and returns to the entry, so the walk proves the
// address decoder on every CPU view of the ROM, not just the canonical ones.
// Each node additionally carries two adversarial read-only "peek" edges, biased
// towards the other physical mask ROM and towards mirror addresses.
//
// Unlike Act 1, the addresses here are 24-bit CPU addresses straight out of the
// payload — no file→CPU translation. A mirror-addressed node is a genuine mirror
// read, and the fold catches a decoder that resolved it to the wrong byte.
//
// The includer must define, before including:
//   SEAMGRAPH_FAR8(addr)                        -> uint8_t, read one cartridge
//                                                  byte at a 24-bit CPU address
//   SEAMGRAPH_EDGE(ctx, x0, y0, x1, y1, accent) -> void, may expand to nothing
// and must have included the generated seamdemo-data.h and seamdemo_vm.h (for
// seamvm_fold — Act 2 folds with the same primitive as Act 1).
//
// Traversal order is the contract the Python oracle's run_act2() already
// computes SEAMDEMO_ACT2_CRC for: all 16 node bytes, then the byte at peek0,
// then the byte at peek1; after every node, the node count low byte then high.
#ifndef SEAMDEMO_GRAPH_H
#define SEAMDEMO_GRAPH_H

#include <stdint.h>

#ifndef SEAMDEMO_VM_H
#error "include seamdemo_vm.h before seamdemo_graph.h (seamvm_fold lives there)"
#endif
#ifndef SEAMGRAPH_FAR8
#error "define SEAMGRAPH_FAR8(addr) before including seamdemo_graph.h"
#endif
#ifndef SEAMGRAPH_EDGE
#define SEAMGRAPH_EDGE(ctx, x0, y0, x1, y1, accent) ((void)0)
#endif

#define SEAMGRAPH_ST_CYCLE 0x0100u  // the covering cycle did not close on the entry
#define SEAMGRAPH_ST_CRC 0x0200u    // the walk folded to something other than the oracle

typedef struct {
  unsigned long p;       // current node, as a 24-bit CPU address
  uint16_t crc;
  uint16_t visited;
  uint16_t edges;        // edges accounted so far (next + two peeks per node)
  uint16_t seam_edges;   // ... of which cross the physical device boundary
  uint16_t mirror_edges; // ... of which name a MIRROR rather than the canonical window
  uint16_t status;
  uint8_t x, y;          // canvas position of the current node
  uint8_t done;
} SeamGraph;

// The web IS the address space: a node's canvas position is its own CPU address.
// x is the bank (256 banks folded to 128 columns), y the address within the bank
// (64 KiB folded to 128 rows). So a seam-crossing edge is visibly a long jump
// across the picture, and the $FF→$40 discontinuity reads as one.
static inline uint8_t seamgraph_x(unsigned long far) {
  return (uint8_t)(((far >> 16) & 0xFFu) >> 1);
}
static inline uint8_t seamgraph_y(unsigned long far) {
  return (uint8_t)((far >> 9) & 0x7Fu);
}

static void seamgraph_init(SeamGraph *g) {
  g->p = SEAMDEMO_ACT2_ENTRY;
  g->crc = 0;
  g->visited = 0;
  g->edges = 0;
  g->seam_edges = 0;
  g->mirror_edges = 0;
  g->done = 0;
  g->x = seamgraph_x(SEAMDEMO_ACT2_ENTRY);
  g->y = seamgraph_y(SEAMDEMO_ACT2_ENTRY);
  // `status` is deliberately NOT cleared — it accumulates across a lap.
}

// Walk one node: fold it, fold its two peeked bytes, draw the edge, advance.
// noinline for the same reason as seamvm_step — one copy, one shape to read in
// the disassembly.
__attribute__((noinline)) static void seamgraph_step(SeamGraph *g, void *ctx) {
  const unsigned long p = g->p;
  uint8_t rec[SEAMDEMO_NODE_BYTES];
  (void)ctx;  // unused when SEAMGRAPH_EDGE is the no-op (the host harness)

  for (uint8_t i = 0; i < SEAMDEMO_NODE_BYTES; i++) {
    rec[i] = SEAMGRAPH_FAR8(p + i);
    g->crc = seamvm_fold(g->crc, rec[i]);
  }

  unsigned long nxt = (unsigned long)rec[SEAMDEMO_NODE_NEXT]
                      | ((unsigned long)rec[SEAMDEMO_NODE_NEXT + 1] << 8)
                      | ((unsigned long)rec[SEAMDEMO_NODE_NEXT + 2] << 16);

  // The peeks are READ-ONLY probes: the walk does not move to them, it just
  // dereferences them. That is what lets one lap touch every decode cell via the
  // cycle AND still fire hundreds of long-range adversarial far reads.
  for (uint8_t k = 0; k < 2; k++) {
    const uint8_t base = k ? (uint8_t)SEAMDEMO_NODE_PEEK1 : (uint8_t)SEAMDEMO_NODE_PEEK0;
    unsigned long t = (unsigned long)rec[base]
                      | ((unsigned long)rec[base + 1] << 8)
                      | ((unsigned long)rec[base + 2] << 16);
    g->crc = seamvm_fold(g->crc, SEAMGRAPH_FAR8(t));
    const uint8_t fl = rec[base + 3];
    g->edges++;
    if (fl & SEAMDEMO_EDGE_SEAM) g->seam_edges++;
    if (fl & SEAMDEMO_EDGE_MIRROR) g->mirror_edges++;
  }

  const uint8_t nflags = rec[SEAMDEMO_NODE_NEXT_FLAGS];
  g->edges++;
  if (nflags & SEAMDEMO_EDGE_SEAM) g->seam_edges++;
  if (nflags & SEAMDEMO_EDGE_MIRROR) g->mirror_edges++;

  const uint8_t nx = seamgraph_x(nxt), ny = seamgraph_y(nxt);
  SEAMGRAPH_EDGE(ctx, g->x, g->y, nx, ny, (uint8_t)(nflags & SEAMDEMO_EDGE_SEAM));
  g->x = nx;
  g->y = ny;

  g->p = nxt;
  g->visited++;

  if (g->visited >= SEAMDEMO_ACT2_NODES) {
    // The cycle must land back on the entry. A decoder that mis-resolved ONE
    // mirror would almost certainly break the chain here rather than merely
    // perturb the fold, which is why this is checked separately.
    if (g->p != (unsigned long)SEAMDEMO_ACT2_ENTRY) g->status |= SEAMGRAPH_ST_CYCLE;
    g->done = 1;
  }
}

static uint16_t seamgraph_final_crc(const SeamGraph *g) {
  uint16_t h = g->crc;
  h = seamvm_fold(h, (uint8_t)(SEAMDEMO_ACT2_NODES & 0xFFu));
  h = seamvm_fold(h, (uint8_t)(SEAMDEMO_ACT2_NODES >> 8));
  return h;
}

#endif /* SEAMDEMO_GRAPH_H */
