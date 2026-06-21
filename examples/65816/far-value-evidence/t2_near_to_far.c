#define FAR __attribute__((address_space(2)))
#define DP  __attribute__((address_space(1)))
/* WORKS (+mos-a16): near->far cast then deref (zero-extend bank=0 -> [dp]). */
char load(char *p){ return *(char FAR *)p; }
