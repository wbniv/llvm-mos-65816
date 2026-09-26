#!/usr/bin/env python3
"""Record additional compiler probes without modifying retained executables."""
import hashlib
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = HERE / "additional"
OUT.mkdir(exist_ok=False)
tools = {"baseline": ROOT / "build/0030-claude-review/llc-final",
         "candidate": ROOT / "build/0030-claude-review/llc-0038",
         "integrated": ROOT / "build/llvm-mos/bin/llc"}
env = dict(os.environ, PATH=str(ROOT / "build/llvm-mos/bin") + ":" + os.environ["PATH"])
records = []
def run(name, filename, cpu):
    src = HERE / filename
    stem = name + "-" + src.stem + "-" + cpu
    cmd = [str(tools[name]), "-mtriple=mos", "-mcpu=" + cpu, "-O2",
           "-verify-machineinstrs", str(src), "-o", str(OUT / (stem + ".s"))]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=30, env=env)
    log = OUT / (stem + ".log")
    log.write_text(p.stdout + p.stderr)
    record = {"command": cmd, "exit_code": p.returncode,
              "tool_sha256": hashlib.sha256(tools[name].read_bytes()).hexdigest(),
              "input_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
              "log": str(log.relative_to(ROOT)),
              "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()}
    records.append(record)
    print(stem, p.returncode)
for cpu in ("mos6502", "mosw65816", "mosspc700"):
    run("candidate", "additional-controls.ll", cpu)
for name in tools:
    run(name, "spc-existing-control.ll", "mosspc700")
run("integrated", "additional-controls.ll", "mosspc700")
(OUT / "receipt.json").write_text(json.dumps({
    "attribution": "OpenAI Codex CLI 0.157.1 (codex-tui), gpt-6-astra, xhigh",
    "runs": records}, indent=2) + "\n")
