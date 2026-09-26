#!/usr/bin/env python3
"""Identify exact diagnostic outcomes for isolated current-main 0043 builds."""

import hashlib
import json
from pathlib import Path
import resource
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build/post-ready-validation-mos/0043"
OUT = Path(__file__).resolve().parent / "0043"
OUT.mkdir(exist_ok=True)
INPUTS = BUILD / "candidate-tests/inline-asm-physreg-width.ll/tmp"
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
results = []
for label in ("baseline", "candidate"):
    binary = BUILD / (label + "-bin/llc")
    for source in sorted(INPUTS.glob("*.ll")):
        for level in (0, 2):
            command = [str(binary), "-mtriple=mos", "-mcpu=mos6502", f"-O{level}", "-verify-machineinstrs", str(source), "-o", "-"]
            proc = subprocess.run(command, capture_output=True, timeout=30)
            name = f"{label}-{source.stem}-O{level}"
            (OUT / (name + ".stdout")).write_bytes(proc.stdout)
            (OUT / (name + ".stderr")).write_bytes(proc.stderr)
            result = {"name": name, "command": command, "exit": proc.returncode,
                      "binary_sha256": hashlib.file_digest(binary.open("rb"), "sha256").hexdigest(),
                      "input_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                      "diagnostics": proc.stderr.decode(errors="replace").splitlines()[:3]}
            results.append(result)
            print(json.dumps({"name": name, "exit": result["exit"], "diagnostics": result["diagnostics"]}), flush=True)
(OUT / "results.json").write_text(json.dumps(results, indent=2) + "\n")
