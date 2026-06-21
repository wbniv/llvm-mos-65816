#define PACKED __attribute__((address_space(3)))
char PACKED *g;            /* expect 3-byte object */
char PACKED *table[16];    /* expect 48-byte object */
