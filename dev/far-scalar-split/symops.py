#!/usr/bin/env python3
"""symops.py -- list every instruction whose relocation targets a given symbol set.
Usage: llvm-objdump -dr X.o | symops.py SYM[,SYM...]      (-h/--help: this text)
Prints: FUNC OPCODE MNEMONIC RELOC-TYPE SYMBOL. Used to prove which addressing forms (16-bit
DBR-relative R_MOS_ADDR16 vs 24-bit R_MOS_ADDR24) the native s16 path uses for a scalar."""
import re, sys
if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
    print(__doc__); sys.exit(0)
syms = set(sys.argv[1].split(","))
fn = ins = None
for line in sys.stdin:
    m = re.match(r"^[0-9a-f]+ <([^>]+)>:", line)
    if m: fn = m.group(1); continue
    m = re.match(r"^\s+[0-9a-f]+:\s+((?:[0-9a-f]{2} )+)\s*(\S+)", line)
    if m: ins = (m.group(1).split()[0], m.group(2)); continue
    m = re.search(r"(R_MOS_\S+)\s+(\S+)", line)
    if m and ins:
        s = re.sub(r"\+0x[0-9a-f]+$", "", m.group(2))
        if s in syms: print(fn, ins[0], ins[1], m.group(1), m.group(2))
