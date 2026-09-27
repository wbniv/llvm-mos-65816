#!/usr/bin/env python3
"""Compare null emission and ordinary outputs for an isolated MOS extraction."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arm", choices=["baseline", "candidate"], required=True)
    parser.add_argument("--tools", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    evidence = root / "docs/defects/evidence/2026-09-27-null-output-upstream"
    out = evidence / args.arm
    out.mkdir()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    environment = os.environ.copy()
    environment["PATH"] = str(args.tools) + os.pathsep + environment["PATH"]
    runs = []

    def run(name, command, source, expected_failure=False, output=None):
        log = out / (name + ".log")
        with log.open("wb") as stream:
            result = subprocess.run(command, cwd=root, env=environment,
                                    stdout=stream, stderr=subprocess.STDOUT,
                                    timeout=120)
        record = {"name": name, "command": list(map(str, command)),
                  "working_directory": str(root), "exit_code": result.returncode,
                  "input": str(source.relative_to(root)), "input_sha256": digest(source),
                  "log": str(log.relative_to(root)), "log_sha256": digest(log),
                  "expected_failure": expected_failure}
        if output is not None and output.exists():
            record.update(output=str(output.relative_to(root)),
                          output_sha256=digest(output), output_bytes=output.stat().st_size)
        runs.append(record)
        (out / "runs.json").write_text(json.dumps(runs, indent=2) + "\n")
        assert (result.returncode < 0) if expected_failure else (result.returncode == 0), record
        return record

    cpus = ["mos6502", "mos65c02", "mosw65816"]
    inputs = {
        "original": root / "docs/defects/evidence/2026-09-27-mos-null-output/arith.Os.ll",
        "minimal": evidence / "filetype-null.ll",
        "sections": evidence / "sections.ll",
    }
    for label, source in inputs.items():
        for cpu in cpus:
            prefix = f"{label}-{cpu}"
            for diagnostic in [False, True]:
                name = prefix + ("-diagnostic" if diagnostic else "-null")
                output = out / (name + ".out")
                command = [args.tools / "llc", "-mtriple=mos", "-mcpu=" + cpu,
                           "-verify-machineinstrs", "-filetype=null", source, "-o", output]
                if diagnostic:
                    command.append("-debug-pass=Structure")
                run(name, command, source, args.arm == "baseline", output)
                if args.arm == "candidate":
                    assert not output.exists() or output.stat().st_size == 0
            for kind in ["obj", "asm"]:
                name = prefix + "-" + kind
                output = out / (name + ".out")
                run(name, [args.tools / "llc", "-mtriple=mos", "-mcpu=" + cpu,
                           "-verify-machineinstrs", "-filetype=" + kind, source,
                           "-o", output], source, output=output)

    source = evidence / "zeropage.s"
    for cpu in cpus:
        for kind in ["null", "obj", "asm"]:
            name = "mc-" + cpu + "-" + kind
            output = out / (name + ".out")
            run(name, [args.tools / "llvm-mc", "-triple=mos", "-mcpu=" + cpu,
                       "-filetype=" + kind, source, "-o", output], source,
                args.arm == "baseline" and kind == "null", output)
            if args.arm == "candidate" and kind == "null":
                assert not output.exists() or output.stat().st_size == 0

    receipt = {"arm": args.arm, "tools": {tool: digest(args.tools / tool)
                                         for tool in ["llc", "llvm-mc"]}, "runs": runs}
    if args.arm == "candidate":
        baseline = json.loads((evidence / "baseline/runs.json").read_text())
        ordinary = {r["name"]: r["output_sha256"] for r in baseline
                    if not r["expected_failure"]}
        comparisons = [{"name": r["name"], "identical": r["output_sha256"] == ordinary[r["name"]]}
                       for r in runs if r["name"] in ordinary]
        assert all(r["identical"] for r in comparisons)
        receipt["ordinary_output_comparisons"] = comparisons
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"{args.arm}: {len(runs)} commands satisfy their expected results")


if __name__ == "__main__":
    main()
