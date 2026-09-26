#!/usr/bin/env python3
"""Compare runtime-index code size and verifier results on two MOS compilers."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def run(args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE)


def measure(compiler, source, output, flags, config, objdump):
    command = [str(compiler), "--config", str(config), "-fno-lto", "-Os",
               "-mllvm", "-verify-machineinstrs", *flags, "-c", str(source),
               "-o", str(output)]
    proc = run(command)
    output.with_suffix(".log").write_text(proc.stderr)
    result = {"command": command, "exit": proc.returncode}
    if proc.returncode:
        # Executable paths vary between the two runs. Preserve full diagnostics
        # on disk, and compare the semantic diagnostic separately from MIR dumps.
        errors = [line for line in proc.stderr.splitlines()
                  if "error:" in line or "Bad machine code" in line]
        result["errors"] = [re.sub(r"%\d+", "%vreg", line) for line in errors]
        return result
    sections = run([str(objdump), "-h", str(output)])
    sections.check_returncode()
    sizes = re.findall(r"^\s*\d+\s+(\.text\S*)\s+([0-9a-fA-F]+)",
                       sections.stdout, re.M)
    result["functions"] = {name: int(size, 16) for name, size in sizes}
    result["bytes"] = sum(result["functions"].values())
    disasm = run([str(objdump), "-dr", "--mcpu=mosw65816", str(output)])
    disasm.check_returncode()
    text = disasm.stdout.partition("Disassembly of section")[2]
    result["disassembly_sha256"] = hashlib.sha256(text.encode()).hexdigest()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("sources", type=Path, nargs="*")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    sources = args.sources or sorted({*root.glob("examples/65816/*.c"),
                                     *root.glob("examples/snes/*.c"),
                                     *root.glob("dev/dpy-shapes/*.c")})
    sources = [p.resolve() for p in sources]
    args.output.mkdir(parents=True, exist_ok=True)
    config = root / "build/install/bin/mos-snes.cfg"
    objdump = args.after.resolve().parent / "llvm-objdump"
    a16 = ["-Xclang", "-target-feature", "-Xclang", "+mos-a16"]
    xy16 = [*a16, "-Xclang", "-target-feature", "-Xclang", "+mos-xy16"]
    modes = {"default": [], "a16": a16, "xy16": xy16,
             "a16-nosched": [*a16, "-mllvm", "-enable-misched=false"],
             "xy16-nosched": [*xy16, "-mllvm", "-enable-misched=false"]}
    records = []
    failures = 0
    for mode, flags in modes.items():
        counts = {k: 0 for k in ("wins", "growth", "same", "identical",
                                "matching_failures", "new_failures")}
        total_before = total_after = 0
        for source in sources:
            name = source.relative_to(root).as_posix()
            directory = args.output / mode / name.replace("/", "_")
            directory.mkdir(parents=True, exist_ok=True)
            old = measure(args.before.resolve(), source, directory / "before.o",
                          flags, config, objdump)
            new = measure(args.after.resolve(), source, directory / "after.o",
                          flags, config, objdump)
            record = {"source": name, "mode": mode, "before": old, "after": new}
            records.append(record)
            if old["exit"] or new["exit"]:
                if old["exit"] and new["exit"] and old["errors"] == new["errors"]:
                    counts["matching_failures"] += 1
                elif new["exit"]:
                    counts["new_failures"] += 1
                    failures += 1
                    print("FAIL", mode, name, flush=True)
                else:
                    print("NOW COMPILES", mode, name, flush=True)
                continue
            delta = new["bytes"] - old["bytes"]
            identical = old["disassembly_sha256"] == new["disassembly_sha256"]
            counts["wins" if delta < 0 else "growth" if delta > 0 else "same"] += 1
            counts["identical"] += identical
            total_before += old["bytes"]
            total_after += new["bytes"]
            if delta or not identical:
                print(f"{mode} {name}: {old['bytes']} -> {new['bytes']} ({delta:+})"
                      f" identical={identical}", flush=True)
            if delta > 0 or (mode == "default" and not identical):
                failures += 1
        print(f"{mode}: {total_before} -> {total_after} "
              f"({total_after-total_before:+}); {counts}", flush=True)
        (args.output / "results.json").write_text(json.dumps(records, indent=2) + "\n")
    print(f"RESULT: {'FAIL' if failures else 'PASS'}; {failures} regressions")
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
