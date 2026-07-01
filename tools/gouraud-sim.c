#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/gouraud.h"

int main(void) {
    /* Sanity: a fixed triangle covers a plausible pixel count and interpolates the attribute range. */
    GVert v[3];
    gs_make_tri(0u, 32, 32, 14, v);
    long covered = 0, isum = 0;
    int32_t area = gs_edge(v[0].x, v[0].y, v[1].x, v[1].y, v[2].x, v[2].y);
    for (int16_t py = 10; py <= 54; py++)
        for (int16_t px = 10; px <= 54; px++) {
            int32_t e0 = gs_edge(v[1].x, v[1].y, v[2].x, v[2].y, px, py);
            int32_t e1 = gs_edge(v[2].x, v[2].y, v[0].x, v[0].y, px, py);
            int32_t e2 = gs_edge(v[0].x, v[0].y, v[1].x, v[1].y, px, py);
            if (area > 0 ? (e0 >= 0 && e1 >= 0 && e2 >= 0) : (e0 <= 0 && e1 <= 0 && e2 <= 0)) {
                covered++;
                isum += (e0 * (int32_t)v[0].a + e1 * (int32_t)v[1].a + e2 * (int32_t)v[2].a) / area;
            }
        }
    fprintf(stderr, "area=%ld covered=%ld avg_I=%ld\n", (long)area, covered,
            covered ? isum / covered : 0);
    printf("gouraud gate_crc = 0x%04X\n", gouraud_gate_crc());
    return 0;
}
