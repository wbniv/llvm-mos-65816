#define FAR __attribute__((address_space(2)))
#define DP  __attribute__((address_space(1)))
/* WORKS: transient deref of a constant far address (absolute-long). */
char load(void){ return *(volatile char FAR *)0x7E1234; }
