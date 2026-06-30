/* FORK REGRESSION repro (ROOT-CAUSED + FIX VERIFIED 2026-06-29) — patch 0002's absolute-indexed-
 * addressing seed-56 workaround replaces a value's uses with a BODY-block def that doesn't dominate a
 * SIBLING (loop-header) use.
 *
 *   build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 -Os \
 *       -mllvm -verify-machineinstrs -c THIS_FILE -o /dev/null
 *   => fatal error: Found 1 machine code errors.
 *      *** Bad machine code: Virtual register defs don't dominate all uses. ***
 *
 * NOT AN UPSTREAM BUG. The UNPATCHED upstream toolchain at the SAME commit compiles this CLEAN:
 *   /opt/llvm-mos/bin/mos-clang (clang 23.0.0git, llvm-mos c798c31416f72b395c658b5502d281a162387ab1)
 *   --target=mos -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs  => exit 0, no diagnostic.
 * Reproduces ONLY with our fork's patched toolchain, in DEFAULT 8-bit AND +mos-a16 AND +mos-xy16.
 * Introducing pass: the LEGALIZER (-stop-after=irtranslator clean; -stop-after=legalizer dirty).
 *
 * ROOT CAUSE (pinned by an asserts-build -debug-only=legalizer trace; bisected to patch 0002):
 * MOSLegalizerInfo::tryAbsoluteIndexedAddressing's seed-56 workaround folds DX[d] into an
 * absolute-indexed load by building, AT THE G_PtrAdd's (body) BLOCK,
 *     Lo = trunc(NewOffset); ZeroHi = G_CONSTANT(0); Explicit16 = G_MERGE(Lo, ZeroHi);
 * then replacing EVERY use of NewOffset with Explicit16. But NewOffset (the came value, zero-extended)
 * is ALSO used in a SIBLING block — it is the `h ^ came` operand in the loop HEADER as well as the
 * DX[d] index in the loop BODY. The use-replacement rewrites the header use to Explicit16, defined in
 * the body, which does not dominate it. (The "shared G_CONSTANT 0" framing in the first draft of this
 * note was a red herring; legalizeSExt is byte-identical to upstream and uninvolved.) Essential repro
 * pieces: (1) the `if (cell==0) break;` diamond CFG (a straight loop is clean); (2) the GENUINE indexed
 * rodata table DX[d] (plain `cell+d` is clean; an all-equal table constant-folds the load away);
 * (3) came[cell] consumed both as the folded value and as the table index — one value across two blocks.
 *
 * FIX (in patch 0002, MOSLegalizerInfo::tryAbsoluteIndexedAddressing): insert the trunc/zero-extend at
 * NewOffset's DEFINITION (which by SSA dominates every use) instead of at the G_PtrAdd:
 *     MachineInstr *OffDef = MRI.getVRegDef(NewOffset);
 *     Builder.setInsertPt(*OffDef->getParent(),
 *         OffDef->isPHI() ? OffDef->getParent()->getFirstNonPHI()
 *                         : std::next(OffDef->getIterator()));
 * Verified on an isolated 0001+0002 bisect toolchain: -verify clean in all 3 modes; no miscompile
 * (a varied-came differential runs == host on bsnes-jg in all 3 modes); a 285-compile -verify sweep
 * over the corpus + a16/xy16 micro-tests has 0 new domination failures.
 *
 * NOT a demonstrated miscompile: with -verify OFF the emitted ROM is correct (the rewritten use still
 * reads the right value on the executed path); the MIR just violates SSA domination, aborting -verify
 * builds (exit 70). In the maze demo this shape was first worked around by splitting the loop into two
 * passes (examples/65816/maze.h maze_path_build + maze_fold_path) — revisit once the fix is live, per
 * the project's "stress the compiler, never work around it" directive.
 */
#include <stdint.h>
static const int8_t DX[4] = { 0, 1, 0, -1 };   /* genuine indexed table; constant-foldable away if all-equal */
extern uint8_t came[240];
uint16_t f(uint16_t h) {
    uint16_t cell = 239;
    for (uint16_t step = 0; step <= 240u; step++) {
        h = (uint16_t)((uint16_t)(h << 1) ^ (uint16_t)came[cell]);  /* came high byte == G_CONSTANT 0 (header use) */
        if (cell == 0) break;                                        /* diamond CFG — essential */
        uint8_t d = came[cell];
        cell = (uint16_t)(cell + (uint16_t)DX[d]);                   /* sign-ext of int8 DX[d] reuses that 0 (body def) */
    }
    return h;
}
