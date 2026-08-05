#include <stdio.h>
#include "../examples/65816/farspill.h"

int main(void) {
    printf("farspill gate_crc = 0x%04X\n", farspill_model());
    return 0;
}
