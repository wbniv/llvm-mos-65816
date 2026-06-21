#!/usr/bin/env python3
"""torture_run.py — Phase 1 differential runner for the gcc c-torture/execute suite.

Runs in-scope torture tests (examples/65816/torture/inscope.tsv, from the Phase-0 filter)
through the SAME differential gate as the corpus/fuzzer, with the DEFAULT (non-+mos-a16)
build as the trusted oracle:

  for each test:
    verify-machineinstrs (+mos-a16, +mos-xy16)      crash detector
    build default / +mos-a16 / +mos-xy16 ROMs (test + shim.o, with the -D renames)
    run default@MAME, +mos-a16@MAME, +mos-xy16@MAME, +mos-a16@bsnes-jg
    classify by the read-back corpus_result sentinel (PASS 0x600D / FAIL 0xDEAD):
      default != PASS (or default build/run fails)   -> SKIP   (target-inappropriate; not a bug)
      default == PASS and all variants == PASS        -> PASS
      default == PASS and a variant != PASS / crashes -> FAIL   (a real #321 defect)
      +mos-a16 crash matching a KNOWN_ISSUES sig      -> XFAIL  (regalloc / scavenger family)

Reuses tools/a16_fuzz.py primitives (run_mame / run_bsnes / map_lookup / verify_machineinstrs
/ classify_known) — only the shim wiring + the SKIP sentinel logic are new. Runs INSIDE the
dev container (MAME + bsnes-jg live there); drive from the host via dev/run.sh torture.

See docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md (Phase 1).
"""
import argparse
import random
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import a16_fuzz as fz  # noqa: E402  (path set above; runs with ROOT=/work in the container)

PASS_SENTINEL = 0x600D
SRCDIR = fz.ROOT / "vendor" / "c-torture" / "execute"
INSCOPE = fz.ROOT / "examples" / "65816" / "torture" / "inscope.tsv"
XFAILS = fz.ROOT / "examples" / "65816" / "torture" / "xfails.tsv"
SHIM = fz.ROOT / "examples" / "65816" / "torture" / "_shim.c"
DEFS = ["-Dmain=torture_test_main", "-Dabort=__torture_abort", "-Dexit=__torture_exit"]


def load_xfails():
    """Map test-name -> note for the confirmed-miscompile expected-fail manifest (if present)."""
    out = {}
    if XFAILS.exists():
        for ln in XFAILS.read_text().splitlines():
            ln = ln.strip()
            if ln and not ln.startswith("#"):
                f = ln.split(None, 2)
                out[f[0]] = (f[2] if len(f) > 2 else (f[1] if len(f) > 1 else ""))
    return out


def build(test, rom, mapf, flags, shim_obj, opt):
    """Compile+link a torture test (renamed) against the prebuilt shim.o -> SNES ROM.
    Raises fz.CompileError on failure (same contract as a16_fuzz.compile_rom)."""
    cmd = [str(fz.TOOL / "mos-clang"), "--config", str(fz.CFG), "-mcpu=mosw65816",
           *flags, opt, *DEFS, "-Wl,-Map=%s" % mapf, "-o", str(rom), str(test), shim_obj]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if p.returncode != 0:
        raise fz.CompileError(p.stderr or p.stdout)


def verify(test, obj, flags, opt):
    """Compile the test TU under -verify-machineinstrs to catch invalid +mos-a16/+mos-xy16 MIR.

    Uses --config (unlike a16_fuzz.verify_machineinstrs) so torture tests that #include standard
    headers (string.h, stdlib.h, …) resolve them via the SDK sysroot. Returns (ok, log)."""
    cmd = [str(fz.TOOL / "mos-clang"), "--config", str(fz.CFG), "-mcpu=mosw65816",
           *flags, opt, "-mllvm", "-verify-machineinstrs", *DEFS, "-c", "-o", str(obj), str(test)]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired as e:
        return False, "compile TIMEOUT >%ss — possible backend infinite loop" % e.timeout
    log = p.stdout + p.stderr
    return (p.returncode == 0 and "Bad machine code" not in log), log


def run_variant(rom, mapf):
    """Read corpus_result back from a built ROM on MAME. Returns (value|None, mame_line)."""
    vma, size = fz.map_lookup(mapf, "corpus_result")
    if vma is None:
        return None, "(corpus_result not in map)"
    return fz.run_mame(rom, 0x7E0000 + vma, PASS_SENTINEL, max(size or 2, 1))


def evaluate(test, shim_obj, opt, want_bsnes):
    """Return (status, detail). status in {PASS, FAIL, SKIP, XFAIL}.

    The DEFAULT build is the oracle and gates everything: a test that doesn't build OR
    doesn't self-check PASS in the trusted non-a16 build is SKIP'd (target-inappropriate)
    BEFORE +mos-a16 is judged — so only tests the default handles can produce a FAIL.
    """
    work = Path(tempfile.mkdtemp(prefix="torture-"))
    try:
        # 1) ORACLE: build + run the DEFAULT (non-a16) ROM. Non-buildable / non-PASS -> SKIP.
        droms = work / "default.sfc", work / "default.map"
        try:
            build(test, droms[0], droms[1], [], shim_obj, opt)
        except (fz.CompileError, subprocess.TimeoutExpired):
            return "SKIP", "default build fails at %s (unsupported)" % opt
        got_d, _ = run_variant(*droms)
        if got_d != PASS_SENTINEL:
            return "SKIP", "default != PASS (got %s) — target-inappropriate" % _hex(got_d)

        # 2) crash detector: -verify-machineinstrs under +mos-a16 then +mos-xy16.
        for tag, flags in (("a16", fz.A16), ("xy16", fz.XY16)):
            ok, vlog = verify(test, work / ("%s.vo" % tag), flags, opt)
            if not ok:
                kid = fz.classify_known(vlog)
                return ("XFAIL", "known issue [%s]" % kid) if kid else ("FAIL", "verify-machineinstrs (+mos-%s) crash" % tag)

        # 3) build the +mos-a16 / +mos-xy16 ROMs (default already built PASS).
        roms = {}
        for tag, flags in (("a16", fz.A16), ("xy16", fz.XY16)):
            rom, mapf = work / ("%s.sfc" % tag), work / ("%s.map" % tag)
            try:
                build(test, rom, mapf, flags, shim_obj, opt)
            except (fz.CompileError, subprocess.TimeoutExpired) as e:
                kid = fz.classify_known(str(e))
                return ("XFAIL", "known issue [%s]" % kid) if kid else ("FAIL", "%s build fails (default ok)" % tag)
            roms[tag] = (rom, mapf)

        # 4) every +mos-a16 / +mos-xy16 variant must also reach PASS, on both emulators.
        got_a, _ = run_variant(*roms["a16"])
        got_x, _ = run_variant(*roms["xy16"])
        vals = {"a16@MAME": got_a, "xy16@MAME": got_x}
        if want_bsnes:
            vma, size = fz.map_lookup(roms["a16"][1], "corpus_result")
            got_jg, _ = fz.run_bsnes(roms["a16"][0], vma, max(size or 2, 1), PASS_SENTINEL)
            if got_jg not in (None, "skip"):
                vals["a16@bsnes"] = got_jg
        bad = {k: v for k, v in vals.items() if v != PASS_SENTINEL}
        if bad:
            return "FAIL", "default PASS but " + ", ".join("%s=%s" % (k, _hex(v)) for k, v in bad.items())
        return "PASS", "all variants PASS (0x600D)"
    finally:
        __import__("shutil").rmtree(work, ignore_errors=True)


def _hex(v):
    return "0x%04X" % v if isinstance(v, int) else str(v)


def load_inscope():
    return [ln.strip() for ln in INSCOPE.read_text().splitlines()
            if ln.strip() and not ln.startswith("#")]


def main():
    # Line-buffer stdout so a long run's per-test lines stream to a redirected log in real time
    # (Python block-buffers to a pipe by default, which hides progress for hours).
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="Phase-1 differential runner for gcc c-torture/execute")
    ap.add_argument("count", nargs="?", type=int, default=30, help="number of in-scope tests (default 30)")
    ap.add_argument("--opt", default="-Os", help="optimization level (default -Os)")
    ap.add_argument("--start", type=int, default=0, help="offset into inscope.tsv (for sharding)")
    ap.add_argument("--tests", nargs="*", help="explicit test filenames (override count/start)")
    ap.add_argument("--sample", type=int, default=0,
                    help="run a seeded pseudo-random subset of N in-scope tests (overrides count/start)")
    ap.add_argument("--sample-seed", type=int, default=1, help="seed for --sample selection (reproducible)")
    ap.add_argument("--no-bsnes", action="store_true")
    # argparse rejects a separate-token value that looks like a flag (`--opt -Os`), so fold it
    # into the `=` form, which accepts dash-values. Lets users type the natural `--opt -Os`.
    raw, argv = sys.argv[1:], []
    i = 0
    while i < len(raw):
        if raw[i] == "--opt" and i + 1 < len(raw):
            argv.append("--opt=%s" % raw[i + 1]); i += 2
        else:
            argv.append(raw[i]); i += 1
    args = ap.parse_args(argv)

    for need in (fz.TOOL / "mos-clang", fz.CFG, SHIM, INSCOPE):
        if not Path(need).exists():
            sys.exit("FATAL: missing %s (run dev/fetch-torture.sh + tools/torture_filter.py + build first)" % need)
    want_bsnes = not args.no_bsnes and fz.JGX.exists() and fz.JG_DB.is_dir()

    # Selection: explicit --tests > seeded pseudo-random --sample > sequential --start/count slice.
    # --sample picks a representative spread (inscope.tsv is alphabetical, so a head slice clusters);
    # sampling is seeded for reproducibility, then sorted so the per-test output order stays stable.
    if args.tests:
        names, sel = args.tests, "explicit"
    elif args.sample:
        pool = load_inscope()
        names = sorted(random.Random(args.sample_seed).sample(pool, min(args.sample, len(pool))))
        sel = "sample=%d seed=%d" % (args.sample, args.sample_seed)
    else:
        names = load_inscope()[args.start: args.start + args.count]
        sel = "start=%d" % args.start
    print("==> torture-run: %d test(s), %s, %s, default==+mos-a16==+mos-xy16 (MAME%s)"
          % (len(names), args.opt, sel, " + bsnes-jg" if want_bsnes else ""))

    shim_dir = tempfile.mkdtemp(prefix="torture-shim-")
    shim_obj = str(Path(shim_dir) / "_shim.o")
    sp = subprocess.run([str(fz.TOOL / "mos-clang"), "--config", str(fz.CFG), "-mcpu=mosw65816",
                         args.opt, "-c", str(SHIM), "-o", shim_obj], capture_output=True, text=True)
    if sp.returncode != 0:
        sys.exit("FATAL: shim precompile failed:\n%s" % sp.stderr)

    xfails = load_xfails()
    tally = {"PASS": 0, "FAIL": 0, "SKIP": 0, "XFAIL": 0}
    fails = []
    for name in names:
        test = SRCDIR / name
        if not test.exists():
            print("  %-22s ERROR  not found" % name); continue
        status, detail = evaluate(test, shim_obj, args.opt, want_bsnes)
        # A confirmed-miscompile in the expected-fail manifest is XFAIL, not FAIL, so the gate
        # stays green-modulo-known while each backlog defect is triaged + fixed. An UNEXPECTED pass
        # (status PASS but listed) is surfaced as XPASS — the row should be removed (defect fixed).
        if name in xfails:
            if status == "FAIL":
                status, detail = "XFAIL", "expected c-torture miscompile (%s)" % xfails[name]
            elif status == "PASS":
                status, detail = "XPASS", "listed in xfails.tsv but now PASSes — remove the row"
        tally[status] = tally.get(status, 0) + 1
        mark = {"PASS": "  ", "SKIP": "··", "XFAIL": "xf", "XPASS": "XP", "FAIL": "!!"}.get(status, "??")
        print("  %s %-22s %-5s %s" % (mark, name, status, detail))
        if status == "FAIL":
            fails.append((name, detail))

    xp = tally.get("XPASS", 0)
    print("==> torture-run: %d PASS, %d FAIL, %d SKIP, %d XFAIL%s (of %d)"
          % (tally["PASS"], tally["FAIL"], tally["SKIP"], tally["XFAIL"],
             (", %d XPASS" % xp) if xp else "", len(names)))
    if fails:
        print("    FAILs (real #321 defects to triage):")
        for n, d in fails:
            print("      %-22s %s" % (n, d))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
