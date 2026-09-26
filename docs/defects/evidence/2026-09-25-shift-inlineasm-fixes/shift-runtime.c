#include "shift-narrow.h"
#ifdef HOST_MAIN
#include <stdio.h>
#endif
volatile uint16_t corpus_result;
int main(void) {
#ifdef HOST_MAIN
  printf("0x%04X\n", (unsigned)shift64seam_model());
#else
  corpus_result = shift64seam_model();
  for (;;) __asm__ volatile("wai");
#endif
}
