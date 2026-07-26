#include <stdio.h>
#include <stdlib.h>
#include "../examples/65816/lzss.h"

int main(int argc,char **argv){
  if(argc!=2){fprintf(stderr,"usage: %s frame.idx\n",argv[0]);return 2;}
  FILE *f=fopen(argv[1],"rb"); if(!f)return 2;
  fseek(f,0,SEEK_END); long n=ftell(f); rewind(f);
  uint8_t *in=malloc(n),*out=malloc(n+n/8+8),*dec=malloc(n);
  uint16_t *head=malloc(256*2),*prev=malloc(4096*2);
  if(fread(in,1,n,f)!=(size_t)n){fclose(f);return 2;}fclose(f);
  LzssStats st; uint16_t z=lzss_compress(in,(uint16_t)n,out,(uint16_t)(n+n/8+8),head,prev,&st);
  if(!z||lzss_decode(out,z,dec,(uint16_t)n)!=(uint16_t)n)return 1;
  uint16_t h=0xffff;for(long i=0;i<n;i++){if(in[i]!=dec[i])return 1;h=lzss_fold(h,in[i]);}
  printf("raw=%ld compressed=%u reduction=%.2f%% literals=%u matches=%u longest=%u hash=0x%04X\n",
    n,z,100.0*(1.0-(double)z/n),st.literals,st.matches,st.longest,h);
  return 0;
}
