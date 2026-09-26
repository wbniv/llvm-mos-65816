#!/usr/bin/env python3
"""Retain matched-input X86 red/green checks for the selected 0028 source."""

import hashlib
import json
from pathlib import Path
import resource
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "0028"
BIN = OUT / "cross-build"
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
results = []
fc = ROOT / "build/0041-inlineasm-build/bin/FileCheck"
for case in ("x86-undef-high-byte-result", "x86-copy-contracts"):
    source = OUT / (case + ".mir")
    for label, binary in (("recorded-baseline", ROOT / "build/0041-inlineasm-build/llc-0041"),
                          ("private-baseline", BIN / "llc-baseline"),
                          ("candidate", BIN / "llc-0028")):
        for mode in ("none", "greedy,virtregrewriter"):
            command = [str(binary), "-mtriple=x86_64", "-enable-subreg-liveness", "-run-pass=" + mode,
                       "-verify-machineinstrs", str(source), "-o", "-"]
            proc = subprocess.run(command, capture_output=True, timeout=30)
            name = case + "-" + label + "-" + mode.replace(",", "-")
            (OUT / (name + ".stdout")).write_bytes(proc.stdout)
            (OUT / (name + ".stderr")).write_bytes(proc.stderr)
            expect_red = case == "x86-undef-high-byte-result" and mode != "none" and label != "candidate"
            passed = proc.returncode == (-6 if expect_red else 0)
            if expect_red:
                passed = passed and b"Using an undefined physical register" in proc.stderr and b"MOVZX32rr8 killed renamable $ah" in proc.stderr
            if not expect_red and mode != "none":
                check = subprocess.run([str(fc), str(source)], input=proc.stdout, capture_output=True)
                passed = passed and check.returncode == 0
                (OUT / (name + ".check.stderr")).write_bytes(check.stderr)
            results.append({"name": name, "command": command, "exit": proc.returncode, "expected_result": passed,
                            "input_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                            "binary_sha256": hashlib.file_digest(binary.open("rb"), "sha256").hexdigest()})
            print(name, proc.returncode, "PASS" if passed else "FAIL", flush=True)
(OUT / "x86-results.json").write_text(json.dumps(results, indent=2) + "\n")
assert all(result["expected_result"] for result in results)
