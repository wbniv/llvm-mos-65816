#define FAR __attribute__((address_space(2)))
#define DP  __attribute__((address_space(1)))
/* sizeof(far*) reports 2, not 4 (clang getPointerWidthV lacks case 2). */
_Static_assert(sizeof(char FAR *)==4, "far ptr should be 4 bytes (IR p2:32:8)");
