#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/dither.h"

int main(void) {
    /* Sanity: count band usage of one dithered frame — a proper dither uses all 4 levels. */
    static uint8_t out[DS_GW * DS_GH];
    ds_dither((uint8_t)DS_GW, (uint8_t)DS_GH, 0u, out);
    long cnt[4] = {0, 0, 0, 0};
    for (int i = 0; i < (int)(DS_GW * DS_GH); i++) cnt[out[i] & 3]++;
    fprintf(stderr, "bands: %ld %ld %ld %ld\n", cnt[0], cnt[1], cnt[2], cnt[3]);
    printf("dither gate_crc = 0x%04X\n", dither_gate_crc());
    return 0;
}
