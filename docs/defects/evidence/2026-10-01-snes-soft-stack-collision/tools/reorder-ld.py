#!/usr/bin/env python3
"""Write a copy of the SNES link.ld that moves dither's gate data away from the soft stack.

usage: reorder-ld.py INSTALLED_LINK_LD OUTDIR

The copy differs from the installed script only in the order of low-WRAM data: .noinit (the
static stack) first, then dither_gate_crc.out, corpus_result and main.title, then the rest of
.bss with main.a (the App struct, whose tail is App.out, unused until the first dither_frame)
last. __stack stays $2000, the region sizes stay the same, and no code changes: only data
addresses move. Pass OUTDIR to the driver as -Wl,-L,OUTDIR; lld then finds this link.ld
first and resolves its INCLUDEs from the SDK directories as usual.

This is a diagnostic experiment, not a fix: it only moves which object the -O3 soft-stack
frame overlaps, from live gate data to App.out.
"""
import pathlib
import sys

if len(sys.argv) != 3 or sys.argv[1] in ('-h', '--help'):
    print(__doc__)
    sys.exit(0 if len(sys.argv) > 1 and sys.argv[1] in ('-h', '--help') else 2)

src = pathlib.Path(sys.argv[1]).read_text()
old = '  INCLUDE bss.ld\n  INCLUDE noinit.ld'
new = '''  .noinit (NOLOAD) : { *(.noinit .noinit.* NULL INIT ZPSAVE) } >c_writeable
  .bss (NOLOAD) : { __bss_start = .; *(.bss.dither_gate_crc.out) *(.bss.corpus_result) *(.bss.main.title) *(EXCLUDE_FILE(*.nothing) .bss.[!m]* ) *(.bss .bss.* BSS COMMON) __bss_end = .; } >c_writeable
  __bss_size = SIZEOF(.bss);
  __heap_start = ALIGN(., 2);'''
if src.count(old) != 1:
    sys.exit('reorder-ld.py: expected exactly one "INCLUDE bss.ld / INCLUDE noinit.ld" pair')
out = pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
(out / 'link.ld').write_text(src.replace(old, new))
print(out / 'link.ld')
