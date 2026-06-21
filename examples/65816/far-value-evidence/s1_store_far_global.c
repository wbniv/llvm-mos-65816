#define FAR __attribute__((address_space(2)))
#define DP  __attribute__((address_space(1)))
/* MISSING: store a far POINTER into a global (G_STORE p2). */
char FAR *G;
void s(char FAR *p){ G = p; }
