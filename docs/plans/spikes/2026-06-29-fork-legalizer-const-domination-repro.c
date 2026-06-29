/* FORK REGRESSION repro — MOS legalizer parks a shared G_CONSTANT's def in a non-dominating block.
 *
 *   build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 -Os \
 *       -mllvm -verify-machineinstrs -c THIS_FILE -o /dev/null
 *   => fatal error: Found 1 machine code errors.
 *      *** Bad machine code: Virtual register defs don't dominate all uses. ***
 *      - function: f   - v. register: %NN   (a `G_CONSTANT i8 0`)
 *
 * NOT AN UPSTREAM BUG. The UNPATCHED upstream toolchain at the SAME commit compiles this CLEAN:
 *   /opt/llvm-mos/bin/mos-clang (clang 23.0.0git, llvm-mos c798c31416f72b395c658b5502d281a162387ab1)
 *   --target=mos -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs  => exit 0, no diagnostic.
 * It reproduces ONLY with our fork's patched toolchain (patches/llvm-mos/0001..0014 applied), and in
 * the DEFAULT 8-bit build (no +mos-a16 / +mos-xy16), so a fork patch regressed default-8-bit
 * legalization. (It also fires under +mos-a16 and +mos-xy16.)  Verified 2026-06-29.
 *
 * Introducing pass: the LEGALIZER.  -stop-after=irtranslator verifies clean; -stop-after=legalizer
 * already carries the violation.
 *
 * Mechanism: the s16 accumulator `h` and the s16 `cell` are narrowed to byte pairs.  The
 * zero-extension of the UNSIGNED `came[cell]` high byte (used in the loop HEADER's `h ^= came[cell]`)
 * and the sign-extension of the SIGNED `int8_t DX[d]` table value (used in the loop BODY's
 * `cell += DX[d]`) both reference one CSE'd `G_CONSTANT i8 0`.  The legalizer places that constant's
 * lone def in the loop body — which does not dominate the header use.  Essential ingredients (each
 * removable piece was bisected by hand): (1) the `if (cell==0) break;` diamond CFG (a straight loop
 * is clean); (2) the GENUINE indexed rodata table `DX[d]` (plain arithmetic `cell+d` is clean; an
 * all-equal table constant-folds the load away and is clean); (3) `came[cell]` consumed both as the
 * folded value and as the table index.
 *
 * NOT a demonstrated miscompile: with -verify OFF the emitted ROM computes the CORRECT result on real
 * silicon (bsnes-jg) for two distinct `came[]` fillings (all-3 -> 0x0001; {0,1,3} pattern -> 0xFFFE,
 * both == host oracle).  The value is the constant 0, so a stale/garbage read rarely diverges — but
 * the MIR violates SSA domination, so -verify-machineinstrs builds ABORT (exit 70), and it is a
 * latent miscompile risk.  In the maze demo this shape forced the fold-while-walking loop to be split
 * into two passes (examples/65816/maze.h maze_path_build + maze_fold_path).
 *
 * Disposition: fork bug — bisect to the offending patch (suspects: the legalizer-touching far/PHI
 * patches 0001/0005/0006/0013/0014 or the a16 patch 0002 leaking a hunk into the ungated 8-bit path,
 * cf. the seed-42 legalizeICmp leak) and fix/gate it; add this as a -verify regression test.
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
