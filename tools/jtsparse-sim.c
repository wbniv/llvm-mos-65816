/* Host oracle for #153 jtsparse (Round 8 Cluster C). */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/jtsparse.h"

int main(void) {
    uint16_t h = jtsparse_gate_crc();
    printf("jtsparse steps=%u disagreements=%u dense_misses=%u sparse_misses=%u\n",
           (unsigned)JS_STEPS, (unsigned)js_disagreements(),
           (unsigned)js_dense_misses(), (unsigned)js_sparse_misses());
    printf("jtsparse acc_dense=%u acc_sparse=%u\n",
           (unsigned)js_vm[0].acc, (unsigned)js_vm[1].acc);
    printf("jtsparse gate_crc = 0x%04X\n", h);
    return 0;
}
