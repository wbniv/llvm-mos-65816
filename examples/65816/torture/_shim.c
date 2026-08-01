/* examples/65816/torture/_shim.c — adapt a self-checking gcc c-torture/execute test
 * onto the SNES value-readback harness (host == default == +mos-a16 == +mos-xy16).
 *
 * A torture test signals via abort()/exit(0)/return-0 from main; our harness reads a
 * `volatile unsigned short corpus_result` back from emulator RAM. This TU is compiled
 * ALONGSIDE the test, which is preprocessed with:
 *     -Dmain=torture_test_main  -Dabort=__torture_abort  -Dexit=__torture_exit
 * so the test's main becomes torture_test_main(), and its abort()/exit() calls route
 * here instead of colliding with the SDK libc's own abort/exit definitions.
 *
 *   PASS sentinel 0x600D — main returned 0 (or exit(0)).
 *   FAIL sentinel 0xDEAD — a self-check failed (abort / exit(nonzero) / return nonzero).
 *
 * The classifier (tools/torture_run.py, Phase 1) reads corpus_result: PASS on the
 * default build makes the test in-scope; any +mos-a16 / +mos-xy16 disagreement is a
 * real defect. See docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md.
 *
 * Phase 0 (tools/torture_filter.py) compiles+links this with each test against the
 * DEFAULT build only — no emulator — purely to bucket tests into in-scope vs
 * unsupported (compile-fail / undefined libc symbol / RAM-or-ROM overflow).
 */

#define TORTURE_PASS 0x600D
#define TORTURE_FAIL 0xDEAD

volatile unsigned short corpus_result;

/* Empty parens (no prototype) so a test whose main is int main(int,char**) still
 * links and is callable with no args — the argv-using tests are rare and self-select
 * out at run time. */
int torture_test_main();

void __torture_abort(void) {
  corpus_result = TORTURE_FAIL;
  for (;;) __asm__ volatile("wai");
}

void __torture_exit(int code) {
  corpus_result = (unsigned short)(code ? TORTURE_FAIL : TORTURE_PASS);
  for (;;) __asm__ volatile("wai");
}

int main(void) {
  int r = torture_test_main();
  corpus_result = (unsigned short)(r ? TORTURE_FAIL : TORTURE_PASS);
  for (;;) __asm__ volatile("wai");
}
