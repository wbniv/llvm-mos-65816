/* Corpus slice: #18 maze generate+solve, HAL-free. The differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises recursion (the soft stack), an indexed binary-heap priority queue, and array
   indexing under +mos-a16 — no 32-bit libcalls (see examples/65816/maze.h). */
#include "../../65816/maze.h"

static maze_t g_maze;   // static: keep the large state out of the soft-stack frame

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = maze_gate_crc(&g_maze);
    for (;;) __asm__ volatile("wai");
    return 0;
}
