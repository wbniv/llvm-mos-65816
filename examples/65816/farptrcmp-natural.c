#include <stdint.h>
#define FAR __attribute__((address_space(2)))
extern const FAR uint8_t bankwalk_table[];
volatile uint32_t farptrcmp_natural_result;
void farptrcmp_natural(void){const FAR uint8_t*p[3]={bankwalk_table+0x10020,bankwalk_table+0x0fff0,bankwalk_table+0x20004};if(p[0]>p[1]){const FAR uint8_t*t=p[0];p[0]=p[1];p[1]=t;}farptrcmp_natural_result=(uint32_t)(p[2]-p[0]);}
