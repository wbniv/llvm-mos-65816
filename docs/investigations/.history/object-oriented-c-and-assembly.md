| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/e934f93) | docs(oop): add §7 — the addressing modes that make OO/HLL cheap |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/11fdaca) | docs(investigations): object-oriented C and assembly howto |

<!--history-meta v1
e934f93	author	Will Norris
e934f93	added	49
e934f93	deleted	1
e934f93	files	1
e934f93	body	New capstone section in object-oriented-c-and-assembly.md: the 6502's\nregister-poverty critique is answered by the addressing modes — zero page as a\n256-byte register file, (dp),Y = ptr->field in one instruction, JSR (abs,X) as a\nhardware vtable — plus the 65816 additions (stack-relative frames, relocatable\ndirect page, 24-bit long-indirect) that make compiled, re-entrant code cheap. A\ntable maps each mode to the HLL/OOP construct it serves, and ties (dp),Y\nstruct-field access to the §4 measured lowering. References renumbered §7 → §8.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_015uDRVm9egPPbPPuNfvVfj2
11fdaca	author	Will Norris
11fdaca	added	279
11fdaca	deleted	0
11fdaca	files	1
11fdaca	body	General guide to OOP without a C++ compiler: vtables/this-pointer/struct-first-member\ninheritance/opaque pointers in C; and the same shapes in assembly. Grounded in the\n65816/llvm-mos with MEASURED facts: the actual emitted lowering of a C virtual call\n(this in __rc2/3; load vt -> load method into __rc18/19; jmp __call_indir) and the\n__call_indir thunk (= jmp (__rc18), one instruction, tail-call trick). Covers the\n6502/65816 indirect-call idioms (JSR (abs,X) selector tables vs per-object vtable via\nJMP (vector) / RTS-trick / JML [dp]), the cost hierarchy (direct < selector < vtable),\nnear vs far method pointers (+mos-a16), and verify-by-CRC. For the rendering-lib agent.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
