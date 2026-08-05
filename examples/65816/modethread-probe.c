#include "modethread.h"
volatile uint16_t modethread_probe_result;
void modethread_probe(void){modethread_probe_result=modethread_run(7u,UINT16_C(0xA16A));}
