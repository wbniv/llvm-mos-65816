#include <stdint.h>
volatile uint64_t shift64seam_narrow_value;
volatile uint8_t shift64seam_narrow_count;
uint64_t shift64seam_narrow(void) {
    return shift64seam_narrow_value << shift64seam_narrow_count;
}
