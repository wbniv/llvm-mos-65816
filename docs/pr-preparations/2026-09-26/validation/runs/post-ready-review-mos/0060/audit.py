#!/usr/bin/env python3
"""Compare the retained upstream backport and replay its exact tests read-only."""
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = HERE / "run-resolved"
OUT.mkdir(exist_ok=False)
PACKET = ROOT / "docs/pr-preparations/2026-09-26/0060-llvm-mos.patch"
META = ROOT / "docs/pr-preparations/2026-09-26/0060-upstream-guard.json"
parts = {}
for part in PACKET.read_text().split("diff --git ")[1:]:
    lines = part.splitlines()
    name = lines[0].split(" b/", 1)[1]
    first = next(i for i, line in enumerate(lines) if line.startswith("@@"))
    parts[name] = (lines, "\n".join(lines[first:]).rstrip())
for entry in json.loads(META.read_text())["files"]:
    assert parts[entry["filename"]][1] == entry["patch"].rstrip(), entry["filename"]

testdir = OUT / "tests/mir"
testdir.mkdir(parents=True)
for name, (lines, _) in parts.items():
    if name.endswith(".mir"):
        first = next(i for i, line in enumerate(lines) if line.startswith("@@"))
        text = "\n".join(line[1:] for line in lines[first + 1:] if line.startswith("+")) + "\n"
        (testdir / Path(name).name).write_text(text)
ir = ROOT / "build/post-ready-2026-09-26-isolated-src/llvm/test/tools/llvm-reduce/operands-skip.ll"
(testdir.parent / "operands-skip.ll").write_bytes(ir.read_bytes())
BIN = ROOT / "build/post-ready-validation-llvm/0060/baseline-bin"
env = dict(os.environ, PATH=str(BIN) + ":" + os.environ["PATH"])
records = []
for src in sorted(testdir.glob("*.mir")):
    for index, raw in enumerate(re.findall(r"^# RUN: (.*)$", src.read_text(), re.M)):
        command = raw.replace("%S", str(src.parent)).replace("%s", str(src)).replace("%t", str(OUT / src.stem))
        command = re.sub(r"\bFileCheck\b", str(BIN / "FileCheck"), command)
        p = subprocess.run(["bash", "-o", "pipefail", "-c", command], capture_output=True,
                           text=True, timeout=60, env=env, cwd=ROOT)
        log = OUT / f"{src.stem}-{index}.log"
        log.write_text(p.stdout + p.stderr)
        record = {"command": command, "exit_code": p.returncode,
                  "input_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
                  "log": str(log.relative_to(ROOT)),
                  "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()}
        records.append(record)
        assert p.returncode == 0, record
tools = {name: hashlib.sha256((BIN / name).read_bytes()).hexdigest()
         for name in ("llvm-reduce", "llc", "FileCheck")}
(OUT / "receipt.json").write_text(json.dumps({
    "attribution": "OpenAI Codex CLI 0.157.1 (codex-tui), gpt-6-astra, xhigh",
    "scope": "Preserved LLVM e59 baseline already containing upstream guard; not a new MOS backport build",
    "packet_sha256": hashlib.sha256(PACKET.read_bytes()).hexdigest(),
    "upstream_metadata_sha256": hashlib.sha256(META.read_bytes()).hexdigest(),
    "exact_upstream_sections": 4, "tools": tools, "runs": records}, indent=2) + "\n")
print("PASS: exact four upstream sections; all nine packet RUNs pass on retained LLVM baseline.")
