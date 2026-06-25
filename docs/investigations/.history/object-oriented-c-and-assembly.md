| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/11fdaca) | docs(investigations): object-oriented C and assembly howto |

<!--history-meta v1
11fdaca	author	Will Norris
11fdaca	added	279
11fdaca	deleted	0
11fdaca	files	1
11fdaca	body	General guide to OOP without a C++ compiler: vtables/this-pointer/struct-first-member\ninheritance/opaque pointers in C; and the same shapes in assembly. Grounded in the\n65816/llvm-mos with MEASURED facts: the actual emitted lowering of a C virtual call\n(this in __rc2/3; load vt -> load method into __rc18/19; jmp __call_indir) and the\n__call_indir thunk (= jmp (__rc18), one instruction, tail-call trick). Covers the\n6502/65816 indirect-call idioms (JSR (abs,X) selector tables vs per-object vtable via\nJMP (vector) / RTS-trick / JML [dp]), the cost hierarchy (direct < selector < vtable),\nnear vs far method pointers (+mos-a16), and verify-by-CRC. For the rendering-lib agent.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
