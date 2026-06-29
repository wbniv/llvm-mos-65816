// Host oracle for the #18 Maze generate+solve demo: prints maze_gate_crc() — the golden
// differential anchor dev/maze.sh asserts against the on-console build + both emulators.
//
// Build: cc -O2 -I examples/65816 tools/maze-sim.c -o /tmp/maze-sim && /tmp/maze-sim
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/maze.h"

int main(void) {
    static maze_t m;
    printf("maze gate_crc = 0x%04X\n", maze_gate_crc(&m));
    return 0;
}
