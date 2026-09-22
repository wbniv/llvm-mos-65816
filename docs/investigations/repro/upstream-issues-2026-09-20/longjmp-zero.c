#include <setjmp.h>

#ifndef JUMP_VALUE
#define JUMP_VALUE 0
#endif
#define EXPECTED_VALUE (JUMP_VALUE == 0 ? 1 : JUMP_VALUE)

static jmp_buf env;
static volatile unsigned char jumped;

int main(void) {
  if (setjmp(env) == EXPECTED_VALUE)
    return jumped ? 0 : 44;
  if (jumped)
    return 42;
  jumped = 1;
  longjmp(env, JUMP_VALUE);
  return 43;
}
