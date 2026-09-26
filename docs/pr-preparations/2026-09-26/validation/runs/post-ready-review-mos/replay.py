from pathlib import Path
import hashlib
import json
import resource
import subprocess

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
runs = []

def run(name, command, expected, signature=None):
    proc = subprocess.run(command, cwd=root, capture_output=True, text=True)
    log = proc.stdout + proc.stderr
    (out / (name + ".log")).write_text(log)
    assert (proc.returncode == 0) == expected, (name, proc.returncode, log[:500])
    if signature:
        assert signature in log, (name, log[:500])
    entry = {"name": name, "command": command, "returncode": proc.returncode,
             "sha256": hashlib.sha256(Path(command[0]).read_bytes()).hexdigest(),
             "log": str(out / (name + ".log"))}
    runs.append(entry)
    print(name, proc.returncode)

baseline = "build/defect-baselines/2026-09-25-mos-correctness/bin/llc"
candidate = "build/llvm-mos/bin/llc"
prefix = "docs/defects/evidence/2026-09-25-mos-correctness/baseline/"
for label, tool in (("baseline", baseline), ("candidate", candidate)):
    run("float-" + label,
        [tool, "-mtriple=mos", "-mcpu=mos6502", "-verify-machineinstrs",
         prefix + "float-vector.ll", "-o", "/dev/null"], label == "candidate",
        "unable to legalize instruction" if label == "baseline" else None)
    run("zp-" + label,
        [tool, "-mtriple=mos", "-run-pass=legalizer", "-verify-machineinstrs",
         prefix + "legalizer.mir", "-o", "/dev/null"], label == "candidate",
        "G_TRUNC %1:_(s8)" if label == "baseline" else None)
for label, tool in (("pristine-pin", "build/retired-worktrees/2026-09-25/llvm-mos-65816-pr0043-pinval/build/before-bin/llc"),
                    ("assertions-upstream", "build/0029-cross-target-build/bin/llc")):
    assembly = str(out / ("zp-" + label + ".s"))
    run("zp-" + label,
        [tool, "-mtriple=mos", "-mcpu=mos6502", "-verify-machineinstrs",
         str(out / "tests/zp-byte-index.ll"), "-o", assembly], True)
    run("zp-" + label + "-check",
        ["build/llvm-mos/bin/FileCheck", str(out / "tests/zp-byte-index.ll"),
         "--input-file=" + assembly], True)
pristine = "build/retired-worktrees/2026-09-25/llvm-mos-65816-pr0043-pinval/build/before-bin/"
for label, folder in (("pristine", pristine), ("candidate", "build/llvm-mos/bin/")):
    for name in ("modifier-width.s", "modifier-width-65816.s"):
        run(name + "-" + label,
            [folder + "llvm-mc", "-triple=mos", "-mcpu=mosw65816", "-show-encoding",
             str(out / "tests" / name)], True)
        run(name + "-" + label + "-check",
            ["build/llvm-mos/bin/FileCheck", str(out / "tests" / name),
             "--input-file=" + str(out / (name + "-" + label + ".log"))], label == "candidate")
    run("asciz-" + label,
        [folder + "llvm-mc", "-triple=mos", "-motorola-integers", "-show-encoding",
         str(out / "tests/addr-asciz.s")], label == "candidate",
        "Don't know how to emit this value" if label == "pristine" else None)
    run("long-symbol-" + label,
        [folder + "llc", "-mtriple=mos", "-mcpu=mosw65816",
         "-start-after=machine-opt-remark-emitter", "-verify-machineinstrs",
         str(out / "long-symbol.mir"), "-o", "-"], True)
    run("long-symbol-" + label + "-check",
        ["build/llvm-mos/bin/FileCheck", str(out / "long-symbol.mir"),
         "--input-file=" + str(out / ("long-symbol-" + label + ".log"))], label == "candidate")
(out / "runs.json").write_text(json.dumps(runs, indent=2) + "\n")
