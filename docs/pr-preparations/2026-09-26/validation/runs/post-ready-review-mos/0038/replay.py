#!/usr/bin/env python3
"""Retain isolated outputs from read-only return/frame-address tool replays."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRATCH = Path(__file__).resolve().parent
TESTS = SCRATCH / "source/llvm/test/CodeGen/MOS"
OUT = SCRATCH / "replay"
OUT.mkdir(exist_ok=False)
TOOLS = {
    "historical-baseline": ROOT / "build/0030-claude-review/llc-final",
    "historical-candidate": ROOT / "build/0030-claude-review/llc-0038",
    "current-main-baseline": ROOT / "build/post-ready-validation-mos/0039/baseline-bin/llc",
}
FC = ROOT / "build/llvm-mos/bin/FileCheck"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

records = []
cases = [
    ("return-frame-address.ll", "mos6502", "-O0", "CHECK,M6502"),
    ("return-frame-address.ll", "mos6502", "-O2", "CHECK,M6502"),
    ("return-frame-address.ll", "mosw65816", "-O2", "CHECK,W65816"),
    ("return-address-spc700.ll", "mosspc700", "-O2", "CHECK"),
]
for name, tool in TOOLS.items():
    version = subprocess.run([str(tool), "--version"], capture_output=True, text=True, check=True)
    (OUT / f"{name}.version.txt").write_text(version.stdout)
    for index, (filename, cpu, level, prefixes) in enumerate(cases):
        src = TESTS / filename
        asm = OUT / f"{name}-{index}.s"
        cmd = [str(tool), "-mtriple=mos", f"-mcpu={cpu}", level,
               "-verify-machineinstrs", str(src), "-o", str(asm)]
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        log = OUT / f"{name}-{index}.log"
        log.write_text(p.stdout + p.stderr)
        record = {"tool": name, "tool_sha256": sha(tool), "command": cmd,
                  "input": str(src.relative_to(ROOT)), "input_sha256": sha(src),
                  "exit_code": p.returncode, "log": str(log.relative_to(ROOT)),
                  "log_sha256": sha(log)}
        if name == "historical-candidate":
            assert p.returncode == 0, record
            check = [str(FC), str(src), f"--check-prefixes={prefixes}", f"--input-file={asm}"]
            q = subprocess.run(check, capture_output=True, text=True, timeout=30)
            check_log = OUT / f"{name}-{index}.filecheck.log"
            check_log.write_text(q.stdout + q.stderr)
            record.update(check_command=check, check_exit=q.returncode,
                          assembly_sha256=sha(asm), check_log_sha256=sha(check_log))
            assert q.returncode == 0, record
        else:
            assert p.returncode != 0 and "unable to legalize instruction" in p.stderr, record
        records.append(record)

src = TESTS / "return-address-depth.mir"
dst = OUT / "depth.mir"
cmd = [str(TOOLS["historical-candidate"]), "-mtriple=mos", "-mcpu=mos6502",
       "-run-pass=mos-lower-return-address", "-verify-machineinstrs", str(src), "-o", str(dst)]
p = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
log = OUT / "depth.log"
log.write_text(p.stdout + p.stderr)
assert p.returncode == 0, p.stderr
check = [str(FC), str(src), f"--input-file={dst}"]
q = subprocess.run(check, capture_output=True, text=True, timeout=30)
check_log = OUT / "depth.filecheck.log"
check_log.write_text(q.stdout + q.stderr)
assert q.returncode == 0, q.stderr
records.append({"tool": "historical-candidate", "command": cmd,
                "input": str(src.relative_to(ROOT)), "input_sha256": sha(src),
                "exit_code": p.returncode, "output_sha256": sha(dst),
                "log_sha256": sha(log), "check_command": check, "check_exit": q.returncode,
                "check_log_sha256": sha(check_log)})
(OUT / "receipt.json").write_text(json.dumps({
    "attribution": "OpenAI Codex CLI 0.157.1 (codex-tui), gpt-6-astra, xhigh",
    "scope": "Read-only retained executables; no new build or runtime execution",
    "filecheck_sha256": sha(FC), "runs": records}, indent=2) + "\n")
print("PASS: four original RUNs fail for intrinsic legalization on both baselines;")
print("all four pass on the historical candidate, as does the added depth MIR.")
