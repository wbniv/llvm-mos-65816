/* Host oracle for #151 vlanest (Round 8 Cluster C). */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/vlanest.h"

int main(void) {
    uint16_t h = vlanest_gate_crc();
    printf("vlanest rows=%u inner_brackets=%u inner_total=%u reread_bad=%u acc=%u\n",
           (unsigned)VN_ROWS, (unsigned)vn_inner_n, (unsigned)vn_inner_total,
           (unsigned)vn_reread_bad, (unsigned)vn_acc);
    printf("vlanest distinct_outer_len=%u distinct_inner_len=%u\n",
           (unsigned)vn_distinct_outer(), (unsigned)vn_distinct_inner());
    printf("vlanest gate_crc = 0x%04X\n", h);
    return 0;
}
