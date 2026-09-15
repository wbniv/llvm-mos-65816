#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/backtrack.h"

int main(void) {
    uint16_t h = backtrack_gate_crc();
    printf("backtrack visits=%u backs=%u frames=%u events=%u traced=%u\n",
           (unsigned)bt_visits, (unsigned)bt_backs, (unsigned)bt_frames,
           (unsigned)bt_events, (unsigned)bt_tn);
    printf("backtrack gate_crc = 0x%04X\n", h);
    return 0;
}
