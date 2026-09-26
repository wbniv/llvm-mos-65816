#!/usr/bin/env python3
"""Run the exact tests carried in the four inline-assembly patch bundles."""

import json
import os
from pathlib import Path
import resource
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
BIN = ROOT / "build/0041-inlineasm-build/bin"
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
os.chdir(ROOT)

CASES = (
    ("0056-llvm-gisel-inline-asm-register-bounds.patch", "inlineasm-bounds-fix"),
    ("0057-llvm-selectiondag-inline-asm-register-bounds.patch", "selectiondag-inlineasm-fix"),
    ("0058-aarch64-inline-asm-unknown-type.patch", "aarch64-asm-type-fix"),
    ("0059-llvm-selectiondag-vector-asm-parts.patch", "selectiondag-vector-parts-fix"),
)
results = []
for patch_name, build_name in CASES:
    patch = ROOT / "patches/llvm-mos" / patch_name
    section = patch.read_text().split("diff --git a/llvm/test/", 1)[1]
    source = OUT / (patch_name[:4] + "-regression.ll")
    content = "\n".join(line[1:] for line in section.splitlines() if line.startswith("+") and not line.startswith("+++")) + "\n"
    source.write_text(content)
    lines = [line.removeprefix("; RUN: ") for line in content.splitlines() if line.startswith("; RUN: ")]
    for index, line in enumerate(lines):
        command = line.replace("%s", shlex.quote(str(source))).replace("%t", shlex.quote(str(source) + ".tmp"))
        command = command.replace("llc ", shlex.quote(str(ROOT / "build" / build_name / "llc")) + " ")
        env = dict(os.environ, PATH=str(BIN) + ":" + os.environ["PATH"])
        proc = subprocess.run(["bash", "-o", "pipefail", "-c", command], capture_output=True, text=True, env=env, timeout=45)
        (OUT / f"{patch_name[:4]}-run-{index:02d}.log").write_text("$ " + command + "\n" + proc.stdout + proc.stderr)
        results.append({"patch": str(patch.relative_to(ROOT)), "index": index, "command": command, "exit": proc.returncode})
    print(patch_name, len(lines), "commands;", sum(result["exit"] != 0 for result in results if result["patch"].endswith(patch_name)), "failures", flush=True)
(OUT / "regression-results.json").write_text(json.dumps(results, indent=2) + "\n")
assert all(result["exit"] == 0 for result in results)
