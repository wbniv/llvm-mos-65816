#ifndef BANKWALK_H
#define BANKWALK_H
#include <stdint.h>
#define BANKWALK_START UINT32_C(65520)
#define BANKWALK_N 64u
#if defined(HOST)
#define FAR
static uint8_t bankwalk_read(uint32_t i){return(uint8_t)(i^(i>>8)^((i>>16)*UINT32_C(0x5B)));}
#else
#define FAR __attribute__((address_space(2)))
extern const FAR uint8_t bankwalk_table[];
static uint8_t bankwalk_read(uint32_t i){return bankwalk_table[i];}
#endif
static uint8_t bankwalk_inc_samples[BANKWALK_N],bankwalk_idx_samples[BANKWALK_N],bankwalk_rev_samples[BANKWALK_N];
static uint16_t bankwalk_fold(uint16_t h,uint8_t v){return(uint16_t)(((h<<5)|(h>>11))^v);}
__attribute__((noinline)) static uint16_t bankwalk_run(void){uint16_t h=UINT16_C(0xB128);volatile uint32_t start=BANKWALK_START;
#if defined(HOST)
 for(uint8_t i=0;i<BANKWALK_N;i++){uint32_t j=start+i;uint8_t a=bankwalk_read(j),b=bankwalk_read(j),c=bankwalk_read(start+63u-i);bankwalk_inc_samples[i]=a;bankwalk_idx_samples[i]=b;bankwalk_rev_samples[i]=c;h=bankwalk_fold(bankwalk_fold(bankwalk_fold(h,a),b),c);}
#else
 const FAR uint8_t*p=bankwalk_table+start;const FAR uint8_t*r=bankwalk_table+start+63u;
 for(uint8_t i=0;i<BANKWALK_N;i++){uint8_t a=*p++,b=bankwalk_table[start+i],c=*r--;bankwalk_inc_samples[i]=a;bankwalk_idx_samples[i]=b;bankwalk_rev_samples[i]=c;h=bankwalk_fold(bankwalk_fold(bankwalk_fold(h,a),b),c);}
#endif
 return h;}
#endif
