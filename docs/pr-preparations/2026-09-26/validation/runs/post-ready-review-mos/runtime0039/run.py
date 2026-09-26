from pathlib import Path
import argparse
import hashlib
import json
import resource
import shlex
import struct
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--baseline", type=Path, required=True)
parser.add_argument("--candidate", type=Path, required=True)
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[3]
source = Path(__file__).with_name("modifier-width-runtime.s")
out = args.out.resolve()
out.mkdir(parents=True, exist_ok=False)
objcopy = root / "build/llvm-mos/bin/llvm-objcopy"
readobj = root / "build/llvm-mos/bin/llvm-readobj"
sim = root / "build/utils/sim/mos-sim"
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

def hashed(path):
    path = Path(path)
    return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

def run(name, command, expected=0):
    result = subprocess.run([str(x) for x in command], cwd=root,
                            capture_output=True, timeout=10)
    log_path = out / (name + ".log")
    log_path.write_text("$ " + shlex.join([str(x) for x in command]) + "\n" +
                        "exit=" + str(result.returncode) + "\nstdout:\n" +
                        result.stdout.decode() + "\nstderr:\n" + result.stderr.decode())
    assert result.returncode == expected, (name, result.returncode, log_path)
    return {"command": [str(x) for x in command], "exit_code": result.returncode,
            "stdout": result.stdout.decode(), "stderr": result.stderr.decode(),
            "log": hashed(log_path)}

manifest = {
    "purpose": "0039 stock-6502 explicit-address-width runtime differential",
    "cwd": str(root), "input": hashed(source), "runner": hashed(__file__),
    "scope": "Assembler MC object text only; no C frontend, linker, SDK library, or SNES platform.",
    "configuration": {"triple": "mos", "cpu": "mos6502", "emulator_cmos": False,
                      "reset_pc": 512, "timeout_seconds": 10},
    "packaging": "Each mos-sim block is little-endian address:u16,size:u16,data; code is at 0x0200 and the reset vector at 0xFFFC points to it.",
    "tools": {"objcopy": hashed(objcopy), "readobj": hashed(readobj), "sim": hashed(sim)},
    "runs": {}
}

for label, mc, status, character, opcode in (
        ("baseline", args.baseline.resolve(), 7, "W", bytes.fromhex("b5f0")),
        ("candidate", args.candidate.resolve(), 0, "P", bytes.fromhex("bdf000"))):
    obj = out / (label + ".o")
    raw = out / (label + ".bin")
    image = out / (label + ".simg")
    version = run(label + "-version", [mc, "--version"])
    assemble = run(label + "-assemble", [mc, "-triple=mos", "-mcpu=mos6502",
                                          "-filetype=obj", source, "-o", obj])
    relocations = run(label + "-relocations", [readobj, "--relocations", obj])
    assert "Relocations [\n]" in relocations["stdout"], relocations
    extract = run(label + "-extract", [objcopy, "--only-section=.text", "-O", "binary", obj, raw])
    code = raw.read_bytes()
    assert code[11:11 + len(opcode)] == opcode, code.hex()
    image.write_bytes(struct.pack("<HH", 0x0200, len(code)) + code +
                      struct.pack("<HHH", 0xFFFC, 2, 0x0200))
    execute = run(label + "-execute", [sim, "--trace", image], status)
    assert execute["stdout"] == character, execute
    manifest["runs"][label] = {
        "assembler": hashed(mc), "version": version, "assemble": assemble,
        "relocations": relocations, "extract": extract, "execute": execute,
        "object": hashed(obj), "code": hashed(raw), "image": hashed(image),
        "code_hex": code.hex(), "observed_byte": ord(character)
    }
manifest_path = out / "manifest.json"
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print("baseline: W / 0x57 / exit 7; candidate: P / 0x50 / exit 0")
print(json.dumps(hashed(manifest_path)))
