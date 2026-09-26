#!/usr/bin/env python3
"""Replay retained diagnostic contracts without modifying source or binaries."""

import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
os.chdir(ROOT)

records = [
    "gisel-inline-asm-register-bounds",
    "selectiondag-inline-asm-register-bounds",
    "selectiondag-inline-asm-nonstandard-integer",
    "selectiondag-inline-asm-vector-parts",
]
results = []

for name in records:
    record = json.loads((ROOT / "docs/defects" / f"{name}.json").read_text())
    for side, run in (("baseline", record["baseline"]),
                      ("candidate", record["resolution"]["candidate"])):
        binary = ROOT / run["toolchain_location"]
        digest = hashlib.file_digest(binary.open("rb"), "sha256").hexdigest()
        assert digest == run["toolchain_sha256"], (binary, digest)
        source = ROOT / run["input"]["path"]
        assert hashlib.sha256(source.read_bytes()).hexdigest() == run["input"]["sha256"]
        config = run["configuration"]
        command = [str(binary), "-mtriple=aarch64", "-global-isel=" + str(int(config["global_isel"])),
                   "-O0", "-verify-machineinstrs"]
        if config["global_isel"]:
            command.append("-global-isel-abort=1")
        if "stop_after" in config:
            command.append("-stop-after=" + config["stop_after"])
        command += [str(source), "-o", "/dev/null"]
        proc = subprocess.run(command, capture_output=True, text=True, timeout=30)
        stem = name + "-" + side
        (OUT / (stem + ".stdout")).write_text(proc.stdout)
        (OUT / (stem + ".stderr")).write_text(proc.stderr)
        passed = (proc.returncode == -6 and run["failure_signature"] in proc.stderr) if side == "baseline" else (proc.returncode == 1 and len(proc.stderr.strip().splitlines()) == 1 and proc.stderr.startswith("error:"))
        result = {"name": stem, "command": command, "binary_sha256": digest,
                  "input_sha256": run["input"]["sha256"], "exit": proc.returncode,
                  "expected_result": passed, "diagnostic": proc.stderr.splitlines()[0]}
        results.append(result)
        print(json.dumps(result), flush=True)

(OUT / "replay-results.json").write_text(json.dumps(results, indent=2) + "\n")
assert all(result["expected_result"] for result in results)
