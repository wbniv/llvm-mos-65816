#define FAR __attribute__((address_space(2)))
#define DP  __attribute__((address_space(1)))
/* MISSING: an array of far pointers (the banked-asset-table idiom). */
char FAR *T[4];
char r(int i){ return *T[i]; }
