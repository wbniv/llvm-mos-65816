#define FAR __attribute__((address_space(2)))
#define DP  __attribute__((address_space(1)))
/* MISSING: dp->near cast + deref (can SEGFAULT the compiler without -verify). */
char d(char DP *p){ return *(char*)p; }
