#define FAR __attribute__((address_space(2)))
#define DP  __attribute__((address_space(1)))
/* MISSING: load a far pointer back from a global, then deref. */
char FAR *G;
char d(void){ return *G; }
