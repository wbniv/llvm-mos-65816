// Maze generate + solve on the snesgfx OOP library — #18 of the compiler stress-test demo battery.
//
// Renders the verified, portable maze logic (examples/65816/maze.h — the same header the host
// oracle tools/maze-sim.c and the corpus slice run) on the SNES:
//   GENERATE  recursive-division carve (genuine recursion — the soft-stack / JSR-RTS frame-ABI
//             codegen; ~log depth so it fits the 65816's 256-byte hardware stack, where a
//             recursive-backtracker DFS's O(N) depth would not — see the plan).
//   SOLVE     A* shortest path with an indexed binary min-heap priority queue (decrease-key) +
//             Manhattan heuristic — the heap/queue/array data-structure stress, animated one
//             expansion per frame: explored cells dim, then the shortest path lights up.
//
// No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16 → the full 5-way differential
// bar (the corpus slice examples/snes/corpus/maze_sim.c). corpus_result = maze_gate_crc() (a
// fixed-seed generate+solve folded to a CRC) is the proof channel, set once before the loop.
//
// Codegen under test: recursion (maze_divide self-call), the heap sift-up/down array indexing,
// branchy A* relaxation, native-16 throughout under +mos-a16 — and NO 32-bit libcalls (a
// different profile from the multiply/divide demos). See docs/plans/2026-06-28-18-snes-maze-...md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "font8.h"
#include "../65816/maze.h"

#define MV_CHR   0x0000u    // BG3 char base (word) — maze tiles 0..47, font at TEXT_FONT_BASE=256
#define MV_MAP   0x4000u    // BG3 tilemap base (word)
#define BOX_COL  8u         // 16-wide maze at cols 8..23  (screen px 64..191)
#define BOX_ROW  7u         // 15-tall maze at rows 7..21  (screen px 56..175)
#define HUD_TOP  4u         // value bar (above the box)
#define HUD_BOT  24u        // legend bar (below the box)

// Tile banks: each holds 16 wall-pattern tiles (one per N/E/S/W bitmask). Bank choice = cell state.
#define TILE_WALL 0u        // tiles  0..15 : walls only (colour 1)
#define TILE_EXPL 16u       // tiles 16..31 : walls + dim centre dot (colour 2) — A* explored
#define TILE_PATH 32u       // tiles 32..47 : walls + bright centre dot (colour 3) — shortest path
#define MV_NTILES 48u

// BG3 2bpp palette (CGRAM 0..3): 0 black bg, 1 wall (cyan), 2 explored (dim violet), 3 path (yellow).
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(6, 24, 28), SNES_RGB(12, 6, 18), SNES_RGB(31, 30, 4),
};

// ------------------------------------- MazeView drawable -------------------------------------
// BG3 tilemap of the 16x15 maze. shadow[] holds one tile# per cell; emit() DMAs the rows changed
// since the last frame (per-row dirty bitmask, capped by q->n like the spigot PiHud).

typedef struct {
    Drawable base;
    uint16_t map_word;
    uint16_t shadow[MAZE_N];              // tile# per cell (480 bytes)
    uint32_t dirty;                       // bit r => maze row r needs re-DMA (15 rows)
} MazeView;

// Build one 2bpp tile (8 words: word r = plane0 | plane1<<8) for wall bitmask `mask` + a centre
// marker in `marker` colour (0 = none, 2 = explored, 3 = path). Walls are colour 1 (plane 0).
static void _mv_tile(uint16_t *out, uint8_t mask, uint8_t marker) {
    for (uint8_t r = 0u; r < 8u; r++) {
        uint8_t p0 = 0u, p1 = 0u;
        if ((mask & WALL_N) && r == 0u) p0 = 0xFFu;
        if ((mask & WALL_S) && r == 7u) p0 = 0xFFu;
        if (mask & WALL_W) p0 |= 0x80u;                 // column 0 (leftmost)
        if (mask & WALL_E) p0 |= 0x01u;                 // column 7 (rightmost)
        if (marker && r >= 2u && r <= 5u) {             // centre 4x4 block, cols 2..5 (0x3C)
            if (marker & 1u) p0 |= 0x3Cu;
            if (marker & 2u) p1 |= 0x3Cu;
        }
        out[r] = (uint16_t)(p0 | ((uint16_t)p1 << 8));
    }
}

static void _mv_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    MazeView *v = (MazeView *)d;
    REG_BG3SC   = SNES_BGSC(v->map_word, 0);
    REG_BG34NBA = (uint8_t)((MV_CHR >> 12) & 0x0Fu);
    // Write the 48 maze tiles (3 banks x 16 wall masks). Direct VRAM is safe in force-blank.
    snes_vram_addr(MV_CHR);
    for (uint8_t bank = 0u; bank < 3u; bank++) {
        uint8_t marker = bank == 0u ? 0u : (uint8_t)(bank + 1u);   // 0, then 2 (expl), 3 (path)
        for (uint8_t mask = 0u; mask < 16u; mask++) {
            uint16_t w[8]; _mv_tile(w, mask, marker);
            for (uint8_t r = 0u; r < 8u; r++) REG_VMDATA = w[r];
        }
    }
    // Blank the whole 32x32 tilemap (tile 0 = mask-0 = transparent); emit() fills the box rows.
    snes_vram_addr(v->map_word);
    for (uint16_t i = 0u; i < 32u * 32u; i++) REG_VMDATA = 0u;
    v->base.tm_bits = TM_BG3;
    v->dirty = 0u;
}

static void _mv_emit(Drawable *d, UploadQueue *q) {
    MazeView *v = (MazeView *)d;
    for (uint8_t r = 0u; r < MAZE_H_CELLS && q->n < UPQ_MAX_JOBS; r++) {
        if (!(v->dirty & (uint32_t)(1u << r))) continue;
        upq_push_vram(q, (uint16_t)(v->map_word + (uint16_t)(BOX_ROW + r) * 32u + BOX_COL),
                      &v->shadow[(uint16_t)r * MAZE_W], 0x00u, MAZE_W * 2u, VMAIN_INC_HIGH_1);
        v->dirty &= ~(uint32_t)(1u << r);
    }
}

static const DrawableVT MV_VT = { _mv_reserve, _mv_emit };

static void mazeview_init(MazeView *v, uint16_t map_word) {
    v->base.vt = &MV_VT;
    v->base.tm_bits = TM_BG3;
    v->map_word = map_word;
    for (uint16_t i = 0u; i < MAZE_N; i++) v->shadow[i] = 0u;
    v->dirty = 0u;
}

// Set cell (x,y) to a tile in bank `bank_base` (TILE_WALL/EXPL/PATH) carrying wall bitmask `mask`.
static inline void mazeview_cell(MazeView *v, uint8_t x, uint8_t y, uint8_t bank_base, uint8_t mask) {
    v->shadow[(uint16_t)y * MAZE_W + x] = (uint16_t)(bank_base + mask);
    v->dirty |= (uint32_t)(1u << y);
}

// ------------------------------------- application -------------------------------------------

#define PH_SOLVE 0u    // animate A* expansions
#define PH_TRACE 1u    // light the shortest path start->goal
#define PH_HOLD  2u    // pause on the finished maze, then regenerate

typedef struct {
    Display   screen;
    MazeView  view;
    TextLayer text;
    maze_t    mz;
    uint16_t  seed;       // current display maze seed
    uint8_t   phase;
    uint16_t  trace_i;    // PH_TRACE: next path cell index into heap[]
    uint16_t  path_n;     // PH_TRACE: path cell count
    uint16_t  hold;       // PH_HOLD countdown
} App;

volatile uint16_t corpus_result;   // proof channel (read from WRAM by the gate; maze gate CRC)

static void u16_str(char *b, uint16_t v) {     // minimal unsigned -> decimal
    char t[6]; uint8_t n = 0;
    if (!v) t[n++] = '0';
    while (v) { t[n++] = (char)('0' + (uint8_t)(v % 10u)); v /= 10u; }
    uint8_t i = 0; while (n) b[i++] = t[--n]; b[i] = 0;
}

static void hud_top(App *a) {
    char num[6], line[24]; uint8_t n = 0;
    const char *p = "MAZE 16X15 SEED ";
    while (*p) line[n++] = *p++;
    u16_str(num, a->seed);
    for (char *q = num; *q; q++) line[n++] = *q;
    line[n] = 0;
    text_clear_bar(&a->text, 0);
    text_puts(&a->text, 0, 1, line);
}

static void hud_bot(App *a) {
    char num[6], line[28]; uint8_t n = 0;
    const char *p = "A* EXPLORED ";
    while (*p) line[n++] = *p++;
    u16_str(num, a->mz.expanded);
    for (char *q = num; *q; q++) line[n++] = *q;
    if (a->phase >= PH_TRACE) {
        const char *q2 = "  PATH "; while (*q2) line[n++] = *q2++;
        u16_str(num, a->mz.path_len);
        for (char *q = num; *q; q++) line[n++] = *q;
    }
    line[n] = 0;
    text_clear_bar(&a->text, 1);
    text_puts(&a->text, 1, 1, line);
}

// Draw the whole carved maze as wall tiles, with start (0,0) and goal lit in the path colour.
static void render_walls(App *a) {
    for (uint8_t y = 0u; y < MAZE_H_CELLS; y++)
        for (uint8_t x = 0u; x < MAZE_W; x++)
            mazeview_cell(&a->view, x, y, TILE_WALL, a->mz.wall[(uint16_t)y * MAZE_W + x]);
    mazeview_cell(&a->view, 0u, 0u, TILE_PATH, a->mz.wall[0]);
    mazeview_cell(&a->view, MAZE_GX, MAZE_GY, TILE_PATH, a->mz.wall[maze_idx(MAZE_GX, MAZE_GY)]);
}

// Start a fresh maze: carve (recursion), render, arm the animated A*.
static void new_maze(App *a) {
    maze_generate(&a->mz, a->seed);
    render_walls(a);
    maze_solve_init(&a->mz);
    a->phase = PH_SOLVE;
    hud_top(a); hud_bot(a);
}

__attribute__((noinline))
static void app_init(App *a) {
    display_init(&a->screen);
    mazeview_init(&a->view, MV_MAP);
    text_init(&a->text, MV_MAP, HUD_TOP, HUD_BOT);
    display_add(&a->screen, (Drawable *)&a->view);   // reserve BG3 + tiles (force-blank)
    display_add(&a->screen, (Drawable *)&a->text);   // reserve: load font (force-blank)
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->seed = 0xC0DEu;        // first on-screen maze == the gate maze
    new_maze(a);
}

// One animation tick. Returns nothing; advances the phase state machine.
static void step_frame(App *a) {
    uint16_t goal = maze_idx(MAZE_GX, MAZE_GY);
    if (a->phase == PH_SOLVE) {
        uint16_t cur = maze_solve_step(&a->mz);
        if (cur == 0xFFFFu || cur == goal) {                 // solved (or drained)
            a->path_n = maze_path_build(&a->mz);             // heap[] = path goal->start
            a->trace_i = 0u;
            a->phase = PH_TRACE;
        } else if (cur != maze_idx(0u, 0u)) {                // dim the explored cell
            mazeview_cell(&a->view, (uint8_t)(cur & MAZE_WMASK), (uint8_t)(cur >> MAZE_WSH),
                          TILE_EXPL, a->mz.wall[cur]);
        }
        hud_bot(a);
    } else if (a->phase == PH_TRACE) {
        if (a->trace_i < a->path_n) {
            uint16_t c = a->mz.heap[a->trace_i++];
            mazeview_cell(&a->view, (uint8_t)(c & MAZE_WMASK), (uint8_t)(c >> MAZE_WSH),
                          TILE_PATH, a->mz.wall[c]);
        } else {
            a->phase = PH_HOLD; a->hold = 150u;
            hud_bot(a);
        }
    } else { /* PH_HOLD */
        if (a->hold) a->hold--;
        else { a->seed = (uint16_t)(a->seed * 1103u + 12345u); new_maze(a); }   // next maze
    }
}

int main(void) {
    static App a;
    app_init(&a);

    // Title overlay (BG2), held during the gate CRC, then torn down before the maze animates.
    static TitleLayer title;
    title_begin(&a.screen, &title, "MAZE", "GENERATE + SOLVE");

    // Self-verify: the gate CRC generates+solves the fixed-seed maze. It reuses the App's maze_t,
    // so re-arm the on-screen maze (seed 0xC0DE) afterwards.
    corpus_result = maze_gate_crc(&a.mz);
    new_maze(&a);
    title_end(&a.screen, &title, 90u);                    // ~1.5 s title

    for (;;) {
        step_frame(&a);
        display_frame(&a.screen);
    }
}
