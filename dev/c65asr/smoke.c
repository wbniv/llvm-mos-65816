#define RESULT (*(volatile unsigned short *)0x0400)
#define FLAG   (*(volatile unsigned char  *)0x0402)
int main(void){ RESULT = 0xBEEF; FLAG = 0x5A; for(;;){} }
