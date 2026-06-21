#define FAR __attribute__((address_space(2)))
#define DP  __attribute__((address_space(1)))
/* MISSING: a struct field of far-pointer type. */
struct E { char FAR *p; char tag; };
char d(struct E *e){ return *e->p; }
