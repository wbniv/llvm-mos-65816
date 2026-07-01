#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/msquares.h"

int main(void) {
    /* Sanity: count non-empty cases in one frame — a live contour crosses many cells. */
    int16_t cx[MS_NB], cy[MS_NB];
    ms_centers(0u, cx, cy);
    long crossed = 0, cases[16] = {0};
    for (uint8_t gy = 0; gy < (uint8_t)MS_GH; gy++)
        for (uint8_t gx = 0; gx < (uint8_t)MS_GW; gx++) {
            int16_t px = (int16_t)((int16_t)gx * 6 + 8), py = (int16_t)((int16_t)gy * 6 + 8);
            int32_t vtl = ms_field(px, py, cx, cy), vtr = ms_field((int16_t)(px+6), py, cx, cy);
            int32_t vbr = ms_field((int16_t)(px+6),(int16_t)(py+6),cx,cy), vbl = ms_field(px,(int16_t)(py+6),cx,cy);
            uint8_t cs = (uint8_t)(((vtl>=MS_ISO)<<3)|((vtr>=MS_ISO)<<2)|((vbr>=MS_ISO)<<1)|(vbl>=MS_ISO));
            cases[cs]++;
            if (cs != 0 && cs != 15) crossed++;
        }
    fprintf(stderr, "crossed-cells=%ld  empty(0)=%ld  full(15)=%ld\n", crossed, cases[0], cases[15]);
    printf("msquares gate_crc = 0x%04X\n", msquares_gate_crc());
    return 0;
}
