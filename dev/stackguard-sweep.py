#!/usr/bin/env python3
"""Sweep the soft-stack overlap guard across the SNES corpus and demo gates, then tabulate margins.

  dev/stackguard-sweep.py corpus [--out DIR] [-j N] [--frames N] [--only a,b]
      Build every examples/snes/corpus program named in expected.tsv (corpus_result rows) in the
      three configurations tools/a16_fuzz.py gates (default, +mos-a16, +mos-xy16; -Os, SDK config,
      the same command line as a16_fuzz.compile_rom) and run each in build/jgxcheck for the gate's
      frame budget with its expected value asserted (JGX_POLL: a run stops at the frame corpus_result
      first equals the expected value, --no-poll runs every frame). One guard record per run.
  dev/stackguard-sweep.py demos [--out DIR] [--timeout S] [--only g1,g2]
      Run every SNES demo's own gate (dev/run.sh <gate>, JG_ONLY=1: bsnes-jg leg only, no MAME) one
      after another and keep the guard records its jgxcheck runs write. Sequential on purpose: the
      gates share build/ scratch names. Gates without a jgxcheck leg produce no record and are listed
      as unguarded.
  dev/stackguard-sweep.py report DIR_OR_TSV...
      Print every record, smallest margin first, plus the violations and a margin histogram.

Records are the TSV rows tools/stackguard.h appends to JGX_STACKGUARD_LOG: rom, program, config,
status, min SP, end of static data, stack top, margin (bytes), pc of the minimum, function, bounds source.
Run from the checkout whose build/ holds the toolchain, SDK and the patched build/jgxcheck. The corpus
mode's compiler and emulator runs get `ulimit -c 0` and `ulimit -v 2000000` through setrlimit, plus a
timeout. The demo gates run in dev/run.sh's container (`--ulimit core=0`); a virtual-memory limit on the
docker client itself makes it abort, so only the core limit and the timeout apply there.
"""
import argparse
import concurrent.futures as cf
import csv
import datetime as dt
import os
import resource
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
TOOL = Path(os.environ.get("MOS_TOOLCHAIN", str(BUILD / "llvm-mos-install"))) / "bin"
CFG = BUILD / "install" / "bin" / "mos-snes.cfg"
JGX = BUILD / "jgxcheck"
DB = ROOT / "vendor" / "bsnes-jg" / "Database"
A16 = ["-Xclang", "-target-feature", "-Xclang", "+mos-a16"]
XY16 = ["-Xclang", "-target-feature", "-Xclang", "+mos-xy16"]
CONFIGS = [("default", []), ("a16", A16), ("xy16", XY16)]
FIELDS = ["rom", "program", "config", "status", "min_sp", "static_end", "stack_top", "margin", "pc", "function", "source"]


def now():
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_AS, (2000000 * 1024, 2000000 * 1024))


def limits_core_only():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def run(cmd, timeout, env=None, cwd=None, preexec=limits):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout,
                          env=env, cwd=cwd, preexec_fn=preexec)


def read_records(path):
    rows = []
    for line in Path(path).read_text().splitlines():
        parts = line.split("\t")
        if len(parts) == len(FIELDS):
            rows.append(dict(zip(FIELDS, parts)))
    return rows


def margin_key(r):
    try:
        return int(r["margin"])
    except ValueError:
        return 10 ** 9


# ---------------------------------------------------------------------------------------------- corpus
def corpus_one(name, cfile, expected, cfgname, flags, out, frames, timeout, poll):
    work = out / "corpus-roms"
    rom, mapf = work / f"{name}.{cfgname}.sfc", work / f"{name}.{cfgname}.map"
    cmd = [str(TOOL / "mos-clang"), "--config", str(CFG), "-mcpu=mosw65816", *flags, "-Os",
           f"-Wl,-Map={mapf}", "-o", str(rom), str(ROOT / "examples" / "snes" / cfile)]
    try:
        p = run(cmd, timeout)
    except subprocess.TimeoutExpired:
        return (name, cfgname, "BUILD-TIMEOUT", "")
    if p.returncode != 0:
        return (name, cfgname, "BUILD-FAIL", p.stdout.strip().splitlines()[-1] if p.stdout.strip() else "")
    run([sys.executable, str(ROOT / "tools" / "snes-checksum.py"), str(rom)], 60)
    addr = None
    for line in mapf.read_text().splitlines():
        t = line.split()
        if len(t) >= 5 and t[-1] == "corpus_result":
            addr = (int(t[0], 16), int(t[2], 16))
            break
    if not addr:
        return (name, cfgname, "NO-RESULT-SYMBOL", "")
    env = dict(os.environ, JGX_PROGRAM=name, JGX_CONFIG=f"{cfgname} -Os",
               JGX_STACKGUARD_LOG=str(out / "corpus.tsv"))
    if poll and expected != 0:
        env["JGX_POLL"] = "1"   # stop at the frame corpus_result == expected; frames is then a budget
    cmd = [str(JGX), str(rom), str(DB), "0x%X" % addr[0], str(max(addr[1], 1)), "0x%X" % expected, str(frames)]
    try:
        p = run(cmd, timeout, env=env)
    except subprocess.TimeoutExpired:
        return (name, cfgname, "RUN-TIMEOUT", "")
    smoke = next((ln for ln in p.stdout.splitlines() if ln.startswith("SMOKE:")), "(no SMOKE line)")
    return (name, cfgname, f"rc={p.returncode}", smoke)


def cmd_corpus(args):
    out = (Path(args.out).resolve() if args.out else BUILD / "stackguard-sweep" / now())
    (out / "corpus-roms").mkdir(parents=True, exist_ok=True)
    rows = []
    for line in (ROOT / "examples" / "snes" / "corpus" / "expected.tsv").read_text().splitlines():
        t = line.split(None, 3)
        if len(t) >= 3 and not t[0].startswith("#") and t[1] == "corpus_result":
            rows.append((Path(t[0]).stem, t[0], int(t[2], 0)))
    if args.only:
        keep = set(args.only.split(","))
        rows = [r for r in rows if r[0] in keep]
    print(f"{now()} corpus sweep: {len(rows)} programs x {len(CONFIGS)} configs, {args.frames} frames, "
          f"-j{args.jobs}, out={out}", flush=True)
    results = []
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        futs = [ex.submit(corpus_one, n, c, e, cn, fl, out, args.frames, args.timeout, not args.no_poll)
                for n, c, e in rows for cn, fl in CONFIGS]
        for i, f in enumerate(cf.as_completed(futs), 1):
            r = f.result()
            results.append(r)
            print(f"{now()} [{i}/{len(futs)}] {r[0]} {r[1]} {r[2]} {r[3][:120]}", flush=True)
    with (out / "corpus-results.tsv").open("w") as fh:
        for r in sorted(results):
            fh.write("\t".join(r) + "\n")
    print(f"{now()} corpus sweep done: {out}", flush=True)
    return 0


# ---------------------------------------------------------------------------------------------- demos
SPECIAL = {"mandel-display": "mandel-shot", "spigot": "pi", "snes-video-codec": "snes-video-reel",
           "snes-video-dma": "snes-video-reel"}
EXCLUDE = {"hello", "apollo-reel", "snes-video-codec-bench", "snes-video-stream"}


def gate_map():
    gates = []
    for src in sorted((ROOT / "examples" / "snes").glob("*.c")):
        d = src.stem
        g = SPECIAL.get(d, d)
        if d in EXCLUDE or not (ROOT / "dev" / f"{g}.sh").exists():
            continue
        if g not in gates:
            gates.append(g)
    return gates


def cmd_demos(args):
    out = (Path(args.out).resolve() if args.out else BUILD / "stackguard-sweep" / now())
    (out / "demos").mkdir(parents=True, exist_ok=True)
    gates = args.only.split(",") if args.only else gate_map()
    print(f"{now()} demo sweep: {len(gates)} gates (JG_ONLY=1), out={out}", flush=True)
    rel = out.relative_to(ROOT)
    res = out / "demos-results.tsv"
    with res.open("a") as fh:
        for i, g in enumerate(gates, 1):
            log, tsv = out / "demos" / f"{g}.log", out / "demos" / f"{g}.tsv"
            env = dict(os.environ, JG_ONLY="1", JGX_STACKGUARD_LOG=f"/work/{rel}/demos/{g}.tsv")
            t0 = dt.datetime.now()
            try:
                # The docker client (Go) aborts under RLIMIT_AS, so only core dumps are limited here; the gate's
                # compiler and emulator run inside the container, which `--ulimit core=0` already covers.
                p = run([str(ROOT / "dev" / "run.sh"), g], args.timeout, env=env, cwd=ROOT, preexec=limits_core_only)
                rc, text = p.returncode, p.stdout
            except subprocess.TimeoutExpired as e:
                rc, text = 124, (e.stdout or "") if isinstance(e.stdout, str) else ""
            log.write_text(text)
            recs = read_records(tsv) if tsv.exists() else []
            bad = sum(1 for r in recs if r["status"] == "overlap")
            fh.write(f"{g}\t{rc}\t{int((dt.datetime.now() - t0).total_seconds())}\t{len(recs)}\t{bad}\n")
            fh.flush()
            print(f"{now()} [{i}/{len(gates)}] {g} rc={rc} records={len(recs)} overlaps={bad}", flush=True)
    print(f"{now()} demo sweep done: {out}", flush=True)
    return 0


# ---------------------------------------------------------------------------------------------- report
def cmd_report(args):
    paths = []
    for a in args.paths:
        p = Path(a)
        paths += sorted(p.rglob("*.tsv")) if p.is_dir() else [p]
    rows = []
    for p in paths:
        if p.name.endswith("-results.tsv"):
            continue
        for r in read_records(p):
            r["file"] = p.stem
            rows.append(r)
    checked = [r for r in rows if r["status"] in ("ok", "overlap")]
    print(f"records: {len(rows)} ({len(checked)} measured, {len(rows) - len(checked)} skipped/no SP)")
    print(f"\n{'margin':>7}  {'status':8} {'program':24} {'config':16} {'minSP':6} {'end':6}  function@pc")
    for r in sorted(checked, key=margin_key):
        print(f"{r['margin']:>7}  {r['status']:8} {r['program'][:24]:24} {r['config'][:16]:16} {r['min_sp']:6} "
              f"{r['static_end']:6}  {r['function']}@{r['pc']}")
    bad = [r for r in checked if r["status"] == "overlap"]
    print(f"\nviolations: {len(bad)}")
    for r in sorted(bad, key=margin_key):
        print(f"  {r['program']} [{r['config']}] overlap {-int(r['margin'])} B  ({r['rom']})")
    buckets = [(-10 ** 9, -1, "< 0 (overlap)"), (0, 63, "0-63"), (64, 255, "64-255"), (256, 1023, "256-1023"),
               (1024, 4095, "1024-4095"), (4096, 10 ** 9, ">= 4096")]
    print("\nmargin histogram (bytes):")
    for lo, hi, label in buckets:
        n = sum(1 for r in checked if lo <= margin_key(r) <= hi)
        print(f"  {label:>14}: {n}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("corpus"); c.set_defaults(fn=cmd_corpus)
    c.add_argument("--out"); c.add_argument("-j", "--jobs", type=int, default=2)
    c.add_argument("--frames", type=int, default=1000); c.add_argument("--only")
    c.add_argument("--timeout", type=int, default=600)
    c.add_argument("--no-poll", action="store_true", help="run the full frame count instead of stopping at the expected value")
    d = sub.add_parser("demos"); d.set_defaults(fn=cmd_demos)
    d.add_argument("--out"); d.add_argument("--only"); d.add_argument("--timeout", type=int, default=1800)
    r = sub.add_parser("report"); r.set_defaults(fn=cmd_report); r.add_argument("paths", nargs="+")
    a = ap.parse_args()
    sys.exit(a.fn(a))


if __name__ == "__main__":
    main()
