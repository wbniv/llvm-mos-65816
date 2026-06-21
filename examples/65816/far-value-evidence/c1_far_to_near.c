#define FAR __attribute__((address_space(2)))
#define DP  __attribute__((address_space(1)))
/* MISSING: far->near narrowing cast (drops the bank). */
char d(char FAR *p){ return *(char*)p; }
