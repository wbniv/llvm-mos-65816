#!/usr/bin/env python3
"""Replay the existing 0003 regression to qualify an SPC700 observation."""
import hashlib
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = HERE / "spc-reconciliation"
OUT.mkdir(exist_ok=False)
src = ROOT / "vendor/llvm-mos/llvm/test/CodeGen/MOS/late-opt-spc700.mir"
records = []
for name, relative in (
    ("historical-baseline", "build/0030-claude-review/llc-final"),
    ("historical-candidate", "build/0030-claude-review/llc-0038"),
    ("integrated", "build/llvm-mos/bin/llc"),
):
    tool = ROOT / relative
    cmd = [str(tool), "-mtriple=mos", "-mcpu=mosspc700", "-run-pass=mos-late-opt",
           "-verify-machineinstrs", str(src), "-o", str(OUT / (name + ".mir"))]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=30,
                       env=dict(os.environ, PATH=str(ROOT / "build/llvm-mos/bin") + ":" + os.environ["PATH"]))
    log = OUT / (name + ".log")
    log.write_text(p.stdout + p.stderr)
    records.append({"command": cmd, "exit_code": p.returncode,
                    "tool_sha256": hashlib.sha256(tool.read_bytes()).hexdigest(),
                    "input_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
                    "log": str(log.relative_to(ROOT)),
                    "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()})
    print(name, p.returncode)
(OUT / "receipt.json").write_text(json.dumps({
    "attribution": "OpenAI Codex CLI 0.157.1 (codex-tui), gpt-6-astra, xhigh",
    "runs": records}, indent=2) + "\n")
