#!/usr/bin/env python3
"""Relink a private 0028 comparison with one replaced CodeGen object."""

import hashlib
import json
from pathlib import Path
import shlex
import shutil
import subprocess

ROOT = Path("/work")
OUT = ROOT / "build/post-ready-review-inline/0028/cross-build"
BUILD = ROOT / "build/newton-postra-build"
SRC = ROOT / "build/register-exhaustion-src/llvm/lib/CodeGen/VirtRegMap.cpp"
CANDIDATE = ROOT / "build/post-ready-review-inline/0028/llvm-src/llvm/lib/CodeGen/VirtRegMap.cpp"
OUT.mkdir(exist_ok=True)
assert "CopyHasUndefLanes" not in SRC.read_text()
commands = json.loads((BUILD / "compile_commands.json").read_text())
entry = next(item for item in commands if item["file"].endswith("/VirtRegMap.cpp"))
argv = shlex.split(entry["command"])
argv[argv.index("-o") + 1] = str(OUT / "VirtRegMap.cpp.o")
argv[-1] = str(CANDIDATE)

with (OUT / "build.log").open("w") as log:
    def run(command, cwd):
        log.write("$ " + shlex.join(command) + "\n")
        log.flush()
        subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, check=True)

    run(argv, entry["directory"])
    archive = OUT / "libLLVMCodeGen.a"
    shutil.copy2(BUILD / "lib/libLLVMCodeGen.a", archive)
    run(["/usr/bin/ar", "r", str(archive), str(OUT / "VirtRegMap.cpp.o")], OUT)
    line = subprocess.check_output(["ninja", "-C", str(BUILD), "-t", "commands", "bin/llc"], text=True).splitlines()[-1]
    link = shlex.split(line)
    assert link[:2] == [":", "&&"] and link[-2:] == ["&&", ":"]
    link = link[2:-2]
    for name, patched in (("llc-baseline", False), ("llc-0028", True)):
        command = list(link)
        command[command.index("-o") + 1] = str(OUT / name)
        command = [str(archive) if patched and item == "lib/libLLVMCodeGen.a" else item for item in command]
        command = [("-Wl,--dependency-file=" + str(OUT / (name + ".d"))) if item.startswith("-Wl,--dependency-file=") else
                   ("--dependency-file=" + str(OUT / (name + ".d"))) if item.startswith("--dependency-file=") else item for item in command]
        run(command, BUILD)

def digest(path):
    return hashlib.file_digest(path.open("rb"), "sha256").hexdigest()

identity = {"baseline_source_sha256": digest(SRC), "candidate_source_sha256": digest(CANDIDATE),
            "baseline_archive_sha256": digest(BUILD / "lib/libLLVMCodeGen.a"), "candidate_archive_sha256": digest(archive),
            "baseline_binary_sha256": digest(OUT / "llc-baseline"), "candidate_binary_sha256": digest(OUT / "llc-0028"),
            "only_changed_link_input": "libLLVMCodeGen.a:VirtRegMap.cpp.o", "assertions": True}
(OUT / "identity.json").write_text(json.dumps(identity, indent=2) + "\n")
print(json.dumps(identity), flush=True)
