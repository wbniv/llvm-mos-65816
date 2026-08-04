#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/irqgate.h"

int main(void) {
    uint16_t nmi_tally, irq_tally;
    uint32_t nmi_mix, irq_mix;
    uint16_t crc = irqgate_model(&nmi_tally, &irq_tally, &nmi_mix, &irq_mix);
    printf("irqgate gate_crc = 0x%04X nmi=%u irq=%u nest=%u nmi_mix=0x%08lX irq_mix=0x%08lX\n",
           crc, (unsigned)nmi_tally, (unsigned)irq_tally, (unsigned)IRQGATE_NEST_EXPECT,
           (unsigned long)nmi_mix, (unsigned long)irq_mix);
    return 0;
}
