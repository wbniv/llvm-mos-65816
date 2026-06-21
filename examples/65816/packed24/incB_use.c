#define PACKED __attribute__((address_space(3)))
#define FAR    __attribute__((address_space(2)))
char PACKED *g;
void set_g(char FAR *p){ g = (char PACKED *)p; }     /* cast p2->p3 + store p3 (3 bytes) */
char deref_g(void){ return *(char FAR *)g; }          /* load p3 + cast p3->p2 + far deref */
