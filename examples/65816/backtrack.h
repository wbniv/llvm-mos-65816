// Backtracking Solver (#116) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster G — the FLAGSHIP guard for the 65816-native
// platforms/snes/setjmp.S fix (bug #35, 2026-07-02). corpus/setjmp_sim.c already guards the
// minimum: one frame, one jump, no live callee-saved registers. This escalates to the corner a
// page-1-S-reconstruct defect actually hides in — a MULTI-frame unwind from a VARYING depth,
// run continuously.
//
// MECHANISM: an 8-queens search where every recursion level owns a choice point
// (`setjmp(bt_cp[row])`). bt_descend() is noinline + recursive and NEVER returns: a completed
// board longjmps to bt_root (BT_N+1 frames at once), and a dead end at depth d longjmps to the
// deepest ancestor k that still has a safe untried column, unwinding (d - k) jsr frames in ONE
// jump. Skipping ancestors whose remaining columns are all unsafe is sound -- they would be
// exhausted immediately -- so the search stays a complete, deterministic backtracking search
// while the unwind depth varies from 1 frame to many. Each backtrack reconstructs the page-1 S,
// restores the soft-SP + the __rc18..__rc31 CSR block, and rts-es back into a frame several
// levels up.
//
// Six independent searches run with the column order rotated per run, so each takes a different
// path and the unwind-depth histogram is wide.
//
// DIFFERENTIAL: integer-exact -- pure compare/index logic, bit-identical host vs target. The gate
// CRC folds the six solution grids, the solved flags, the visit/backtrack counters, the SUMMED
// unwind depth, the total event count and the recorded event trace, so a botched unwind corrupts
// the counters AND the board.
// WIDTH DISCIPLINE: explicit uint8/16; no bare int except setjmp's own return value.
// CLOBBER DISCIPLINE: every value that changes between a setjmp and its longjmp is file-scope,
// never a local (C99 7.13.2.1p3 leaves non-volatile locals indeterminate).
// See docs/plans/2026-09-15-116-118-setjmp-cluster-g-demos.md.

#ifndef BACKTRACK_H
#define BACKTRACK_H

#include <stdint.h>
#include "sjcompat.h"

#define BT_N          8u     /* board size: 8 queens on 8x8 (row/col both fit in 3 bits) */
#define BT_RUNS       8u     /* independent searches, one per column rotation            */
#define BT_TRACE_MAX  384u   /* recorded events for the on-screen replay (1 byte each)   */

/* Event byte: bit7=0 -> PLACE (row<<3)|col ; bit7=1 -> BACKJUMP 0x80|(from<<3)|to. */
#define BT_EV_IS_BACK(e)  (((e) & 0x80u) != 0u)
#define BT_EV_HI(e)       (uint8_t)(((e) >> 3) & 7u)
#define BT_EV_LO(e)       (uint8_t)((e) & 7u)

static jmp_buf bt_cp[BT_N];              /* one choice point per row */
static jmp_buf bt_root;                  /* search-complete escape   */

static uint8_t  bt_col[BT_N];            /* column chosen at each placed row */
static uint8_t  bt_idx[BT_N];            /* index chosen at each placed row  */
static uint8_t  bt_sol[BT_RUNS][BT_N];   /* per-run solution grid            */
static uint8_t  bt_ok[BT_RUNS];          /* per-run solved flag              */
static uint8_t  bt_trace[BT_TRACE_MAX];  /* capped replay trace              */

static uint8_t  bt_run;                  /* current search index */
static uint8_t  bt_base;                 /* current column rotation */
static uint8_t  bt_solved;               /* current search solved? */
static uint16_t bt_visits;               /* queens placed */
static uint16_t bt_backs;                /* longjmp backtracks */
static uint16_t bt_frames;               /* SUM of jsr frames unwound by those longjmps */
static uint16_t bt_events;               /* total events (uncapped) */
static uint16_t bt_tn;                   /* events actually recorded (<= BT_TRACE_MAX) */

static void bt_backjump(uint8_t d);      /* forward decl: bt_descend's only exit on a dead end */

static void bt_push(uint8_t ev) {
    bt_events++;
    if (bt_tn < (uint16_t)BT_TRACE_MAX) bt_trace[bt_tn++] = ev;
}

/* Is column c attack-free against the queens already placed in rows 0..row-1? */
static uint8_t bt_safe(uint8_t row, uint8_t c) {
    for (uint8_t r = (uint8_t)0u; r < row; r++) {
        uint8_t cc = bt_col[r];
        if (cc == c) return (uint8_t)0u;
        uint8_t dr = (uint8_t)(row - r);
        uint8_t dc = (uint8_t)(cc > c ? (uint8_t)(cc - c) : (uint8_t)(c - cc));
        if (dr == dc) return (uint8_t)0u;
    }
    return (uint8_t)1u;
}

/* Column tried at search-order index i (rotated per run; BT_N is 8 so & 7 is the modulus). */
static uint8_t bt_col_at(uint8_t i) { return (uint8_t)((uint8_t)(i + bt_base) & (uint8_t)7u); }

/* Lowest index >= from whose column is safe at `row`; BT_N when none remains. */
static uint8_t bt_next(uint8_t row, uint8_t from) {
    for (uint8_t i = from; i < (uint8_t)BT_N; i++)
        if (bt_safe(row, bt_col_at(i))) return i;
    return (uint8_t)BT_N;
}

// The recursive choice point. noinline: every level must be a REAL jsr frame, since the whole
// point is how many of them one longjmp discards. Never returns -- both exits are longjmps, which
// GCC's -Winfinite-recursion cannot see through, so the host-oracle build silences it locally.
#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpragmas"
#pragma GCC diagnostic ignored "-Winfinite-recursion"
#endif
__attribute__((noinline))
static void bt_descend(uint8_t row) {
    if (row >= (uint8_t)BT_N) {                       /* full board */
        for (uint8_t r = (uint8_t)0u; r < (uint8_t)BT_N; r++) bt_sol[bt_run][r] = bt_col[r];
        bt_solved = (uint8_t)1u;
        longjmp(bt_root, 1);                          /* unwinds BT_N + 1 frames at once */
    }
    /* setjmp returns 0 on entry, or (resume index + 1) when a deeper dead end jumps back here. */
    int rv = setjmp(bt_cp[row]);
    uint8_t i = (rv == 0) ? bt_next(row, (uint8_t)0u) : (uint8_t)((uint8_t)rv - (uint8_t)1u);
    if (i < (uint8_t)BT_N) {
        bt_col[row] = bt_col_at(i);
        bt_idx[row] = i;
        bt_visits++;
        bt_push((uint8_t)(((uint8_t)(row << 3)) | bt_col[row]));
        bt_descend((uint8_t)(row + 1u));              /* never returns */
    }
    bt_backjump(row);                                 /* dead end here */
}
#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif

// One longjmp back to the deepest still-viable ancestor: (d - k) jsr frames discarded at once.
__attribute__((noinline))
static void bt_backjump(uint8_t d) {
    uint8_t k = d;
    while (k > (uint8_t)0u) {
        k--;
        uint8_t i = bt_next(k, (uint8_t)(bt_idx[k] + 1u));
        if (i < (uint8_t)BT_N) {
            bt_backs++;
            bt_frames = (uint16_t)(bt_frames + (uint16_t)(uint8_t)(d - k));
            bt_push((uint8_t)((uint8_t)0x80u | (uint8_t)(d << 3) | k));
            longjmp(bt_cp[k], (int)((uint8_t)(i + 1u)));
        }
    }
    bt_solved = (uint8_t)0u;
    longjmp(bt_root, 2);                              /* search space exhausted */
}

static uint16_t bt_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)((uint16_t)(h * (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: run BT_RUNS searches, fold everything the unwind could corrupt.
// --------------------------------------------------------------------------
static uint16_t backtrack_gate_crc(void) {
    bt_visits = (uint16_t)0u; bt_backs = (uint16_t)0u; bt_frames = (uint16_t)0u;
    bt_events = (uint16_t)0u; bt_tn = (uint16_t)0u;
    for (uint8_t r = (uint8_t)0u; r < (uint8_t)BT_RUNS; r++) {
        bt_ok[r] = (uint8_t)0u;
        for (uint8_t c = (uint8_t)0u; c < (uint8_t)BT_N; c++) bt_sol[r][c] = (uint8_t)0u;
    }
    bt_run = (uint8_t)0u;

    for (;;) {
        /* Re-armed each iteration; every search ends by longjmp-ing back into this frame. */
        if (setjmp(bt_root) != 0) {
            bt_ok[bt_run] = bt_solved;
            bt_run++;
            if (bt_run >= (uint8_t)BT_RUNS) break;
        }
        bt_base = (uint8_t)((uint8_t)((uint8_t)(bt_run * (uint8_t)5u) + (uint8_t)1u) & (uint8_t)7u);
        bt_solved = (uint8_t)0u;
        for (uint8_t r = (uint8_t)0u; r < (uint8_t)BT_N; r++) {
            bt_col[r] = (uint8_t)0u; bt_idx[r] = (uint8_t)0u;
        }
        bt_descend((uint8_t)0u);                      /* never returns */
    }

    uint16_t h = (uint16_t)0x1234u;
    for (uint8_t r = (uint8_t)0u; r < (uint8_t)BT_RUNS; r++) {
        h = bt_mix(h, (uint16_t)bt_ok[r]);
        for (uint8_t c = (uint8_t)0u; c < (uint8_t)BT_N; c++) h = bt_mix(h, (uint16_t)bt_sol[r][c]);
    }
    h = bt_mix(h, bt_visits);
    h = bt_mix(h, bt_backs);
    h = bt_mix(h, bt_frames);
    h = bt_mix(h, bt_events);
    h = bt_mix(h, bt_tn);
    for (uint16_t i = (uint16_t)0u; i < bt_tn; i++) h = bt_mix(h, (uint16_t)bt_trace[i]);
    return h;
}

#endif /* BACKTRACK_H */
