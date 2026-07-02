// PlyOracle (#92) — shared, portable logic header.
//
// Stresses: negamax with alpha-beta pruning — the alternating-sign recursion return shape.
// Each ply returns `-negamax(child)` (G_SUB 0,x negation on the return value), the best score is
// a running G_SMAX, and the alpha-beta cutoff (`if (score >= beta) return score;`) builds a
// branch-heavy prune CFG. This negate-on-return + max + cutoff recursion is a shape #17/#18
// (plain/log-depth recursion, no sign flip) never form. Tic-tac-toe (depth <= 9) fits the 65816
// hardware stack (~9 * small frame << 256 B).
//
// WIDTH DISCIPLINE: int16_t scores, uint16_t bitboards. No bare int.
// DIFFERENTIAL: exact integer minimax — bit-identical host vs 65816. Any wrong negation, max, or
// mis-pruned branch changes a chosen move and diverges the self-play fold.
//
// See docs/plans/2026-07-01-92-snes-plyoracle.md.

#ifndef PLYORACLE_H
#define PLYORACLE_H

#include <stdint.h>

#ifndef PO_GATE_N
#define PO_GATE_N 4u        // self-play games folded into the gate
#endif
// Search-depth cap: a standard game-AI bound so the full-width TTT tree fits the SNES time
// budget. The negamax recurrence, negate-on-return (G_SUB 0,x), G_SMAX, and alpha-beta cutoff
// all still fire — only the ply horizon is bounded (a depth-limited heuristic return of 0).
#define PO_MAXD 3u

// 8 winning lines as 9-bit masks.
static const uint16_t PO_LINES[8] = {
    0007u, 0070u, 0700u,     // rows
    0111u, 0222u, 0444u,     // cols
    0421u, 0124u             // diagonals
};

static inline uint8_t po_wins(uint16_t bb) {
    uint8_t i;
    for (i = 0u; i < 8u; i++) if ((bb & PO_LINES[i]) == PO_LINES[i]) return 1u;
    return 0u;
}

// Negamax with alpha-beta. `me`/`opp` are 9-bit boards; returns best score for `me`.
// score: +(depth-left) win / -(...) loss / 0 draw — depth-weighted so quicker wins score higher.
static int16_t po_negamax(uint16_t me, uint16_t opp, int16_t alpha, int16_t beta, uint8_t depth) {
    if (po_wins(opp)) return (int16_t)(-(int16_t)(10 - depth));   // opponent just won
    uint16_t occ = (uint16_t)(me | opp);
    if (occ == 0x1FFu) return 0;                                   // full board → draw
    if (depth >= PO_MAXD) return 0;                                // depth horizon (heuristic)
    int16_t best = (int16_t)-32000;                                // -infinity
    uint8_t m;
    for (m = 0u; m < 9u; m++) {
        uint16_t bit = (uint16_t)(1u << m);
        if (occ & bit) continue;
        // negate-on-return: score of this move = -opponent's best reply (G_SUB 0,x)
        int16_t score = (int16_t)(-po_negamax(opp, (uint16_t)(me | bit),
                                              (int16_t)(-beta), (int16_t)(-alpha), (uint8_t)(depth + 1u)));
        if (score > best) best = score;             // running G_SMAX
        if (best > alpha) alpha = best;
        if (alpha >= beta) break;                    // alpha-beta cutoff (prune CFG)
    }
    return best;
}

// Pick the best move for `me` (0..8), or 255 if none.
static uint8_t po_best_move(uint16_t me, uint16_t opp) {
    uint16_t occ = (uint16_t)(me | opp);
    int16_t best = (int16_t)-32000; uint8_t bestm = 255u, m;
    for (m = 0u; m < 9u; m++) {
        uint16_t bit = (uint16_t)(1u << m);
        if (occ & bit) continue;
        int16_t score = (int16_t)(-po_negamax(opp, (uint16_t)(me | bit),
                                              (int16_t)-32000, (int16_t)32000, 1u));
        if (score > best) { best = score; bestm = m; }
    }
    return bestm;
}

// ------------------------------------------------------------------
// Gate CRC: play PO_GATE_N self-play games from varied openings, fold the move sequence.
// ------------------------------------------------------------------
static uint16_t plyoracle_gate_crc(void) {
    uint16_t h = 0u;
    uint16_t g;
    for (g = 0u; g < (uint16_t)PO_GATE_N; g++) {
        uint16_t x = 0u, o = 0u;
        // vary the opening: force X's first move to cell (g % 9)
        uint8_t first = (uint8_t)(g % 9u);
        x = (uint16_t)(1u << first);
        uint8_t turn = 1u;   // 0 = X to move, 1 = O to move
        uint8_t plies;
        for (plies = 0u; plies < 8u; plies++) {
            if (po_wins(x) || po_wins(o) || (uint16_t)(x | o) == 0x1FFu) break;
            uint8_t mv;
            if (turn == 0u) { mv = po_best_move(x, o); if (mv < 9u) x = (uint16_t)(x | (1u << mv)); }
            else            { mv = po_best_move(o, x); if (mv < 9u) o = (uint16_t)(o | (1u << mv)); }
            turn = (uint8_t)(turn ^ 1u);
            h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
            h = (uint16_t)(h ^ (uint16_t)((uint16_t)mv * 97u) ^ (uint16_t)(x ^ (o << 4)));
        }
    }
    return h;
}

#endif /* PLYORACLE_H */
