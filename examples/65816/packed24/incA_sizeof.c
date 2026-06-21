#define PACKED __attribute__((address_space(3)))
#define FAR    __attribute__((address_space(2)))
/* Increment A: the packed-far TYPE exists and is 3-byte (compile-time only). */
_Static_assert(sizeof(char PACKED *) == 3, "packed far ptr must be 3 bytes");
_Static_assert(_Alignof(char PACKED *) == 1, "packed far ptr alignment 1");
char PACKED *g;
_Static_assert(sizeof(g) == 3, "stored packed ptr is 3 bytes");
char PACKED *table[16];
_Static_assert(sizeof(table) == 48, "16 packed ptrs = 48 B (vs 64 for 32-bit far)");
