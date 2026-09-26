#!/usr/bin/env python3
"""Check preserved 0028 implementations and witnesses in isolated scratch."""

import hashlib
import json
import os
from pathlib import Path
import resource
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "0028"
OUT.mkdir(exist_ok=True)
os.chdir(ROOT)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
PATCH = ROOT / "docs/pr-preparations/2026-09-21/0028-upstream.patch"
REFS = ROOT / "build/post-ready-2026-09-26-isolated-src"
results = []

def run(name, command, expected=0, signature=None):
    result = subprocess.run(command, capture_output=True, timeout=120)
    (OUT / (name + ".stdout")).write_bytes(result.stdout)
    (OUT / (name + ".stderr")).write_bytes(result.stderr)
    passed = result.returncode == expected and (signature is None or signature.encode() in result.stderr)
    results.append({"name": name, "command": command, "exit": result.returncode, "expected_result": passed,
                    "stdout_sha256": hashlib.sha256(result.stdout).hexdigest(),
                    "stderr_sha256": hashlib.sha256(result.stderr).hexdigest()})
    print(name, result.returncode, "PASS" if passed else "FAIL", flush=True)
    return result

for label, ref in (("mos", "refs/remotes/preparation/mos-main"), ("llvm", "refs/remotes/preparation/llvm-main")):
    source = subprocess.check_output(["git", "-C", str(REFS), "show", ref + ":llvm/lib/CodeGen/VirtRegMap.cpp"])
    tree = OUT / (label + "-src")
    target = tree / "llvm/lib/CodeGen/VirtRegMap.cpp"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(source)
    run(label + "-patch-check", ["git", "apply", "--check", "--directory=" + str(tree.relative_to(ROOT)), str(PATCH)])
    run(label + "-patch-apply", ["git", "apply", "--directory=" + str(tree.relative_to(ROOT)), str(PATCH)])

source_roundtrip = (OUT / "mos-src/llvm/lib/CodeGen/VirtRegMap.cpp").read_bytes() == (ROOT / "build/0028-6502/VirtRegMap.patched.cpp").read_bytes()
assert source_roundtrip
assert (OUT / "mos-src/llvm/lib/CodeGen/VirtRegMap.cpp").read_bytes() == (OUT / "llvm-src/llvm/lib/CodeGen/VirtRegMap.cpp").read_bytes()
print("Current-base patch roundtrip equals preserved tested source", flush=True)

FC = ROOT / "build/0041-inlineasm-build/bin/FileCheck"
tools = (("unpatched", "build/0028-6502/llc-unpatched"),
         ("refactor", "build/0028-6502/llc-patched"),
         ("boolean", "build/0028-refactor/llc-bool"))
for label, binary in tools:
    for test in ("virtregrewriter-undef-lane-identity-copy.mir", "virtregrewriter-copy-liveness.mir"):
        source = OUT / "mos-src/llvm/test/CodeGen/MOS" / test
        bad = label == "unpatched" and "undef-lane" in test
        name = label + "-" + test.removesuffix(".mir")
        result = run(name, [str(ROOT / binary), "-mtriple=mos", "-mcpu=mos6502", "-run-pass=greedy,virtregrewriter", "-verify-machineinstrs", str(source), "-o", "-"], -6 if bad else 0, "Using an undefined physical register" if bad else None)
        if not bad and result.returncode == 0:
            run(name + "-filecheck", [str(FC), str(source), "--input-file=" + str(OUT / (name + ".stdout"))])

for name in ("bitboard-inline-register-pressure", "mos-coalescing-rc-undef"):
    record = json.loads((ROOT / "docs/defects" / (name + ".json")).read_text())
    for side, entry in (("baseline", record["baseline"]), ("candidate", record["resolution"]["candidate"])):
        binary = ROOT / entry["toolchain_location"]
        assert hashlib.file_digest(binary.open("rb"), "sha256").hexdigest() == entry["toolchain_sha256"]
        assert hashlib.sha256((ROOT / entry["input"]["path"]).read_bytes()).hexdigest() == entry["input"]["sha256"]
        run(name + "-" + side, shlex.split(entry["command"]), -6 if side == "baseline" else 0,
            entry.get("failure_signature"))

comparison = {}
for test in ("virtregrewriter-undef-lane-identity-copy", "virtregrewriter-copy-liveness"):
    comparison[test] = (OUT / ("refactor-" + test + ".stdout")).read_bytes() == (OUT / ("boolean-" + test + ".stdout")).read_bytes()
print("Boolean/refactor exact MIR equivalence:", comparison)
(OUT / "results.json").write_text(json.dumps({"runs": results, "roundtrip_matches_saved_source": source_roundtrip, "mir_equivalence": comparison}, indent=2) + "\n")
assert all(result["expected_result"] for result in results)
