#!/usr/bin/env python3
"""torture_filter.py — Phase 0 host-side compile/link filter for the gcc c-torture suite.

For each vendor/c-torture/execute/*.c, try to build a DEFAULT (non-+mos-a16) SNES ROM
with the shim (examples/65816/torture/_shim.c). NO emulator, NO +mos-a16 — this just
partitions the suite into:

  in-scope     — compiles + links into a valid SNES ROM (a candidate for the differential
                 runner; whether it actually PASSes is decided later, on the emulator).
  unsupported  — does NOT build, with a bucketed reason:
                   compile-error    clang rejects it (language/feature/16-bit-int assumptions)
                   undefined-symbol needs libc we don't provide (printf/malloc/setjmp/…)
                   region-overflow  static data/code exceeds SNES RAM/ROM
                   link-other       any other link failure
                   timeout          compile/link exceeded the per-test budget

Emits examples/65816/torture/{inscope,unsupported}.tsv and logs the counts. Nothing is
silently dropped — every test lands in exactly one bucket.

Mirrors a16_fuzz.compile_rom's DEFAULT-build command (kept in sync by hand; this is the
fast, parallel, emulator-free path). Run on the host:

  FUZZ_ROOT=$PWD MOS_TOOLCHAIN=$PWD/build/llvm-mos-install python3 tools/torture_filter.py

See docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md.
"""
import argparse
import concurrent.futures as cf
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(os.environ.get("FUZZ_ROOT", os.getcwd()))
TOOL = Path(os.environ.get("MOS_TOOLCHAIN", str(ROOT / "build" / "llvm-mos-install"))) / "bin"
CFG = ROOT / "build" / "install" / "bin" / "mos-snes.cfg"
SHIM = ROOT / "examples" / "65816" / "torture" / "_shim.c"
SRCDIR = ROOT / "vendor" / "c-torture" / "execute"
OUTDIR = ROOT / "examples" / "65816" / "torture"

# Preprocessor renames: the test's main becomes torture_test_main(); its abort()/exit()
# route to the shim's stubs (so they don't collide with the SDK libc).
DEFS = ["-Dmain=torture_test_main", "-Dabort=__torture_abort", "-Dexit=__torture_exit"]


CLANG_ERR = __import__("re").compile(r"^.+?:\d+:\d+: (?:fatal )?error:", __import__("re").M)

# gcc dg-require-effective-target: the test author's own declaration of what the target must
# provide. Our `int` is 16-bit, so a test requiring a wider int is target-inappropriate — it
# can pass the trusted default build by UB-luck and then "fail" +mos-a16 as a FALSE POSITIVE
# (e.g. pr7284-1's `n << 24`). Deny ONLY the provably-unsatisfiable integer-width requirements
# so a misclassification can only ever skip a target-inappropriate test, never drop a valid one.
# We DO satisfy label_values / indirect_jumps (computed goto works — 20071210-1 passes), so
# those are deliberately NOT denied. Extend DG_REQUIRE_DENY if a future false positive warrants.
DG_REQUIRE_RE = __import__("re").compile(r"dg-require-effective-target\s+(\w+)")
DG_REQUIRE_DENY = {"int32plus", "int128"}


def classify(stderr):
    """Bucket a build failure into one reason category + a 1-line diag, in precedence order.

    1. compile-error    a clang front-end `file:line:col: error:` (language / feature / 16-bit-int).
    2. undefined-symbol  ld.lld can't resolve a libc symbol (printf/malloc/setjmp/__putchar/…).
    3. region-overflow   ld.lld: static data/code won't fit the SNES RAM/ROM regions.
    4. link-other        any other linker failure.
    Front-end errors win over the overflow heuristic so a compile diagnostic that merely
    *mentions* "overflow"/"exceeds" isn't mis-bucketed as a region overflow (a link-only event).
    """
    m = CLANG_ERR.search(stderr)
    if m:
        return "compile-error", _first(stderr, ("error:",))
    low = stderr.lower()
    if "undefined symbol" in low or "undefined reference" in low:
        # A test can miss several libc symbols, and ld.lld lists them in a nondeterministic
        # order — report the lexicographically smallest (+ count) so the manifest is reproducible.
        syms = sorted(set(__import__("re").findall(r"undefined (?:symbol|reference)(?:s)?: (\S+)", stderr)))
        if syms:
            extra = " (+%d more)" % (len(syms) - 1) if len(syms) > 1 else ""
            return "undefined-symbol", "ld.lld: error: undefined symbol: %s%s" % (syms[0], extra)
        return "undefined-symbol", _first(stderr, ("undefined symbol", "undefined reference"))
    if "ld.lld" in low and any(kw in low for kw in
                               ("will not fit", "overflowed", "does not fit", "out of range", "no space")):
        return "region-overflow", _first(stderr, ("ld.lld",))
    if "ld.lld" in low:
        # Prefer the actual error line over the generic "command failed" / crash-dump banner.
        return "link-other", _first(stderr, ("ld.lld: error:", "Assertion", "PLEASE submit",
                                             "Invalid call record", "ld.lld"))
    return "link-other", _first(stderr, ("error:", "ld.lld")) or "(no diagnostic)"


def _first(text, needles):
    for line in text.splitlines():
        ls = line.strip()
        for n in needles:
            if n in ls:
                return ls[:200]
    return ""


def build_one(cfile, opt, timeout, shim_obj):
    """Return (name, 'inscope'|reason, diag). Link test (with -D renames) + prebuilt shim.o -> ROM.

    The shim is precompiled ONCE (build_shim) because the -D renames must hit only the test
    TU — applied to the whole command line they'd also rename the shim's own main() and clash.
    """
    name = cfile.name
    # Honor dg-require-effective-target BEFORE building: a test that requires an integer
    # width our 16-bit-int target can't provide is target-inappropriate (skip it so it can't
    # masquerade as a +mos-a16 defect). Cheap regex over the source; no compile in the denied case.
    try:
        text = cfile.read_text(errors="replace")
    except OSError:
        text = ""
    for req in DG_REQUIRE_RE.findall(text):
        if req in DG_REQUIRE_DENY:
            return name, "dg-require-unsupported", "requires %s (16-bit-int target cannot satisfy)" % req
    with tempfile.TemporaryDirectory() as td:
        rom = Path(td) / "t.sfc"
        mapf = Path(td) / "t.map"
        cmd = [str(TOOL / "mos-clang"), "--config", str(CFG), "-mcpu=mosw65816",
               opt, *DEFS, "-Wl,-Map=%s" % mapf, "-o", str(rom), str(cfile), shim_obj]
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            return name, "timeout", "compile/link > %ss" % timeout
        except Exception as e:  # toolchain missing, etc. — surface, don't swallow
            return name, "error", "%s: %s" % (type(e).__name__, e)
        if p.returncode == 0 and rom.exists():
            return name, "inscope", ""
        reason, diag = classify(p.stderr or p.stdout)
        return name, reason, sanitize(diag)


def sanitize(diag):
    """Strip machine-specific paths so the committed manifest is portable + deterministic:
    the repo root becomes relative, and random tempdir paths collapse to <tmp>."""
    diag = diag.replace(str(ROOT) + "/", "").replace(str(ROOT), "")
    return __import__("re").sub(r"/tmp/\S+", "<tmp>", diag)


def main():
    ap = argparse.ArgumentParser(description="Phase-0 compile/link filter for gcc c-torture/execute")
    ap.add_argument("--opt", default="-Os", help="optimization level for the default build (default -Os)")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 4) - 1))
    ap.add_argument("--timeout", type=int, default=60, help="per-test compile/link budget, seconds")
    ap.add_argument("--limit", type=int, default=0, help="only the first N tests (debug)")
    ap.add_argument("--subdirs", action="store_true", help="also include builtins/ and ieee/ subdirs")
    args = ap.parse_args()

    for need in (TOOL / "mos-clang", CFG, SHIM, SRCDIR):
        if not Path(need).exists():
            sys.exit("FATAL: missing %s (run dev/fetch-torture.sh + build the toolchain/SDK first)" % need)

    tests = sorted(SRCDIR.glob("*.c"))
    if args.subdirs:
        tests += sorted(SRCDIR.glob("*/*.c"))
    if args.limit:
        tests = tests[: args.limit]
    total = len(tests)
    print("==> torture filter: %d tests, default build %s, %d jobs" % (total, args.opt, args.jobs))

    # Precompile the shim ONCE (no -D), reused by every test link.
    shim_dir = tempfile.mkdtemp(prefix="torture-shim-")
    shim_obj = str(Path(shim_dir) / "_shim.o")
    sp = subprocess.run([str(TOOL / "mos-clang"), "--config", str(CFG), "-mcpu=mosw65816",
                         args.opt, "-c", str(SHIM), "-o", shim_obj], capture_output=True, text=True)
    if sp.returncode != 0:
        sys.exit("FATAL: shim precompile failed:\n%s" % sp.stderr)

    inscope, unsupported = [], []
    buckets = {}
    done = 0
    with cf.ProcessPoolExecutor(max_workers=args.jobs) as ex:
        futs = {ex.submit(build_one, t, args.opt, args.timeout, shim_obj): t for t in tests}
        for fut in cf.as_completed(futs):
            name, verdict, diag = fut.result()
            done += 1
            if verdict == "inscope":
                inscope.append(name)
            else:
                unsupported.append((name, verdict, diag))
                buckets[verdict] = buckets.get(verdict, 0) + 1
            if done % 100 == 0 or done == total:
                sys.stderr.write("\r    %d/%d (in-scope %d)" % (done, total, len(inscope)))
                sys.stderr.flush()
    sys.stderr.write("\n")

    inscope.sort()
    unsupported.sort()
    OUTDIR.mkdir(parents=True, exist_ok=True)
    with (OUTDIR / "inscope.tsv").open("w") as f:
        f.write("# gcc c-torture/execute tests that compile+link a DEFAULT SNES ROM (gcc-14.2.0).\n")
        f.write("# Generated by tools/torture_filter.py --opt %s. One test per line.\n" % args.opt)
        for n in inscope:
            f.write(n + "\n")
    with (OUTDIR / "unsupported.tsv").open("w") as f:
        f.write("# gcc c-torture/execute tests that do NOT build a DEFAULT SNES ROM (gcc-14.2.0).\n")
        f.write("# Generated by tools/torture_filter.py --opt %s.\n" % args.opt)
        f.write("# test\treason\tdiagnostic\n")
        for n, r, d in unsupported:
            f.write("%s\t%s\t%s\n" % (n, r, d))

    print("==> %d/%d in-scope, %d unsupported" % (len(inscope), total, len(unsupported)))
    for r in sorted(buckets):
        print("      %-16s %d" % (r, buckets[r]))
    print("==> wrote %s , %s" % (OUTDIR / "inscope.tsv", OUTDIR / "unsupported.tsv"))


if __name__ == "__main__":
    main()
