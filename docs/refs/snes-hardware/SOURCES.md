# Sources — SNES hardware reference

The [hardware summary](snes-hardware-summary.md) is authored prose; the
[register map](snes-register-map.md) is generated from the annotated HAL headers
(`platforms/snes/snes_*.h`) by [`tools/gen-snes-regmap.py`](../../../tools/gen-snes-regmap.py).
The register names, addresses and bit-field facts in those headers were taken from the
public hardware references below. These are **cited, not vendored** — no copyrighted text
is redistributed here; consult them directly for cycle-level detail and corrections.

| Reference | Use |
|-----------|-----|
| nocash **fullsnes** — <https://problemkaputt.de/fullsnes.htm> | Primary: exhaustive register, DMA, PPU and timing detail |
| **SNESdev wiki** — <https://snes.nesdev.org/wiki/SNESdev_Wiki> | Register addresses, bit layouts, memory map |
| **anomie's** SNES docs (PPU / registers / timing) | Classic deep-dive cross-check |
| **Super Famicom Development Wiki** — <https://wiki.superfamicom.org/registers> | Register bit-field cross-check |
| R. Copetti, *SNES Architecture* — <https://www.copetti.org/writings/consoles/super-nintendo/> | Architecture overview |

For the 65816 CPU (instruction set + opcode oracle), see the separate
[../65816/SOURCES.md](../65816/SOURCES.md).
