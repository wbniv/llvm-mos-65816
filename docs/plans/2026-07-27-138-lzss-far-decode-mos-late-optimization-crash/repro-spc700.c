/* #138 minimal C reproducer — MOS Late Optimizations segfault.
 *
 * Crashes clang in `MOS Late Optimizations` on `@f` at -O1/-O2/-Os/-Oz.
 * Nothing fork-specific: plain C, upstream SPC700 target, no +mos-a16, no
 * far pointers, no SNES platform, no asset corpus.
 *
 *   build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosspc700 \
 *       -Os -S -o /dev/null docs/plans/.../repro-spc700.c
 *
 * Root cause: register allocation places one of the eight live bytes in an
 * imaginary (zero-page) register, and SPC700 legalises `$rcN = LDImm imm`
 * (`mov dp, #imm`) via MOSInstrInfo::getRegClass widening LDImm's def class to
 * Anyi8.  MOSLateOptimization::combineLdImm switches destinations over
 * {A, X, Y} only and then unconditionally writes through the resulting
 * ImmLoad*, which is null for an imaginary destination.
 *
 * The eight simultaneously-live bytes are headroom, not a threshold: a sweep
 * (2026-07-31, MIR via -mllvm -stop-before=mos-late-opt fed to an unfixed
 * llc -run-pass=mos-late-opt) shows THREE live bytes crash at every level
 * above -O0, and two crash at -Oz. See the guard-hardening follow-up plan.
 */
volatile unsigned char io;

unsigned char f(unsigned char n) {
  unsigned char a = 7, b = 9, c = 11, d = 13, e = 15, g = 17, h = 19, i = 21;
  while (n--) {
    io = a; io = b; io = c; io = d;
    io = e; io = g; io = h; io = i;
    a += n;
    b ^= n;
  }
  return a + b + c + d + e + g + h + i;
}
