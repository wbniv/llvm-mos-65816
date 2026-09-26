#!/usr/bin/env python3
"""Check isolated diagnostic recovery and live aggregate output definitions."""

import json
from pathlib import Path
import resource
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
results = []
for level in (0, 2):
    for form in ("bad_output", "bad_input", "bad_tied", "bad_indirect", "bad_callbr", "bad_callbr_input", "bad_callbr_pair"):
        source = ROOT / "docs/defects/evidence/2026-09-25-selectiondag-inlineasm" / (form + ".ll")
        command = [str(ROOT / "build/selectiondag-inlineasm-fix/llc"), "-mtriple=aarch64", "-global-isel=0", f"-O{level}", "-verify-machineinstrs", str(source), "-o", "/dev/null"]
        proc = subprocess.run(command, capture_output=True, text=True, timeout=30)
        expected = "error: register 'NZCV' allocated for constraint '{cc}' does not match required type"
        (OUT / f"isolated-{form}-O{level}.log").write_text(proc.stdout + proc.stderr)
        results.append({"command": command, "exit": proc.returncode, "passed": proc.returncode == 1 and proc.stderr.strip() == expected})
    for abort in (0, 1):
        command = [str(ROOT / "build/inlineasm-bounds-fix/llc"), "-mtriple=aarch64", "-global-isel=1", f"-global-isel-abort={abort}", f"-O{level}", "-verify-machineinstrs", str(OUT / "gisel-aggregate-recovery.ll"), "-o", "/dev/null"]
        proc = subprocess.run(command, capture_output=True, text=True, timeout=30)
        expected = "error: not enough registers for inline asm constraint '{cc}'"
        (OUT / f"aggregate-O{level}-abort{abort}.log").write_text(proc.stdout + proc.stderr)
        results.append({"command": command, "exit": proc.returncode, "passed": proc.returncode == 1 and proc.stderr.strip().splitlines() == [expected, expected]})
(OUT / "recovery-results.json").write_text(json.dumps(results, indent=2) + "\n")
print(f"{sum(result['passed'] for result in results)}/{len(results)} recovery commands passed")
assert all(result["passed"] for result in results)
