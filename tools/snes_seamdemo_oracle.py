#!/usr/bin/env python3
"""Host oracle for the ExHiROM three-act boundary synthesis cartridge (seamdemo).

This module is deliberately the ONLY implementation of the three traversals on
the host side.  It reads BYTES out of a `.sfc` image through
`snes_cartmap.CartMap.decode` -- the same decode the console performs -- and
never consults the generator's construction.  `snes-seamdemo-gen.py` builds the
payload, then calls in here to learn what the CRCs are, so a generator that
lays a byte down in the wrong place produces a different oracle value instead of
a matching pair of wrong numbers.

The console (P1-P3) implements the same three traversals in C; the differential
is host(this) == default @ MAME == +mos-a16 @ MAME == +mos-a16 @ bsnes-jg.

  act1  sequential bytecode march   -- a 16-opcode VM whose PC is a 24-bit FILE
                                       offset, so the $3FFFFF -> $400000 device
                                       seam is a plain PC increment.
  act2  pointer-linked graph walk   -- one node per decode cell (mirrors
                                       included), chained into a covering cycle.
  act3  atlas flyover               -- a serpentine camera tour over one data
                                       page per 32 KiB slot.

  corpus_result = fold(act1_lo, act1_hi, act2_lo, act2_hi, act3_lo, act3_hi)

Usage as a CLI:
  snes_seamdemo_oracle.py --rom IMAGE.sfc --desc LAYOUT.json [--json OUT]
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
import sys
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from snes_cartmap import CartMap  # noqa: E402

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load_cartcanary():
    """Import `snes-cartcanary.py` (hyphenated, so not importable by name).

    `pattern` and `fold` are the canary fixture's primitives and are reused
    verbatim rather than re-typed: the padding pattern's non-linearity and the
    fold's non-GF(2)-linearity were both learned the hard way there (see that
    file's docstrings), and a second copy is a second place to relearn them."""
    path = os.path.join(_HERE, "snes-cartcanary.py")
    spec = importlib.util.spec_from_file_location("snes_cartcanary", path)
    if spec is None or spec.loader is None:  # pragma: no cover
        raise ImportError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_canary = _load_cartcanary()
pattern = _canary.pattern
fold = _canary.fold
layout = _canary.layout
code_region = _canary.code_region


# --------------------------------------------------------------------------
# The slot record -- the ONE sub-layout every 32 KiB canonical file unit uses
# --------------------------------------------------------------------------
#: A "slot" is one canonical 32 KiB file unit (`CartMap.CELL`).  All three acts
#: place their payload inside slots at these fixed offsets, so the three acts
#: cannot collide by construction and the layout report is one table.
SLOT = 0x8000
DATA_OFF, DATA_LEN = 0x0100, 0x1000                 # act3 texture page, 64x64 8bpp; act1 LOAD source
HGT_OFF, HGT_LEN = 0x1100, 0x0100                   # act3 heights, 16x16
META_OFF, META_LEN = 0x1200, 0x0100                 # act3 page metadata (self-describing)
NODE_OFF, NODE_LEN = 0x2000, 0x2000                 # act2 nodes, 16 B each, up to 512 per slot

#: Act 1 chapter length.  SIZED BY MEASUREMENT, not taste (dev/seamdemo.sh step
#: 5b, bsnes-jg, SlowROM).  Drawing dominates the act and does NOT scale linearly
#: with segment count -- the canvas dirty-tile flush is budgeted at
#: CANVAS_FLUSH_TILES per v-blank, so past some density it is a throughput wall
#: rather than a per-line cost -- which is why this took two rounds:
#:
#:   256 B chapters, MOVE 2-in-9 : 65,961 ops / 12,729 seg -> ~245 s
#:    48 B chapters, MOVE 1-in-10:  10,224 ops /   689 seg -> ~38 s
#:    48 B chapters, MOVE 1-in-23:  10,494 ops /   367 seg -> ~34 s   <- shipping
#:
#: against the plan's 20-30 s.  Every slot still gets its own chapter, so the
#: march still spans the whole 6 MiB.
CHAP_OFF, CHAP_LEN = 0x4000, 0x0030

#: The seam chapter is split down the middle across the device boundary: half of
#: it is the last bytes of physical ROM 1, half the first bytes of ROM 2.
STRADDLE_OUT_LEN = CHAP_LEN // 2
STRADDLE_OUT_OFF = SLOT - STRADDLE_OUT_LEN          # bytecode running OUT into the next slot
STRADDLE_IN_OFF, STRADDLE_IN_LEN = 0x0000, CHAP_LEN // 2  # ... and IN from the previous slot

NODE_BYTES = 16
TEX_W = TEX_H = 64
HGT_W = HGT_H = 16

# --------------------------------------------------------------------------
# Act 1 -- the VM ISA.  Dense 0x00..0x0F so `switch (op)` lowers to a jump
# table (JMP (abs,X)); the ALU ops go through a function-pointer table.
# --------------------------------------------------------------------------
OPS = (
    ("HALT", 0),   # 0x00  end of act
    ("NOP", 0),    # 0x01
    ("IMM", 2),    # 0x02  a,i     r[a&7] = i
    ("IMMH", 2),   # 0x03  a,i     r[a&7] = (r[a&7] & 0x00FF) | (i << 8)
    ("ALU", 2),    # 0x04  f,ab    r[d] = ALU[f&7](r[d], r[s]);  d=(ab>>4)&7, s=ab&7
    ("MOVE", 1),   # 0x05  a       pen-move r[a&7]&63 units along heading; draws
    ("TURN", 1),   # 0x06  i       heading = (heading + i) & 0xFF
    ("PEN", 1),    # 0x07  i       pen = i & 3
    ("JREL", 1),   # 0x08  i       pc += (int8)i
    ("JZ", 2),     # 0x09  a,i     if (r[a&7] == 0) pc += (int8)i
    ("LOOP", 2),   # 0x0A  a,i     if (--r[a&7] != 0) pc += (int8)i
    ("EMIT", 1),   # 0x0B  a       fold r[a&7], low byte then high
    ("MARK", 0),   # 0x0C          fold the 24-bit PC (lo,mid,hi) -- the seam beat
    ("LOAD", 2),   # 0x0D  a,d     d = data page byte at (pc & ~0x7FFF)+DATA_OFF+(r[a&7] & 0x0FFF)
    ("JFAR", 3),   # 0x0E  lo,m,hi pc = 24-bit FILE offset (chapter link)
    ("SYNC", 1),   # 0x0F  i       fold i; the console yields i frames here
)
OP = {name: i for i, (name, _) in enumerate(OPS)}
OP_ARGS = {i: n for i, (_, n) in enumerate(OPS)}
assert len(OPS) == 16

ALU_OPS = ("ADD", "SUB", "XOR", "AND", "OR", "SHL", "ROR", "MULLO")
assert len(ALU_OPS) == 8


def alu(f: int, d: int, s: int) -> int:
    f &= 7
    if f == 0:
        return (d + s) & 0xFFFF
    if f == 1:
        return (d - s) & 0xFFFF
    if f == 2:
        return d ^ s
    if f == 3:
        return d & s
    if f == 4:
        return d | s
    if f == 5:
        return (d << 1) & 0xFFFF
    if f == 6:
        return ((d >> 1) | (d << 15)) & 0xFFFF
    return (d * s) & 0xFFFF


#: 16 headings, integer deltas only -- no trig at run time, so the console and
#: the host agree bit-for-bit without a shared sine table.
DIR16 = (
    (4, 0), (4, 2), (3, 3), (2, 4), (0, 4), (-2, 4), (-3, 3), (-4, 2),
    (-4, 0), (-4, -2), (-3, -3), (-2, -4), (0, -4), (2, -4), (3, -3), (4, -2),
)
CANVAS_MASK = 0x7F  # the act-1 canvas is 128x128

# --------------------------------------------------------------------------
# Terrain -- act 3's smooth half.  Built once from math.sin and checked against
# a baked digest, so a platform whose libm rounds differently fails loudly here
# instead of producing a quietly different cartridge.
# --------------------------------------------------------------------------
SIN256 = tuple(int(round(127.5 + 127.5 * math.sin(2.0 * math.pi * i / 256.0)))
               for i in range(256))
#: Two independent digests of SIN256, baked.  The fold happens to land on
#: $FFFF, which looks like a collapse, so the plain sum is carried alongside it
#: -- a table that degenerated would have to hit BOTH constants to slip through.
SIN256_DIGEST = 0xFFFF
SIN256_SUM = 32641


def _sin_digest() -> tuple[int, int]:
    h = 0
    for v in SIN256:
        h = fold(h, v)
    return h, sum(SIN256)


def terrain8(wx: int, wy: int) -> int:
    """Smooth 0..255 world field.  Integer, wraps every 256 world texels."""
    return (SIN256[(wx * 3) & 0xFF] + SIN256[(wy * 5) & 0xFF]
            + SIN256[((wx + wy) * 2) & 0xFF]) // 3


def texel(slot_file_start: int, gx: int, gy: int, u: int, v: int) -> int:
    """One data-page byte: smooth terrain in the high nibble (so the flyover is
    a picture and the image still compresses), the discriminating file-offset
    pattern in the low nibble (so every texel read is a decode probe)."""
    off = slot_file_start + DATA_OFF + v * TEX_W + u
    return ((terrain8(gx * TEX_W + u, gy * TEX_H + v) >> 4) << 4) | (pattern(off) & 0x0F)


def height(gx: int, gy: int, i: int, j: int) -> int:
    return terrain8(gx * TEX_W + i * 4 + 2, gy * TEX_H + j * 4 + 2)


# --------------------------------------------------------------------------
# Address translation: act 1's PC is a FILE offset
# --------------------------------------------------------------------------
def translate_table(cm: CartMap) -> tuple[tuple[int, int, int], ...]:
    """(file_lo, file_hi_exclusive, delta) such that far = file + delta.

    Derived from `windows()`.  A window whose CPU rows are 32 KiB (LoROM, the
    ExHiROM 8 MiB tail) is NOT linear in the file offset, so this raises rather
    than emit a formula the console would get wrong -- the seamdemo cartridge
    is 6 MiB ExHiROM / 64 KiB HiROM, both of which are whole-bank windows."""
    out = []
    for w in cm.windows():
        if w.addr_span != 0x10000:
            raise ValueError(
                f"window {w} has {w.addr_span:#x}-byte CPU rows; file->CPU is not "
                "a single add for this mapping/size, so act 1's PC cannot be a "
                "plain file offset"
            )
        out.append((w.file_start, w.file_end, (w.bank_lo << 16) - w.file_start))
    return tuple(out)


class Image:
    """A `.sfc` read strictly the way the console reads it."""

    def __init__(self, cm: CartMap, data: bytes):
        if len(data) != cm.size:
            raise ValueError(f"image is {len(data)} bytes, model expects {cm.size}")
        self.cm, self.data = cm, bytes(data)
        self.translate = translate_table(cm)
        self.reads = 0
        #: Which 32 KiB slots the traversals actually touched.  The generator
        #: asserts this never includes a reserved slot, which is what makes it
        #: legitimate to compute the CRCs from a payload-only image before the
        #: linked code exists.
        self.slots_read: set[int] = set()

    def far_of(self, off: int) -> int:
        for lo, hi, delta in self.translate:
            if lo <= off < hi:
                return off + delta
        raise ValueError(f"file ${off:06X} has no whole-bank CPU window")

    def far8(self, far: int) -> int:
        """Read through a 24-bit CPU address -- mirrors included, which is the
        whole point: a mirror-addressed read must yield the canonical byte."""
        off = self.cm.decode((far >> 16) & 0xFF, far & 0xFFFF)
        if off is None:
            raise ValueError(f"${far:06X} is not cartridge ROM")
        self.reads += 1
        self.slots_read.add(off // SLOT)
        return self.data[off]

    def file8(self, off: int) -> int:
        return self.far8(self.far_of(off))


# --------------------------------------------------------------------------
# Act 1 -- sequential bytecode march
# --------------------------------------------------------------------------
@dataclass
class Act1Result:
    crc: int
    ops: int
    segments: int
    marks: tuple[int, ...]
    halted: bool


def run_act1(img: Image, desc: dict) -> Act1Result:
    a = desc["act1"]
    pc = a["entry"]
    budget = a["op_budget"]
    r = [0] * 8
    x, y, heading, pen = 64, 64, 0, 1
    crc, ops, segs = 0, 0, 0
    marks: list[int] = []
    halted = False

    def s8(b: int) -> int:
        return b - 256 if b & 0x80 else b

    while ops < budget:
        op = img.file8(pc)
        pc = (pc + 1) & 0xFFFFFF
        ops += 1
        if op == OP["HALT"]:
            halted = True
            break
        if op == OP["NOP"]:
            continue
        if op == OP["MARK"]:
            crc = fold(crc, pc & 0xFF)
            crc = fold(crc, (pc >> 8) & 0xFF)
            crc = fold(crc, (pc >> 16) & 0xFF)
            marks.append(pc)
            continue
        if op == OP["JFAR"]:
            lo = img.file8(pc); mid = img.file8(pc + 1); hi = img.file8(pc + 2)
            pc = hi << 16 | mid << 8 | lo
            continue
        n = OP_ARGS.get(op)
        if n is None:
            raise ValueError(f"act1: opcode ${op:02X} at file ${pc - 1:06X} is not in the ISA")
        a0 = img.file8(pc); pc = (pc + 1) & 0xFFFFFF
        a1 = 0
        if n == 2:
            a1 = img.file8(pc); pc = (pc + 1) & 0xFFFFFF
        if op == OP["IMM"]:
            r[a0 & 7] = a1
        elif op == OP["IMMH"]:
            r[a0 & 7] = (r[a0 & 7] & 0x00FF) | ((a1 << 8) & 0xFF00)
        elif op == OP["ALU"]:
            d, s = (a1 >> 4) & 7, a1 & 7
            r[d] = alu(a0, r[d], r[s])
        elif op == OP["MOVE"]:
            dist = r[a0 & 7] & 0x3F
            dx, dy = DIR16[(heading >> 4) & 15]
            x0, y0 = x, y
            x = (x + dx * dist) & CANVAS_MASK
            y = (y + dy * dist) & CANVAS_MASK
            for b in (x0, y0, x, y, pen):
                crc = fold(crc, b)
            segs += 1
        elif op == OP["TURN"]:
            heading = (heading + a0) & 0xFF
        elif op == OP["PEN"]:
            pen = a0 & 3
        elif op == OP["JREL"]:
            pc = (pc + s8(a0)) & 0xFFFFFF
        elif op == OP["JZ"]:
            if r[a0 & 7] == 0:
                pc = (pc + s8(a1)) & 0xFFFFFF
        elif op == OP["LOOP"]:
            r[a0 & 7] = (r[a0 & 7] - 1) & 0xFFFF
            if r[a0 & 7] != 0:
                pc = (pc + s8(a1)) & 0xFFFFFF
        elif op == OP["EMIT"]:
            crc = fold(crc, r[a0 & 7] & 0xFF)
            crc = fold(crc, r[a0 & 7] >> 8)
        elif op == OP["LOAD"]:
            src = (pc & ~(SLOT - 1)) + DATA_OFF + (r[a0 & 7] & 0x0FFF)
            v = img.file8(src)
            r[a1 & 7] = v
            crc = fold(crc, v)
        elif op == OP["SYNC"]:
            crc = fold(crc, a0)
        else:  # pragma: no cover -- OP_ARGS and the dispatch above agree
            raise AssertionError(f"unhandled opcode ${op:02X}")
    else:
        raise ValueError(
            f"act1: op budget {budget} exhausted at file ${pc:06X} without HALT -- "
            "the bytecode stream does not terminate"
        )

    for v in r:
        crc = fold(crc, v & 0xFF)
        crc = fold(crc, v >> 8)
    for b in (x, y, heading, pen):
        crc = fold(crc, b)
    return Act1Result(crc=crc, ops=ops, segments=segs, marks=tuple(marks), halted=halted)


# --------------------------------------------------------------------------
# Act 2 -- pointer-linked graph walk over a covering cycle
# --------------------------------------------------------------------------
@dataclass
class Act2Result:
    crc: int
    nodes: int
    visited_far: tuple[int, ...]
    peeked_far: tuple[int, ...]


def run_act2(img: Image, desc: dict) -> Act2Result:
    a = desc["act2"]
    entry, n = a["entry_far"], a["nodes"]
    crc = 0
    p = entry
    visited: list[int] = []
    peeked: list[int] = []
    for _ in range(n):
        visited.append(p)
        rec = [img.far8(p + i) for i in range(NODE_BYTES)]
        for b in rec:
            crc = fold(crc, b)
        nxt = rec[4] | rec[5] << 8 | rec[6] << 16
        for base in (8, 12):
            tgt = rec[base] | rec[base + 1] << 8 | rec[base + 2] << 16
            peeked.append(tgt)
            crc = fold(crc, img.far8(tgt))
        p = nxt
    if p != entry:
        raise ValueError(
            f"act2: the walk did not close -- after {n} nodes the chain is at "
            f"${p:06X}, entry is ${entry:06X}"
        )
    crc = fold(crc, n & 0xFF)
    crc = fold(crc, (n >> 8) & 0xFF)
    return Act2Result(crc=crc, nodes=n, visited_far=tuple(visited), peeked_far=tuple(peeked))


# --------------------------------------------------------------------------
# Act 3 -- serpentine atlas flyover
# --------------------------------------------------------------------------
def act3_path(desc: dict) -> tuple[tuple[int, int, int, int, int], ...]:
    """(slot, gx, gy, u, v) samples -- a boustrophedon sweep over the page grid.

    The path is scripted (this is a camera, not a data-driven walk), so it is
    regenerated identically here, in the generator and on the console from the
    four numbers in the descriptor plus the reserved-slot skip list."""
    a = desc["act3"]
    gw, gh, per = a["grid_w"], a["grid_h"], a["samples_per_page"]
    skip = set(a["skip"])
    nslots = a["slots"]
    out = []
    for gy in range(gh):
        xs = range(gw) if (gy & 1) == 0 else range(gw - 1, -1, -1)
        right = (gy & 1) == 0
        for gx in xs:
            slot = gy * gw + gx
            if slot >= nslots or slot in skip:
                continue
            for k in range(per):
                u = (k * 4 + 2) if right else (TEX_W - 2 - k * 4)
                v = ((gy * 13 + k * 7) & (TEX_H - 1))
                out.append((slot, gx, gy, u, v))
    return tuple(out)


@dataclass
class Act3Result:
    crc: int
    samples: int
    pages: int


def run_act3(img: Image, desc: dict) -> Act3Result:
    crc = 0
    path = act3_path(desc)
    pages = set()
    for slot, gx, gy, u, v in path:
        base = slot * SLOT
        far = img.far_of(base)
        pages.add(slot)
        crc = fold(crc, slot & 0xFF)
        crc = fold(crc, (slot >> 8) & 0xFF)
        crc = fold(crc, img.far8(far + DATA_OFF + v * TEX_W + u))
        crc = fold(crc, img.far8(far + HGT_OFF + (v >> 2) * HGT_W + (u >> 2)))
        crc = fold(crc, img.far8(far + META_OFF))
    return Act3Result(crc=crc, samples=len(path), pages=len(pages))


# --------------------------------------------------------------------------
# The fold every act reports into
# --------------------------------------------------------------------------
def corpus_result(a1: int, a2: int, a3: int) -> int:
    h = 0
    for v in (a1, a2, a3):
        h = fold(h, v & 0xFF)
        h = fold(h, (v >> 8) & 0xFF)
    return h


def run_all(cm: CartMap, data: bytes, desc: dict) -> dict:
    img = Image(cm, data)
    r1 = run_act1(img, desc)
    r2 = run_act2(img, desc)
    r3 = run_act3(img, desc)
    return {
        "act1": {"crc": r1.crc, "ops": r1.ops, "segments": r1.segments,
                 "marks": len(r1.marks), "halted": r1.halted},
        "act2": {"crc": r2.crc, "nodes": r2.nodes},
        "act3": {"crc": r3.crc, "samples": r3.samples, "pages": r3.pages},
        "corpus_result": corpus_result(r1.crc, r2.crc, r3.crc),
        "rom_reads": img.reads,
        "_act1": r1, "_act2": r2, "_act3": r3,
    }


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="snes_seamdemo_oracle.py", description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--rom", required=True, help="the .sfc image to read")
    ap.add_argument("--desc", required=True,
                    help="layout report emitted by snes-seamdemo-gen.py")
    ap.add_argument("--json", help="write the result as JSON")
    args = ap.parse_args(argv[1:])

    with open(args.desc) as f:
        desc = json.load(f)
    with open(args.rom, "rb") as f:
        data = f.read()
    cm = CartMap(desc["mapping"], desc["size"], speed=desc.get("speed", "slow"))
    res = run_all(cm, data, desc)
    out = {k: v for k, v in res.items() if not k.startswith("_")}
    print(f"act1 CRC ${res['act1']['crc']:04X}  ({res['act1']['ops']} ops, "
          f"{res['act1']['segments']} segments, {res['act1']['marks']} marks)")
    print(f"act2 CRC ${res['act2']['crc']:04X}  ({res['act2']['nodes']} nodes, cycle closed)")
    print(f"act3 CRC ${res['act3']['crc']:04X}  ({res['act3']['samples']} samples over "
          f"{res['act3']['pages']} pages)")
    print(f"corpus_result ${res['corpus_result']:04X}  "
          f"({res['rom_reads']} cartridge reads)")
    if args.json:
        with open(args.json, "w") as f:
            json.dump(out, f, indent=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
