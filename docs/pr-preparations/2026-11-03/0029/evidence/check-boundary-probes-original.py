"""Check semantic register relationships without depending on vreg numbering."""

import json
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
functions = {}
for document in text.split("---\n"):
    name = re.search(r"^name:\s+(\w+)", document, re.M)
    if name:
        functions[name[1]] = document.split("body:", 1)[1]

def lines(name, opcode):
    return [line for line in functions[name].splitlines() if opcode in line]

def regs(line):
    return re.findall(r"%(\d+)(?![\d])", line)

asm = lines("distinct_sources", "INLINEASM")
first, second = regs(asm[0]), regs(asm[1])
assert first[0] == first[1] and first[0] != first[2]
assert second[0] not in first and not ({"0", "1"} & set(first + second))
assert "IMPLICIT_DEF" not in functions["distinct_sources"]

inc = lines("mixed_tied_untied", "IncMB")[0]
tied = re.search(r"killed %(\d+)\(tied-def 0\)", inc)[1]
implicit = re.search(r"implicit undef %(\d+)", inc)[1]
load = regs(lines("mixed_tied_untied", "LDAbs")[0])[0]
defs = lines("mixed_tied_untied", "IMPLICIT_DEF")
assert len(defs) == 2 and regs(defs[1])[0] == tied
assert implicit != load and implicit != tied
assert regs(lines("mixed_tied_untied", "STAbs")[0])[0] == load
assert ".subhi" not in inc

phi = lines("phi_edges", " = PHI ")[0]
inputs = re.findall(r"undef %(\d+)", phi)
assert len(inputs) == 2 and inputs[0] == inputs[1]
assert inputs[0] != regs(lines("phi_edges", "LDAbs")[0])[0]
assert len(lines("phi_edges", "PCOPY")) == 1

load = regs(lines("debug_live", "LDAbs")[0])[0]
debug = lines("debug_live", "DBG_VALUE")
assert len(debug) == 2 and all(regs(line) == [load] for line in debug)
assert regs(lines("debug_live", "INLINEASM")[0])[0] != load
assert f"STAbs killed %{load}," in lines("debug_live", "STAbs")[0]
print(json.dumps({"result": "PASS", "functions": sorted(functions)}, indent=2))
