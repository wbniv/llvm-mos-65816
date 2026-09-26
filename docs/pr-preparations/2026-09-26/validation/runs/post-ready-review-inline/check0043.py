#!/usr/bin/env python3
"""Run the current diagnostic test against both isolated 0043 snapshots."""

import difflib
import hashlib
import json
import os
from pathlib import Path
import resource
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build/post-ready-validation-mos/0043"
OUT = Path(__file__).resolve().parent / "0043"
SOURCE = OUT / "inline-asm-physreg-width.ll"
ORIGINAL = BUILD / "candidate-tests/inline-asm-physreg-width.ll/input.txt"
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
commands = [line.removeprefix("; RUN: ") for line in SOURCE.read_text().splitlines() if line.startswith("; RUN: ")]
results = []
for label in ("baseline", "candidate"):
    environment = dict(os.environ, PATH=str(BUILD / (label + "-bin")) + ":" + os.environ["PATH"])
    temporary = OUT / (label + "-adapted-splits")
    for index, template in enumerate(commands):
        command = template.replace("%s", shlex.quote(str(SOURCE))).replace("%t", shlex.quote(str(temporary)))
        proc = subprocess.run(["bash", "-o", "pipefail", "-c", command], env=environment, capture_output=True, timeout=30)
        name = f"{label}-adapted-{index:02d}"
        (OUT / (name + ".log")).write_bytes(proc.stdout + proc.stderr)
        passed = proc.returncode == 0
        expected = label == "candidate" or index < 2
        result = {"name": name, "command": command, "exit": proc.returncode, "expected_pass": expected, "as_expected": passed == expected}
        results.append(result)
        print(json.dumps(result), flush=True)
receipt = {"test_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(), "results": results}
(OUT / "adapted-results.json").write_text(json.dumps(receipt, indent=2) + "\n")
diff = difflib.unified_diff(ORIGINAL.read_text().splitlines(keepends=True), SOURCE.read_text().splitlines(keepends=True), fromfile="a/llvm/test/CodeGen/MOS/inline-asm-physreg-width.ll", tofile="b/llvm/test/CodeGen/MOS/inline-asm-physreg-width.ll")
(OUT / "diagnostic-test-adaptation.patch").write_text("".join(diff))
assert all(result["as_expected"] for result in results)
