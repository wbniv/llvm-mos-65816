#!/usr/bin/env python3
"""csmith_run.py — drive Csmith-generated C through the #321 +mos-a16 differential gate.

Csmith is the off-the-shelf random C generator that replaces a16_fuzz.py's hand-rolled
AST walker as the primary fuzzer generator (the builtin generator stays selectable via
`dev/run.sh fuzz --gen builtin`). The differential ENGINE is reused verbatim — this file
adds NO toolchain/emulator code; it only:

  1. generates one UB-free-at-16-bit C program per seed (csmith -s SEED <frozen profile>,
     run from examples/65816/csmith/ so Csmith reads platform.info → `integer size = 2`),
  2. force-includes the freestanding adapter (examples/65816/csmith/csmith_snes.h, which
     routes Csmith's platform_main_end checksum into the volatile `corpus_result` cell),
  3. runs a fast host-side fit pre-filter (a DEFAULT build; non-buildable seeds — region
     overflow / compile-error / missing libc — are SKIP+counted, never silently dropped),
  4. hands buildable seeds to a16_fuzz.evaluate(..., expected=None, verify=False): the
     trusted DEFAULT build is the oracle and `+mos-a16`/`+mos-xy16` must produce the
     identical corpus_result (+ the bsnes-jg leg). See the plan for why this is sound.

verify=False: Csmith TUs #include <math.h>, which a16_fuzz's `-verify-machineinstrs`
command (bare `--target=mos`, no `--config`) can't resolve — so the `--config` LTO link
inside compile_rom is the crash gate instead (a backend ICE aborts that link; it's caught
as a CompileError and classified — e.g. the a16-unmerge-s32 `long`-split legalizer gap,
which XFAILs rather than failing the run).

Runs HOST-side (csmith builds on the host into gitignored vendor/csmith; MAME + bsnes-jg
are host tools) — NOT in Docker. Drive via `dev/run.sh fuzz [--gen csmith] [N] [seed]`,
or directly:

  FUZZ_ROOT=$PWD MOS_TOOLCHAIN=$PWD/build/llvm-mos-install \
    python3 tools/csmith_run.py --count 100 --seed 1

See docs/plans/2026-06-19-321-csmith-differential-fuzzer.md.
"""
import argparse
import subprocess
import sys
from pathlib import Path

import a16_fuzz as E          # the differential engine (same tools/ dir → importable)
import torture_filter as TF   # the host-side compile/link bucketer (region-overflow, …)

# --- paths (resolved off a16_fuzz.ROOT, i.e. $FUZZ_ROOT) -----------------------------
CS = E.ROOT / "vendor" / "csmith"
CSBIN = CS / "bin" / "csmith"
ADIR = E.ROOT / "examples" / "65816" / "csmith"
ADAPTER = ADIR / "csmith_snes.h"
PLATFORM_INFO = ADIR / "platform.info"
# force-include the adapter + the Csmith runtime headers (csmith.h, safe_math.h, …)
CFLAGS = ["-include", str(ADAPTER), "-I", str(CS / "include")]

# Frozen Phase-0 generation profile: small enough to fit ~7.5 KB LoRAM, keeps
# arrays/structs/pointers/volatiles (the addressing-mode + register-pressure coverage the
# a16/xy16 work targets), no float/longlong/bitfields. `safe_math` is KEPT (default) — it
# is what makes the output UB-free at the target's 16-bit int width. Do NOT pass
# --no-safe-math. (`--no-longlong` drops 64-bit `long long`; 32-bit `long` is still
# emitted → it is what exposes the a16-unmerge-s32 legalizer gap, intentionally XFAILed.)
CSFLAGS = (
    "--max-funcs 3 --max-block-depth 3 --max-array-dim 1 --max-array-len-per-dim 4 "
    "--max-struct-fields 4 --max-expr-complexity 8 --max-pointer-depth 2 "
    "--no-bitfields --no-unions --no-packed-struct --no-float --no-longlong --concise"
).split()


def generate(seed, out):
    """csmith -s SEED <profile> -o out, run from ADIR so platform.info (16-bit int) is read."""
    subprocess.run([str(CSBIN), "-s", str(seed), *CSFLAGS, "-o", str(out)],
                   cwd=str(ADIR), check=True, capture_output=True, text=True, timeout=120)


def prefilter(src):
    """Fast host-side fit check: try a DEFAULT (non-a16) build. Returns None if it links
    (a valid oracle candidate), else (reason, diag) to SKIP+count.

    This is also what cleanly separates "not a buildable oracle" (the DEFAULT build fails →
    region-overflow / compile-error / missing libc → SKIP) from "an a16-specific defect"
    (DEFAULT builds, but +mos-a16/+mos-xy16 later fails → XFAIL/CRASH in evaluate). evaluate
    lumps all three builds into one try/except, so without this split a DEFAULT region
    overflow and a real a16 ICE would be indistinguishable. The redundant DEFAULT build
    (evaluate rebuilds it) is cheap next to the three MAME boots that dominate per-seed cost."""
    try:
        E.compile_rom(src, E.WORK / "csmith_pf.sfc", E.WORK / "csmith_pf.map",
                      flags=[], cflags=CFLAGS)
    except (E.CompileError, subprocess.TimeoutExpired) as e:
        return TF.classify(str(e))
    return None


def triage_csmith(seed, csrc, reason, extra):
    """Persist a failing seed's artifacts (mirrors a16_fuzz.triage but with the csmith
    repro line; no disasm — the .txt's values + MAME SMOKE lines are the repro evidence)."""
    E.TRIAGE.mkdir(parents=True, exist_ok=True)
    base = E.TRIAGE / ("csmith-seed-%05d" % seed)
    base.with_suffix(".c").write_text(csrc)
    info = ["seed=%d" % seed, "reason: %s" % reason,
            "repro: dev/run.sh fuzz --gen csmith 1 %d" % seed, ""]
    for k, v in (extra or {}).items():
        info += ["=== %s ===" % k, str(v), ""]
    base.with_suffix(".txt").write_text("\n".join(info))


def run_one(seed, want_bsnes):
    """Generate + differentially check one Csmith seed.
    Returns (status, msg). status in {PASS,XFAIL,SKIP,FAIL,CRASH,ERROR}."""
    src = E.WORK / "csmith.c"
    E.WORK.mkdir(parents=True, exist_ok=True)
    try:
        generate(seed, src)
    except subprocess.CalledProcessError as e:
        return "ERROR", "csmith generation failed rc=%d: %s" % (
            e.returncode, (e.stderr or "")[-160:].replace("\n", " "))
    except subprocess.TimeoutExpired:
        return "ERROR", "csmith generation timed out"
    csrc = src.read_text()

    # host-side fit pre-filter (no emulator): non-buildable-as-default seeds → SKIP+counted
    skip = prefilter(src)
    if skip is not None:
        reason, diag = skip
        return "SKIP", "%s: %s" % (reason, diag)

    def on_triage(reason, extra):
        # "corpus_result not in map" = Csmith main diverged before platform_main_end, so
        # --gc-sections dropped the unreferenced cell → legitimately SKIP, not a defect.
        if "corpus_result not in map" in reason:
            return
        triage_csmith(seed, csrc, reason, extra)

    status, msg, _ = E.evaluate(src, None, want_bsnes, on_triage, cflags=CFLAGS, verify=False)
    if status == "ERROR" and "corpus_result not in map" in msg:
        return "SKIP", "diverged-before-result (corpus_result GC'd)"
    return status, msg


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
TAGS = {"PASS": " ok ", "XFAIL": "xfail", "SKIP": "skip", "FAIL": "FAIL",
        "CRASH": "CRSH", "ERROR": "ERR "}


def main():
    try:  # stream per-seed lines even when stdout is redirected to a log file
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass

    ap = argparse.ArgumentParser(description="Csmith-generated differential fuzzer for #321 +mos-a16")
    ap.add_argument("--count", type=int, default=25)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--no-bsnes", action="store_true")
    args = ap.parse_args()

    for need in (CSBIN, ADAPTER, PLATFORM_INFO, E.TOOL / "mos-clang", E.CFG):
        if not Path(need).exists():
            sys.exit("FATAL: missing %s (run dev/fetch-csmith.sh + build the toolchain/SDK first)" % need)

    want_bsnes = not args.no_bsnes and E.JGX.exists() and E.JG_DB.is_dir()
    base, total = args.seed, args.count
    print("==> csmith differential fuzz: %d program(s), seeds %d..%d" % (total, base, base + total - 1))
    print("    csmith=%s  toolchain=%s  bsnes=%s"
          % (CSBIN, E.TOOL, "yes" if want_bsnes else "no"))

    counts = {k: 0 for k in TAGS}
    skips = {}  # SKIP reason bucket → count
    for i in range(total):
        seed = base + i
        try:
            status, msg = run_one(seed, want_bsnes)
        except Exception as e:  # never let one seed kill the run
            status, msg = "ERROR", "exception: %r" % e
        counts[status] = counts.get(status, 0) + 1
        if status == "SKIP":
            bucket = msg.split(":", 1)[0]
            skips[bucket] = skips.get(bucket, 0) + 1
        print("  [%s] seed %5d  %s" % (TAGS[status], seed, msg))

    print("==> csmith: %d/%d PASS, %d xfail, %d skip  (%d mismatch, %d crash, %d error)"
          % (counts["PASS"], total, counts["XFAIL"], counts["SKIP"],
             counts["FAIL"], counts["CRASH"], counts["ERROR"]))
    if skips:
        print("    skip buckets: " + ", ".join("%s=%d" % (k, skips[k]) for k in sorted(skips)))
    if counts["FAIL"] or counts["CRASH"] or counts["ERROR"]:
        print("    triage artifacts in %s" % E.TRIAGE)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
