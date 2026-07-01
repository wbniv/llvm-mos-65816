#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/grid3d.h"

int main(void) {
    /* Sanity: the automaton stays active over the gate window. */
    g3_seed();
    for (int f = 0; f < (int)GATE_N; f++) {
        g3_step(g3_a, g3_b);
        int pop = 0;
        for (int i = 0; i < G3D * G3D * G3D; i++) pop += ((uint8_t *)g3_b)[i];
        for (int i = 0; i < G3D * G3D * G3D; i++) ((uint8_t *)g3_a)[i] = ((uint8_t *)g3_b)[i];
        fprintf(stderr, "step %d pop=%d\n", f, pop);
    }
    printf("grid3d gate_crc = 0x%04X\n", grid3d_gate_crc());
    return 0;
}
