#ifndef FARPTRCMP_H
#define FARPTRCMP_H
#include <stdint.h>
#define FAR __attribute__((address_space(2)))
#ifndef HOST
extern const FAR uint8_t bankwalk_table[];
#endif
static uint8_t farptrcmp_order[8];static uint32_t farptrcmp_gaps[7];
static uint16_t farptrcmp_fold(uint16_t h,uint32_t v){for(uint8_t i=0;i<4;i++){h=(uint16_t)(((h<<3)|(h>>13))^(uint8_t)v);v>>=8;}return h;}
static uint16_t farptrcmp_run(void){uint32_t off[8]={UINT32_C(0x10020),UINT32_C(0x0FFF0),UINT32_C(0x10004),UINT32_C(0x10020),UINT32_C(0x10010),UINT32_C(0x10030),UINT32_C(0x10000),UINT32_C(0x0FFFF)};
#ifdef HOST
 uint32_t p[8];for(uint8_t i=0;i<8;i++)p[i]=off[i];for(uint8_t i=1;i<8;i++){uint32_t k=p[i];uint8_t j=i;while(j&&p[j-1]>k){p[j]=p[j-1];j--;}p[j]=k;}uint16_t h=0xF129;for(uint8_t i=0;i<8;i++){farptrcmp_order[i]=(uint8_t)(p[i]>>16);h=farptrcmp_fold(h,p[i]);if(i){farptrcmp_gaps[i-1]=p[i]-p[i-1];h=farptrcmp_fold(h,farptrcmp_gaps[i-1]);}}return h;
#else
 const FAR uint8_t*p[8];uint32_t key[8];for(uint8_t i=0;i<8;i++){p[i]=bankwalk_table+off[i];key[i]=off[i];}for(uint8_t i=1;i<8;i++){const FAR uint8_t*k=p[i];uint32_t ko=key[i];uint8_t j=i;while(j&&p[j-1]>k){p[j]=p[j-1];key[j]=key[j-1];j--;}p[j]=k;key[j]=ko;}uint16_t h=0xF129;for(uint8_t i=0;i<8;i++){uint32_t a=key[i];farptrcmp_order[i]=(uint8_t)(a>>16);h=farptrcmp_fold(h,a);if(i){farptrcmp_gaps[i-1]=(uint32_t)(p[i]-p[i-1]);h=farptrcmp_fold(h,farptrcmp_gaps[i-1]);}}return h;
#endif
}
#endif
