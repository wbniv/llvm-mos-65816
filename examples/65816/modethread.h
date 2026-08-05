// Threaded-Code Interpreter (#127) — computed-goto joins across mixed-width handlers.
#ifndef MODETHREAD_H
#define MODETHREAD_H
#include <stdint.h>
#define MODETHREAD_RUNS 96u
#define MODETHREAD_OUT 8u
static volatile uint8_t modethread_last_op,modethread_last_pc;
static uint8_t modethread_output[MODETHREAD_OUT];
static const uint8_t modethread_prog[]={0,7,2,0x34,0x12,4,5,1,0xA5,3,0x0F,0x0F,4,5,0,29,2,0x21,0x43,6,4,5,1,0x3C,3,0xF0,0x00,4,5,0,11,2,0x01,0x80,6,4,5,7};

__attribute__((noinline)) static uint16_t modethread_run(uint8_t seed8,uint16_t seed16){
    static const void*const handlers[]={&&add8,&&xor8,&&add16,&&xor16,&&mix,&&out,&&rol16,&&halt};
    uint8_t a8=seed8,pc=0u,nout=0u;uint16_t a16=seed16,h=UINT16_C(0x1270);
#define NEXT() do{modethread_last_pc=pc;modethread_last_op=modethread_prog[pc];goto *handlers[modethread_prog[pc++]];}while(0)
    NEXT();
add8:a8=(uint8_t)(a8+modethread_prog[pc++]);NEXT();
xor8:a8^=modethread_prog[pc++];NEXT();
add16:{uint16_t v=(uint16_t)modethread_prog[pc]|((uint16_t)modethread_prog[(uint8_t)(pc+1u)]<<8);pc=(uint8_t)(pc+2u);a16=(uint16_t)(a16+v);NEXT();}
xor16:{uint16_t v=(uint16_t)modethread_prog[pc]|((uint16_t)modethread_prog[(uint8_t)(pc+1u)]<<8);pc=(uint8_t)(pc+2u);a16^=v;NEXT();}
mix:a16=(uint16_t)((a16<<3)|(a16>>13));a16^=(uint16_t)a8*UINT16_C(0x0101);NEXT();
out:modethread_output[nout++]=(uint8_t)(a8^(uint8_t)a16^(uint8_t)(a16>>8));NEXT();
rol16:a16=(uint16_t)((a16<<1)|(a16>>15));NEXT();
halt:for(uint8_t i=0;i<nout;i++)h=(uint16_t)(((h<<5)|(h>>11))^modethread_output[i]);h^=(uint16_t)a8|(uint16_t)(a16<<1);
#undef NEXT
    return h;
}
static uint16_t modethread_model(void){uint16_t h=UINT16_C(0xC127);for(uint16_t i=0;i<MODETHREAD_RUNS;i++){uint16_t v=modethread_run((uint8_t)(i*13u+7u),(uint16_t)(UINT16_C(0xA16A)^i*UINT16_C(0x1021)));h=(uint16_t)(((h<<3)|(h>>13))^v^i);}return h;}
#endif
