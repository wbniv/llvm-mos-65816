// Barnes-Hut quadtree galaxy — shared portable math for SNES demo #31.
//
// A 2-level fixed-depth quadtree (root → 4 quad children → 16 leaf cells)
// partitions an N_PARTICLES-star galaxy. Force on each particle is computed by
// recursive tree walk: distant nodes contribute via their centre-of-mass (the
// Barnes-Hut approximation); near nodes recurse into children.
//
// The codegen corner: "pointer-chasing dynamic trees" from the coverage map.
// Each tree walk follows  qt_pool[node->child[q]]  — the child field is a
// runtime uint8_t index whose value depends on particle positions. Under +mos-a16
// this generates ZP-indexed indirect loads (lda (zp),Y) through the node pool.
// The recursive force-calculation function (bh_force) calls itself via JSR,
// stressing the soft-stack ABI in a tree-shaped call graph (not a linear loop).
//
// Arithmetic stress: each force pair uses __mulsi3 (dx*dx, dy*dy, mass*dx)
// plus __udivsi3 for the force magnitude. Together with the tree walk, this
// combines the multiply-divide corner (#13 N-body) with the new pointer-chasing
// corner in a single demo.
//
// NO bare int — all widths explicit (int16_t / uint32_t). CLAUDE.md §width rules.
#ifndef BHUT_H
#define BHUT_H

#include <stdint.h>

#define BH_N         8u    /* number of particles */
#define BH_W         128u  /* simulation canvas width  */
#define BH_H         128u  /* simulation canvas height */
#define BH_LEVELS    2u    /* quadtree depth (root + 2 = 21 nodes max) */
#define BH_MAX_NODES 21u   /* 1 + 4 + 16 = 21 nodes */
#define BH_NULL      0xFFu /* null node index */
#define BH_SOFT      64u   /* softening constant (added to dist²) */
#define BH_G         96    /* gravity constant (scales force into Q8.8 accel) */
#define BH_GATE_STEPS 6u   /* simulation steps in gate CRC */

typedef struct {
    int16_t  x, y;    /* position (pixels, [0..BH_W-1] × [0..BH_H-1]) */
    int16_t  vx, vy;  /* velocity (pixels/step — NOT Q8.8) */
    uint8_t  mass;    /* particle mass */
} BhParticle;

typedef struct {
    int32_t  sum_x;   /* sum of particle x (for COM: sum_x / mass) */
    int32_t  sum_y;   /* sum of particle y */
    uint8_t  mass;    /* number of particles in this node */
    uint8_t  child[4]; /* child node indices; BH_NULL = empty child */
    int16_t  cx, cy;  /* node cell top-left */
    uint8_t  cw, ch;  /* node cell width/height */
    uint8_t  has_child; /* 0 = leaf, 1 = internal */
} BhNode;

static BhNode   bh_pool[BH_MAX_NODES];
static uint8_t  bh_count;
static BhParticle bh_par[BH_N];

/* Allocate a node from the pool. */
static uint8_t bh_alloc(void) {
    if (bh_count >= (uint8_t)BH_MAX_NODES) return BH_NULL;
    uint8_t idx = bh_count++;
    BhNode *n = &bh_pool[idx];
    n->sum_x = 0; n->sum_y = 0; n->mass = 0; n->has_child = 0;
    n->child[0] = BH_NULL; n->child[1] = BH_NULL;
    n->child[2] = BH_NULL; n->child[3] = BH_NULL;
    return idx;
}

/* Which quadrant (0..3) does (px,py) fall into for node n? */
static uint8_t bh_quad(const BhNode *n, int16_t px, int16_t py) {
    uint8_t qx = (px >= (int16_t)(n->cx + n->cw / 2)) ? 1u : 0u;
    uint8_t qy = (py >= (int16_t)(n->cy + n->ch / 2)) ? 1u : 0u;
    return (uint8_t)(qy * 2u + qx);  /* 0=NW,1=NE,2=SW,3=SE */
}

/* Insert particle pi into subtree rooted at node_idx. Recursive. */
static void bh_insert(uint8_t node_idx, uint8_t pi) {
    if (node_idx == BH_NULL) return;
    BhNode *n = &bh_pool[node_idx];
    /* Update COM accumulator */
    n->sum_x += (int32_t)bh_par[pi].x;
    n->sum_y += (int32_t)bh_par[pi].y;
    n->mass++;
    if (!n->has_child) return;  /* leaf: this node is done */
    /* Route to appropriate child */
    uint8_t q = bh_quad(n, bh_par[pi].x, bh_par[pi].y);
    if (n->child[q] == BH_NULL) {
        /* Allocate missing child */
        uint8_t cidx = bh_alloc();
        if (cidx == BH_NULL) return;
        BhNode *c = &bh_pool[cidx];
        uint8_t hw = (uint8_t)(n->cw / 2u), hh = (uint8_t)(n->ch / 2u);
        c->cx = (int16_t)(n->cx + (int16_t)((q & 1u) ? hw : 0));
        c->cy = (int16_t)(n->cy + (int16_t)((q & 2u) ? hh : 0));
        c->cw = hw; c->ch = hh;
        c->has_child = (n->cw > 16u) ? 1u : 0u; /* stop subdividing at 16px */
        n->child[q] = cidx;
    }
    bh_insert(n->child[q], pi);  /* pointer-chasing: follow child index */
}

/* Accumulate Barnes-Hut gravitational force on particle (px,py) from
   subtree node_idx. Updates *fx, *fy (in Q8.8 fixed-point). Recursive. */
__attribute__((noinline))
static void bh_force(uint8_t node_idx, int16_t px, int16_t py,
                     int32_t *fx, int32_t *fy) {
    if (node_idx == BH_NULL) return;
    BhNode *n = &bh_pool[node_idx];    /* ZP-indexed pool access */
    if (!n->mass) return;

    /* Centre of mass of this node */
    int16_t com_x = (int16_t)(n->sum_x / (int32_t)(uint32_t)n->mass);
    int16_t com_y = (int16_t)(n->sum_y / (int32_t)(uint32_t)n->mass);
    int32_t dx = (int32_t)com_x - (int32_t)px;
    int32_t dy = (int32_t)com_y - (int32_t)py;
    uint32_t dist2 = (uint32_t)((int32_t)dx*dx + (int32_t)dy*dy)  /* __mulsi3 */
                   + (uint32_t)BH_SOFT;

    /* Barnes-Hut: use node COM if width² < dist²  (theta ≈ 1) */
    uint32_t w2 = (uint32_t)n->cw * (uint32_t)n->cw;              /* __mulsi3 */
    if (!n->has_child || w2 < dist2) {
        /* Apply force: F = G * mass * d / dist² → Q8.8 accel (all signed 32-bit). */
        *fx += (int32_t)BH_G * (int32_t)n->mass * dx / (int32_t)dist2;  /* __mulsi3 + __divsi3 */
        *fy += (int32_t)BH_G * (int32_t)n->mass * dy / (int32_t)dist2;
    } else {
        /* Recurse into children — pointer-chasing through the tree */
        for (uint8_t q = 0u; q < 4u; q++)
            bh_force(n->child[q], px, py, fx, fy);  /* JSR via child index */
    }
}

/* Build tree, compute forces, integrate one step. */
static void bh_step(void) {
    /* Reset pool and build tree */
    bh_count = 0;
    uint8_t root = bh_alloc();
    bh_pool[root].cx = 0; bh_pool[root].cy = 0;
    bh_pool[root].cw = (uint8_t)BH_W; bh_pool[root].ch = (uint8_t)BH_H;
    bh_pool[root].has_child = 1u;
    for (uint8_t i = 0u; i < (uint8_t)BH_N; i++) bh_insert(root, i);

    /* Compute forces and integrate */
    for (uint8_t i = 0u; i < (uint8_t)BH_N; i++) {
        int32_t fx = 0, fy = 0;
        bh_force(root, bh_par[i].x, bh_par[i].y, &fx, &fy);
        /* vx,vy are Q8.8 velocity; fx,fy are Q8.8 accel. x,y are integer pixels. */
        bh_par[i].vx = (int16_t)(bh_par[i].vx + (int16_t)fx);
        bh_par[i].vy = (int16_t)(bh_par[i].vy + (int16_t)fy);
        bh_par[i].x  = (int16_t)(bh_par[i].x + (bh_par[i].vx >> 8));
        bh_par[i].y  = (int16_t)(bh_par[i].y + (bh_par[i].vy >> 8));
        /* Bounce off walls */
        if (bh_par[i].x <  0)          { bh_par[i].x =  0; bh_par[i].vx = (int16_t)-bh_par[i].vx; }
        if (bh_par[i].x >= (int16_t)BH_W) { bh_par[i].x = (int16_t)(BH_W-1); bh_par[i].vx = (int16_t)-bh_par[i].vx; }
        if (bh_par[i].y <  0)          { bh_par[i].y =  0; bh_par[i].vy = (int16_t)-bh_par[i].vy; }
        if (bh_par[i].y >= (int16_t)BH_H) { bh_par[i].y = (int16_t)(BH_H-1); bh_par[i].vy = (int16_t)-bh_par[i].vy; }
    }
}

/* Fixed initial conditions for the gate. */
static void bh_init(void) {
    static const int16_t INIT_X[BH_N] = { 32, 96, 64, 16, 112, 48, 80, 64 };
    static const int16_t INIT_Y[BH_N] = { 32, 32, 96, 64,  64, 16, 16, 48 };
    /* Q8.8 velocities (256 = 1 px/step) */
    static const int16_t INIT_VX[BH_N]= { 200, -200,   0, 300, -100, 150, -150,  60 };
    static const int16_t INIT_VY[BH_N]= { 100,  100,-200,   0,  200,-100,  100,-160 };
    for (uint8_t i = 0u; i < (uint8_t)BH_N; i++) {
        bh_par[i].x = INIT_X[i]; bh_par[i].y = INIT_Y[i];
        bh_par[i].vx = INIT_VX[i]; bh_par[i].vy = INIT_VY[i];
    }
}

/* Gate CRC: run BH_GATE_STEPS of the simulation on fixed initial conditions,
   fold particle positions into a rotate-XOR hash. */
static inline uint16_t bh_gate_crc(void) {
    bh_init();
    for (uint8_t s = 0u; s < (uint8_t)BH_GATE_STEPS; s++) bh_step();
    uint16_t h = 0u;
    for (uint8_t i = 0u; i < (uint8_t)BH_N; i++) {
        h = (uint16_t)((h << 1u) | (h >> 15u)) ^ (uint16_t)bh_par[i].x;
        h = (uint16_t)((h << 1u) | (h >> 15u)) ^ (uint16_t)bh_par[i].y;
    }
    return h;
}

#endif /* BHUT_H */
