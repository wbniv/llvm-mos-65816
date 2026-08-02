#!/usr/bin/env python3
"""Generate the three-act boundary synthesis cartridge (seamdemo) payload.

Plan: docs/plans/2026-08-01-exhirom-three-act-synthesis-cart.md (P0).

Everything here derives from `tools/snes_cartmap.py` -- the slot grid from
`windows()`, the coverage denominator from `decode_cells()`, the reserved code
range from the canary tool's model-derived `layout()`.  No address is written by
hand.  The three acts share ONE sub-layout per 32 KiB slot (see
`snes_seamdemo_oracle.py`), so they cannot collide by construction.

  act1  a bytecode stream: one ~256-byte chapter per slot, JFAR-chained in
        ascending FILE order so the VM's 24-bit PC marches the whole image.  At
        the 4 MiB device seam the chapter STRADDLES: a two-byte SYNC has its
        opcode at file $3FFFFF ($FF:FFFF) and its operand at file $400000
        ($40:0000), so one instruction spans the non-monotonic device boundary.
  act2  one 16-byte node per DECODE CELL -- mirrors included -- chained into a
        single covering cycle, plus two adversarial "peek" edges per node biased
        towards the other physical device and towards mirror addresses.  Every
        decode cell therefore has in-degree > 0 by construction, and the gate
        re-derives that from the model rather than trusting the construction.
  act3  one 64x64 data page + 16x16 heightmap + self-describing metadata per
        slot, swept by a scripted boustrophedon camera path.

The payload is SPARSE: only bytes some traversal actually reads are non-zero
(the canary tool's lesson -- these ROMs are published to an in-browser player,
and 6 MiB of incompressible hash is a 6 MiB download).

Sub-commands:
  emit-header  write the C header the ROM includes (tables + expected CRCs).
  report       write the machine-readable layout report (also the oracle's
               descriptor input).
  fill         post-link: write the payload into a linked .sfc and verify it
               back through the oracle.
  selfcheck    build the 64 KiB miniature, reproduce its folds with an
               independent hand-written recomputation, and assert the full
               6 MiB image's decode-cell coverage.

Usage:
  snes-seamdemo-gen.py emit-header --mapping exhirom --size 6M --out FILE
  snes-seamdemo-gen.py report      --mapping exhirom --size 6M --out FILE
  snes-seamdemo-gen.py fill        --mapping exhirom --size 6M --rom FILE [--report FILE]
  snes-seamdemo-gen.py selfcheck   [--verbose]
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
from dataclasses import dataclass, field

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from snes_cartmap import CartMap, DecodeCell, parse_size  # noqa: E402
import snes_seamdemo_oracle as ora  # noqa: E402
from snes_seamdemo_oracle import (  # noqa: E402
    ALU_OPS, CHAP_LEN, CHAP_OFF, DATA_LEN, DATA_OFF, HGT_H, HGT_LEN, HGT_OFF,
    HGT_W, META_LEN, META_OFF, NODE_BYTES, NODE_LEN, NODE_OFF, OP, OPS, SLOT,
    STRADDLE_IN_LEN, STRADDLE_IN_OFF, STRADDLE_OUT_LEN, STRADDLE_OUT_OFF,
    TEX_H, TEX_W, code_region, fold, height, pattern, texel,
)

#: Fixed seed.  The cartridge must be byte-identical on every run and every
#: machine -- there is no wall-clock or environment input anywhere in here.
SEED = 0x5EA3DE30

#: The 64 KiB miniature used by `selfcheck`.  It cannot be ExHiROM: ExHiROM's
#: internal header lives at file $40FFB0, so the mapping is undefined below
#: 4 MiB (`CartMap` rejects it).  HiROM at its 64 KiB minimum exercises the same
#: three traversals and the same alias arithmetic -- 380 decode cells over 2
#: file units -- which is what a fold self-check needs.
MINI = ("hirom", 0x10000)


# ==========================================================================
# Slots: the canonical 32 KiB file units, and which ones are off limits
# ==========================================================================
@dataclass
class SlotPlan:
    n: int                       # total slots = size / 0x8000
    reserved: tuple[int, ...]    # linked code + the far-section arena
    code_lo: int
    code_hi: int
    far_slots: tuple[int, ...]

    @property
    def available(self) -> tuple[int, ...]:
        res = set(self.reserved)
        return tuple(i for i in range(self.n) if i not in res)


def plan_slots(cm: CartMap, far_slots: int) -> SlotPlan:
    """Which slots the payload may use.

    `code_region` is the canary tool's model-derived linked-code range, reused
    verbatim so the two fixture generators cannot disagree about where the ROM
    itself lives.  `far_slots` additionally reserves whole slots immediately
    after it for `.far_text`/`.far_rodata`, which the ExHiROM link script places
    at the start of `rom_b`; `fill` fails loudly if the linker overruns them."""
    lo, hi = code_region(cm)
    if lo % SLOT or hi % SLOT:
        raise AssertionError(
            f"code range ${lo:06X}-${hi:06X} is not slot-aligned; the slot grid "
            "assumption is wrong for this mapping"
        )
    code = tuple(range(lo // SLOT, hi // SLOT))
    nslots = cm.size // SLOT
    far = tuple(i for i in range(hi // SLOT, hi // SLOT + far_slots) if i < nslots)
    plan = SlotPlan(n=nslots, reserved=tuple(sorted(set(code) | set(far))),
                    code_lo=lo, code_hi=hi, far_slots=far)
    if not plan.available:
        raise SystemExit("no slots left for payload after reservations")
    return plan


# ==========================================================================
# Act 2: one node per decode cell
# ==========================================================================
@dataclass
class Node:
    index: int
    cell: DecodeCell
    slot: int
    alias: int          # position among the cells sharing this file unit
    file_off: int
    far: int
    device: int
    kind: int           # 0 canonical, 1 mirror
    weight: int
    flags: int
    hue: int
    nxt: int = 0
    peek: list[int] = field(default_factory=list)
    nxt_flags: int = 0
    peek_flags: list[int] = field(default_factory=list)


EDGE_SEAM = 0x01     # source and target are on opposite sides of the device boundary
EDGE_MIRROR = 0x02   # the target address is a MIRROR, not the canonical window
EDGE_BANK = 0x04     # the edge changes the CPU bank byte

NODE_SEAM_SLOT = 0x01   # this node's slot touches a device boundary
NODE_DEVICE1 = 0x02     # the node lives in the second physical mask ROM
NODE_REGION_B = 0x04    # file offset >= $400000 (ExHiROM's second region)


def build_nodes(cm: CartMap, plan: SlotPlan, rng: random.Random) -> list[Node]:
    res = set(plan.reserved)
    by_unit: dict[int, list[DecodeCell]] = {}
    for c in cm.decode_cells():
        if c.file_start // SLOT in res:
            continue
        by_unit.setdefault(c.file_start, []).append(c)

    seam_slots = {d.file_end // SLOT - 1 for d in cm.devices}
    seam_slots |= {d.file_end // SLOT for d in cm.devices if d.file_end < cm.size}

    nodes: list[Node] = []
    for file_start in sorted(by_unit):
        cells = by_unit[file_start]
        if NODE_OFF + NODE_BYTES * len(cells) > NODE_OFF + NODE_LEN:
            raise SystemExit(
                f"file unit ${file_start:06X} has {len(cells)} decode cells; the "
                f"slot record only has room for {NODE_LEN // NODE_BYTES} nodes"
            )
        for alias, c in enumerate(cells):
            off = file_start + NODE_OFF + NODE_BYTES * alias
            dev, _ = cm.physical(off)
            slot = file_start // SLOT
            flags = (NODE_SEAM_SLOT if slot in seam_slots else 0)
            flags |= (NODE_DEVICE1 if dev else 0)
            flags |= (NODE_REGION_B if off >= 0x400000 else 0)
            nodes.append(Node(
                index=len(nodes), cell=c, slot=slot, alias=alias, file_off=off,
                far=c.far + NODE_OFF + NODE_BYTES * alias, device=dev,
                kind=0 if c.canonical else 1, weight=pattern(off),
                flags=flags, hue=(len(nodes) * 5 + pattern(off)) & 3,
            ))

    n = len(nodes)
    # The covering cycle: a seeded permutation, so successive nodes are far
    # apart in both file and CPU space (a sequential chain would be a prefetch
    # test, not a decode test).
    perm = list(range(n))
    rng.shuffle(perm)
    for i, ni in enumerate(perm):
        nodes[ni].nxt = nodes[perm[(i + 1) % n]].far

    # Two adversarial peek edges per node: one biased to the OTHER physical
    # device (so it crosses the seam), one biased to a MIRROR-addressed node.
    other_dev = {d: [x for x in nodes if x.device != d] for d in {x.device for x in nodes}}
    mirrors = [x for x in nodes if x.kind == 1]
    for nd in nodes:
        cands = other_dev.get(nd.device) or nodes
        p0 = rng.choice(cands)
        p1 = rng.choice(mirrors) if mirrors else rng.choice(nodes)
        nd.peek = [p0.far + 1, p1.far + 1]   # the weight byte: pattern(file offset)
        nd.peek_flags = [edge_flags(cm, nd, p0), edge_flags(cm, nd, p1)]
    tgt = {x.far: x for x in nodes}
    for nd in nodes:
        nd.nxt_flags = edge_flags(cm, nd, tgt[nd.nxt])
    return nodes


def edge_flags(cm: CartMap, src: Node, dst: Node) -> int:
    f = 0
    if src.device != dst.device:
        f |= EDGE_SEAM
    if dst.kind == 1:
        f |= EDGE_MIRROR
    if (src.far >> 16) != (dst.far >> 16):
        f |= EDGE_BANK
    return f


def node_bytes(nd: Node) -> bytes:
    out = bytearray(NODE_BYTES)
    out[0] = nd.kind
    out[1] = nd.weight
    out[2] = nd.flags
    out[3] = nd.hue
    out[4:7] = nd.nxt.to_bytes(3, "little")
    out[7] = nd.nxt_flags
    out[8:11] = nd.peek[0].to_bytes(3, "little")
    out[11] = nd.peek_flags[0]
    out[12:15] = nd.peek[1].to_bytes(3, "little")
    out[15] = nd.peek_flags[1]
    return bytes(out)


# ==========================================================================
# Act 1: the bytecode chapters
# ==========================================================================
LOOP_REGS = (6, 7)      # never written by a loop body -- this is what bounds the VM
GEN_REGS = (0, 1, 2, 3, 4, 5)

#: `NOP` is one byte, so a run of it is self-aligning: filler can never be
#: mistaken for an operand no matter where the PC enters it.
FILL = bytes([OP["NOP"]])


class ChapterWriter:
    """Emits exactly `length` bytes of bytecode, tail-linked to the next chapter.

    Everything it can emit terminates: forward branches only, and the one
    backward branch (LOOP) is always preceded by an IMM that seeds its counter
    with 2..8 and followed by a body that provably never writes that counter."""

    def __init__(self, rng: random.Random, length: int, tail: int = 0):
        self.rng, self.length, self.tail = rng, length, tail
        self.buf = bytearray()

    @property
    def left(self) -> int:
        return self.length - len(self.buf)

    @property
    def room(self) -> int:
        """Bytes still spendable on body instructions.  Every emitter guards on
        this, never on `left` -- the tail (JFAR or HALT) is not negotiable, and
        an emitter that overshot it would leave a chapter that runs off its own
        end into whatever the next slot happens to hold."""
        return self.left - self.tail

    def emit(self, *bs: int) -> None:
        self.buf.extend(bs)

    #: The instruction menu for generated chapter bodies, as a weighted list.
    #:
    #: MOVE is deliberately RARE -- one slot in each menu. On target a drawn
    #: segment costs ~0.94 frames of `canvas_line` while an executed op costs
    #: ~1/24 of a frame, so MOVE density, not op count, is what sets the act's
    #: duration: the first cut drew MOVE 2 times in 9 and spent 81% of a 245 s act
    #: inside canvas_line. These weights put the drawing floor inside the frame
    #: budget while keeping every opcode in the ISA exercised.
    #: Written as base + MOVE + base so the MOVE rate is one slot in the whole
    #: menu and is re-tuned by changing the base length alone.
    _WIDE_BASE = ("IMM", "IMMH", "ALU", "LOAD", "TURN", "PEN", "EMIT",
                  "TURN", "EMIT", "PEN", "ALU")
    WIDE_MENU = _WIDE_BASE + ("MOVE",) + _WIDE_BASE          # 1 MOVE in 23
    _NARROW_BASE = ("TURN", "PEN", "EMIT", "TURN", "EMIT", "PEN", "EMIT")
    NARROW_MENU = _NARROW_BASE + ("MOVE",) + _NARROW_BASE    # 1 MOVE in 15

    def _straight(self, avoid: tuple[int, ...] = ()) -> int:
        """One instruction with no control flow.  Returns its byte length."""
        rng = self.rng
        pool = [r for r in GEN_REGS if r not in avoid]
        if self.room >= 3:
            op = rng.choice(self.WIDE_MENU)
        elif self.room >= 2:
            op = rng.choice(self.NARROW_MENU)
        else:
            self.emit(OP["NOP"])
            return 1
        if op == "IMM":
            self.emit(OP["IMM"], rng.choice(pool), rng.randrange(256)); return 3
        if op == "IMMH":
            self.emit(OP["IMMH"], rng.choice(pool), rng.randrange(256)); return 3
        if op == "ALU":
            d, s = rng.choice(pool), rng.choice(pool)
            self.emit(OP["ALU"], rng.randrange(8), (d << 4) | s); return 3
        if op == "LOAD":
            self.emit(OP["LOAD"], rng.choice(pool), rng.choice(pool)); return 3
        if op == "TURN":
            self.emit(OP["TURN"], rng.choice((13, 23, 29, 37, 47, 61))); return 2
        if op == "PEN":
            self.emit(OP["PEN"], rng.randrange(4)); return 2
        if op == "EMIT":
            self.emit(OP["EMIT"], rng.choice(pool)); return 2
        self.emit(OP["MOVE"], rng.choice(pool)); return 2

    def _loop(self) -> None:
        """IMM rL,k ; <body that never writes rL> ; LOOP rL,-(len(body)+3).

        Terminating by construction: the counter is seeded 2..8 immediately
        before the body, the body cannot write it (LOOP_REGS is in `avoid`) and
        cannot branch, so the loop runs exactly k times."""
        rng = self.rng
        reg = rng.choice(LOOP_REGS)
        self.emit(OP["IMM"], reg, rng.randrange(2, 9))
        body = 0
        want = rng.randrange(8, 40)
        while body < want and self.room >= 3 + 3:     # room for one more + LOOP
            body += self._straight(avoid=LOOP_REGS)
        if body == 0 or body + 3 > 128:              # int8 displacement limit
            self.emit(OP["NOP"], OP["NOP"], OP["NOP"])   # degenerate: drop the loop
            return
        self.emit(OP["LOOP"], reg, (256 - (body + 3)) & 0xFF)

    def _skip(self) -> None:
        """JZ ra,+n or JREL +n, jumping over exactly one straight instruction."""
        rng = self.rng
        scratch = ChapterWriter(rng, 8, tail=0)
        n = scratch._straight()
        use_jz = bool(rng.randrange(2))
        need = (3 if use_jz else 2) + n
        if self.room < need:
            self.emit(OP["NOP"])
            return
        if use_jz:
            self.emit(OP["JZ"], rng.choice(GEN_REGS), n)
        else:
            self.emit(OP["JREL"], n)
        self.buf.extend(scratch.buf[:n])

    def body(self, syncs: int) -> None:
        """Fill everything but the tail, spending `syncs` instructions on SYNC."""
        placed = 0
        while self.room > 0:
            if placed < syncs and self.room >= 2 and self.rng.randrange(24) == 0:
                self.emit(OP["SYNC"], self.rng.randrange(1, 4))
                placed += 1
                continue
            r = self.rng.randrange(10)
            if r < 2 and self.room >= 3 + 3 + 3:
                self._loop()
            elif r < 4 and self.room >= 6:
                self._skip()
            else:
                self._straight()

    def finish_jfar(self, target: int) -> bytes:
        assert self.left == 4, f"tail is {self.left} bytes, JFAR needs 4"
        self.emit(OP["JFAR"], target & 0xFF, (target >> 8) & 0xFF, (target >> 16) & 0xFF)
        assert len(self.buf) == self.length
        return bytes(self.buf)

    def finish_halt(self) -> bytes:
        assert self.left == 1, f"tail is {self.left} bytes, HALT needs 1"
        self.emit(OP["HALT"])
        assert len(self.buf) == self.length
        return bytes(self.buf)


def chapter_sites(cm: CartMap, plan: SlotPlan) -> list[tuple[int, int, bool]]:
    """(file offset, length, is_straddle) for each chapter, in march order.

    One chapter per available slot, except that the slot whose end IS a physical
    device boundary hosts the STRADDLE chapter -- placed at the very top of the
    slot so its body runs off the end of device 1 and into device 2.  The slot on
    the far side of that boundary then has no chapter of its own: the straddle's
    tail already covers it, and that is the point of the act."""
    seam_starts = {d.file_end for d in cm.devices if d.file_end < cm.size}
    avail = list(plan.available)
    straddle_from = {}
    for start in sorted(seam_starts):
        a, b = start // SLOT - 1, start // SLOT
        if a in plan.available and b in plan.available:
            straddle_from[a] = b
    consumed = set(straddle_from.values())
    sites = []
    for s in avail:
        if s in consumed:
            continue
        if s in straddle_from:
            sites.append((s * SLOT + STRADDLE_OUT_OFF, CHAP_LEN, True))
        else:
            sites.append((s * SLOT + CHAP_OFF, CHAP_LEN, False))
    sites.sort()
    return sites


def build_straddle_chapter(length: int, next_target: int) -> bytes:
    """The seam chapter, hand-laid rather than generated.

    Byte `STRADDLE_OUT_LEN - 1` of this run is the LAST byte of physical ROM 1
    and holds a SYNC opcode whose operand is the FIRST byte of physical ROM 2 --
    one VM instruction split across the non-monotonic device boundary."""
    buf = bytearray(FILL * length)
    seam = STRADDLE_OUT_LEN            # index of the first byte past the boundary
    buf[0] = OP["MARK"]                # folds the PC on entry
    buf[seam - 2] = OP["MARK"]         # folds the PC one byte before the boundary
    buf[seam - 1] = OP["SYNC"]         # opcode  at file ...$3FFFFF  ($FF:FFFF)
    buf[seam] = 0x02                   # operand at file ...$400000  ($40:0000)
    buf[seam + 1] = OP["MARK"]         # folds the PC just past the boundary
    buf[seam + 2] = OP["IMM"]; buf[seam + 3] = 0; buf[seam + 4] = 0x10
    buf[seam + 5] = OP["LOAD"]; buf[seam + 6] = 0; buf[seam + 7] = 1
    buf[seam + 8] = OP["EMIT"]; buf[seam + 9] = 1
    buf[length - 4] = OP["JFAR"]
    buf[length - 3] = next_target & 0xFF
    buf[length - 2] = (next_target >> 8) & 0xFF
    buf[length - 1] = (next_target >> 16) & 0xFF
    return bytes(buf)


def build_act1(cm: CartMap, plan: SlotPlan, rng: random.Random
               ) -> tuple[list[tuple[int, bytes]], int, list[int]]:
    sites = chapter_sites(cm, plan)
    if not sites:
        raise SystemExit("no room for any act-1 chapter")
    out: list[tuple[int, bytes]] = []
    straddle_offsets: list[int] = []
    for i, (off, length, straddle) in enumerate(sites):
        last = i == len(sites) - 1
        nxt = sites[(i + 1) % len(sites)][0]
        if straddle:
            straddle_offsets.append(off + STRADDLE_OUT_LEN)
            out.append((off, build_straddle_chapter(length, nxt)))
            continue
        w = ChapterWriter(rng, length, tail=1 if last else 4)
        w.emit(OP["MARK"])
        w.body(syncs=2)
        out.append((off, w.finish_halt() if last else w.finish_jfar(nxt)))
    return out, sites[0][0], straddle_offsets


# ==========================================================================
# Act 3: data pages, heights, self-describing metadata
# ==========================================================================
def grid_dims(nslots: int) -> tuple[int, int]:
    gw = min(16, nslots)
    return gw, (nslots + gw - 1) // gw


def build_act3(cm: CartMap, plan: SlotPlan) -> list[tuple[int, bytes]]:
    gw, _ = grid_dims(plan.n)
    seam_slots = {d.file_end // SLOT - 1 for d in cm.devices}
    seam_slots |= {d.file_end // SLOT for d in cm.devices if d.file_end < cm.size}
    out = []
    for slot in plan.available:
        base = slot * SLOT
        gx, gy = slot % gw, slot // gw
        tex = bytes(texel(base, gx, gy, u, v) for v in range(TEX_H) for u in range(TEX_W))
        hgt = bytes(height(gx, gy, i, j) for j in range(HGT_H) for i in range(HGT_W))
        assert len(tex) == DATA_LEN and len(hgt) == HGT_LEN
        tf = hf = 0
        for b in tex:
            tf = fold(tf, b)
        for b in hgt:
            hf = fold(hf, b)
        dev, _ = cm.physical(base)
        meta = bytearray(META_LEN)
        meta[0:3] = base.to_bytes(3, "little")
        meta[3] = slot & 0xFF
        meta[4] = (slot >> 8) & 0xFF
        meta[5] = ((1 if dev else 0)
                   | (0x02 if slot in seam_slots else 0)
                   | (0x04 if base >= 0x400000 else 0))
        meta[6] = gx
        meta[7] = gy
        meta[8:10] = tf.to_bytes(2, "little")
        meta[10:12] = hf.to_bytes(2, "little")
        out.append((base + DATA_OFF, tex))
        out.append((base + HGT_OFF, hgt))
        out.append((base + META_OFF, bytes(meta)))
    return out


# ==========================================================================
# Assembly
# ==========================================================================
@dataclass
class Build:
    cm: CartMap
    plan: SlotPlan
    nodes: list[Node]
    writes: list[tuple[int, bytes]]
    act1_entry: int
    straddle_offsets: list[int]
    image: bytes
    desc: dict
    result: dict


def build(mapping: str, size: int, far_slots: int = 1, seed: int = SEED) -> Build:
    cm = CartMap(mapping, size)
    plan = plan_slots(cm, far_slots)
    rng = random.Random(seed)

    chapters, entry, straddles = build_act1(cm, plan, rng)
    nodes = build_nodes(cm, plan, rng)
    pages = build_act3(cm, plan)

    writes: list[tuple[int, bytes]] = list(chapters)
    writes += [(nd.file_off, node_bytes(nd)) for nd in nodes]
    writes += pages
    writes.sort()

    img = bytearray(cm.size)
    prev_end = -1
    for off, blob in writes:
        if off < prev_end:
            raise AssertionError(
                f"payload writes overlap at file ${off:06X}; the slot record is "
                "supposed to make that impossible"
            )
        if off + len(blob) > cm.size:
            raise AssertionError(f"write at ${off:06X} +{len(blob)} runs off the image")
        img[off:off + len(blob)] = blob
        prev_end = off + len(blob)

    gw, gh = grid_dims(plan.n)
    ops_guess = 1 << 22
    desc = {
        "mapping": cm.mapping,
        "size": cm.size,
        "speed": cm.speed,
        "seed": seed,
        "slot": SLOT,
        "act1": {"entry": entry, "op_budget": ops_guess},
        "act2": {"entry_far": nodes[0].far if nodes else 0, "nodes": len(nodes)},
        "act3": {"grid_w": gw, "grid_h": gh, "samples_per_page": 16,
                 "slots": plan.n, "skip": list(plan.reserved)},
    }
    # act2's entry must be the START of the cycle, not node 0 -- node 0 is
    # wherever the file order put it, and the chain visits every node exactly
    # once from ANY starting point, so node 0 is a fine (and stable) entry.
    res = ora.run_all(cm, bytes(img), desc)
    desc["act1"]["op_budget"] = res["act1"]["ops"] + 1024
    desc["act1"]["ops"] = res["act1"]["ops"]

    return Build(cm=cm, plan=plan, nodes=nodes, writes=writes, act1_entry=entry,
                 straddle_offsets=straddles, image=bytes(img), desc=desc, result=res)


# ==========================================================================
# Coverage: the gate the plan asks for
# ==========================================================================
def coverage(b: Build) -> dict:
    """In-degree of every decode cell, derived from the model's own enumeration.

    A cell is "covered" when some act-2 edge -- the covering-cycle successor or
    either peek -- names an address inside it.  Reserved cells (linked code, the
    far-section arena) are reported separately and are the only ones allowed to
    be uncovered."""
    cm = b.cm
    cells = cm.decode_cells()
    res = set(b.plan.reserved)
    indeg = {c.key: 0 for c in cells}
    by_cell = {}
    for c in cells:
        by_cell[c.key] = c
    seam = [d.file_end for d in cm.devices if d.file_end < cm.size]

    def cell_of(far: int) -> tuple[int, int]:
        return (far >> 16) & 0xFF, 0x8000 if (far & 0x8000) else 0x0000

    edges = 0
    seam_edges = mirror_edges = bank_edges = 0
    for nd in b.nodes:
        for tgt, fl in [(nd.nxt, nd.nxt_flags)] + list(zip(nd.peek, nd.peek_flags)):
            key = cell_of(tgt)
            if key not in indeg:
                raise AssertionError(f"edge target ${tgt:06X} is not a decode cell")
            indeg[key] += 1
            edges += 1
            seam_edges += bool(fl & EDGE_SEAM)
            mirror_edges += bool(fl & EDGE_MIRROR)
            bank_edges += bool(fl & EDGE_BANK)

    covered = [k for k, v in indeg.items() if v > 0]
    uncovered = [k for k, v in indeg.items() if v == 0]
    reserved_cells = [c.key for c in cells if c.file_start // SLOT in res]
    bad = sorted(set(uncovered) - set(reserved_cells))
    return {
        "cells": len(cells),
        "cells_canonical": sum(1 for c in cells if c.canonical),
        "cells_mirror": sum(1 for c in cells if not c.canonical),
        "cells_reserved": len(reserved_cells),
        "cells_available": len(cells) - len(reserved_cells),
        "covered": len(covered),
        "uncovered_available": [f"${b_:02X}:{a:04X}" for b_, a in bad],
        "edges": edges,
        "edges_seam": seam_edges,
        "edges_mirror": mirror_edges,
        "edges_bank": bank_edges,
        "device_boundaries": [f"${x:06X}" for x in seam],
        "min_indegree_available": min(
            (v for k, v in indeg.items() if k not in set(reserved_cells)), default=0),
    }


# ==========================================================================
# Reports and emitters
# ==========================================================================
def report(b: Build) -> dict:
    cov = coverage(b)
    r = b.result
    nonzero = sum(len(blob) for _, blob in b.writes)
    rep = dict(b.desc)
    rep["generated_by"] = "tools/snes-seamdemo-gen.py"
    rep["model"] = "tools/snes_cartmap.py"
    rep["slots"] = {
        "total": b.plan.n,
        "reserved": list(b.plan.reserved),
        "available": len(b.plan.available),
        "code_range": [b.plan.code_lo, b.plan.code_hi],
        "far_arena": list(b.plan.far_slots),
    }
    rep["slot_record"] = {
        "straddle_in": [STRADDLE_IN_OFF, STRADDLE_IN_LEN],
        "data_page": [DATA_OFF, DATA_LEN],
        "heights": [HGT_OFF, HGT_LEN],
        "meta": [META_OFF, META_LEN],
        "nodes": [NODE_OFF, NODE_LEN],
        "chapter": [CHAP_OFF, CHAP_LEN],
        "straddle_out": [STRADDLE_OUT_OFF, STRADDLE_OUT_LEN],
    }
    rep["coverage"] = cov
    rep["payload_bytes"] = nonzero
    rep["seam"] = {
        "device_boundary": [d.file_end for d in b.cm.devices if d.file_end < b.cm.size],
        "straddle_instruction_at": b.straddle_offsets,
        "act1_marks": r["act1"]["marks"],
    }
    rep["oracle"] = {
        "act1_crc": r["act1"]["crc"], "act1_ops": r["act1"]["ops"],
        "act1_segments": r["act1"]["segments"],
        "act2_crc": r["act2"]["crc"], "act2_nodes": r["act2"]["nodes"],
        "act3_crc": r["act3"]["crc"], "act3_samples": r["act3"]["samples"],
        "act3_pages": r["act3"]["pages"],
        "corpus_result": r["corpus_result"],
        "cartridge_reads": r["rom_reads"],
    }
    return rep


def emit_header(b: Build) -> str:
    r = b.result
    cov = coverage(b)
    tr = ora.translate_table(b.cm)
    gw, gh = grid_dims(b.plan.n)
    L: list[str] = []
    A = L.append
    A("/* GENERATED by tools/snes-seamdemo-gen.py from tools/snes_cartmap.py -- do not edit.")
    A(f" * {b.cm.mapping}, 0x{b.cm.size:X} bytes, map mode ${b.cm.map_mode:02X}, "
      f"seed 0x{b.desc['seed']:08X}.")
    A(" * Plan: docs/plans/2026-08-01-exhirom-three-act-synthesis-cart.md (P0). */")
    A("#ifndef SEAMDEMO_DATA_H")
    A("#define SEAMDEMO_DATA_H")
    A("")
    A(f"#define SEAMDEMO_IMAGE_BYTES 0x{b.cm.size:06X}UL")
    A(f"#define SEAMDEMO_MAP_MODE 0x{b.cm.map_mode:02X}u")
    A(f"#define SEAMDEMO_SLOT 0x{SLOT:04X}u")
    A(f"#define SEAMDEMO_SLOTS {b.plan.n}")
    A("")
    A("/* file offset -> 24-bit CPU address: far = file + delta, per range. */")
    A(f"#define SEAMDEMO_XLAT_COUNT {len(tr)}")
    A("static const unsigned long seamdemo_xlat_lo[SEAMDEMO_XLAT_COUNT] = {")
    A("  " + ", ".join(f"0x{lo:06X}UL" for lo, _, _ in tr) + " };")
    A("static const unsigned long seamdemo_xlat_hi[SEAMDEMO_XLAT_COUNT] = {")
    A("  " + ", ".join(f"0x{hi:06X}UL" for _, hi, _ in tr) + " };")
    A("static const unsigned long seamdemo_xlat_delta[SEAMDEMO_XLAT_COUNT] = {")
    A("  " + ", ".join(f"0x{d & 0xFFFFFF:06X}UL" for _, _, d in tr) + " };")
    A("")
    A("/* --- act 1: the VM ISA.  Dense 0..15 so switch(op) is a jump table. --- */")
    for i, (name, nargs) in enumerate(OPS):
        A(f"#define VMOP_{name} 0x{i:02X}u  /* {nargs} operand byte(s) */")
    A(f"#define VMOP_COUNT {len(OPS)}")
    for i, name in enumerate(ALU_OPS):
        A(f"#define VMALU_{name} {i}u")
    A(f"#define VMALU_COUNT {len(ALU_OPS)}")
    A("static const signed char seamdemo_dir16[16][2] = {")
    A("  " + ", ".join(f"{{{dx},{dy}}}" for dx, dy in ora.DIR16) + " };")
    A(f"#define SEAMDEMO_CANVAS_MASK 0x{ora.CANVAS_MASK:02X}u")
    A("")
    A(f"#define SEAMDEMO_ACT1_ENTRY 0x{b.act1_entry:06X}UL")
    A(f"#define SEAMDEMO_ACT1_OP_BUDGET {b.desc['act1']['op_budget']}UL")
    A(f"#define SEAMDEMO_ACT1_OPS {r['act1']['ops']}UL")
    A(f"#define SEAMDEMO_ACT1_SEGMENTS {r['act1']['segments']}UL")
    A(f"#define SEAMDEMO_ACT1_MARKS {r['act1']['marks']}u")
    A(f"#define SEAMDEMO_ACT1_CRC 0x{r['act1']['crc']:04X}u")
    for i, off in enumerate(b.straddle_offsets):
        A(f"#define SEAMDEMO_SEAM{i}_FILE 0x{off:06X}UL  "
          f"/* the SYNC operand byte: first byte of the next device */")
    A("")
    A("/* --- act 2: one 16-byte node per decode cell (mirrors included) --- */")
    A(f"#define SEAMDEMO_NODE_BYTES {NODE_BYTES}")
    A("#define SEAMDEMO_NODE_KIND 0")
    A("#define SEAMDEMO_NODE_WEIGHT 1")
    A("#define SEAMDEMO_NODE_FLAGS 2")
    A("#define SEAMDEMO_NODE_HUE 3")
    A("#define SEAMDEMO_NODE_NEXT 4")
    A("#define SEAMDEMO_NODE_NEXT_FLAGS 7")
    A("#define SEAMDEMO_NODE_PEEK0 8")
    A("#define SEAMDEMO_NODE_PEEK0_FLAGS 11")
    A("#define SEAMDEMO_NODE_PEEK1 12")
    A("#define SEAMDEMO_NODE_PEEK1_FLAGS 15")
    A(f"#define SEAMDEMO_EDGE_SEAM 0x{EDGE_SEAM:02X}u")
    A(f"#define SEAMDEMO_EDGE_MIRROR 0x{EDGE_MIRROR:02X}u")
    A(f"#define SEAMDEMO_EDGE_BANK 0x{EDGE_BANK:02X}u")
    A(f"#define SEAMDEMO_ACT2_ENTRY 0x{b.desc['act2']['entry_far']:06X}UL")
    A(f"#define SEAMDEMO_ACT2_NODES {len(b.nodes)}u")
    A(f"#define SEAMDEMO_ACT2_CRC 0x{r['act2']['crc']:04X}u")
    A("")
    A("/* --- act 3: one data page per slot, swept boustrophedon --- */")
    A(f"#define SEAMDEMO_DATA_OFF 0x{DATA_OFF:04X}u")
    A(f"#define SEAMDEMO_HGT_OFF 0x{HGT_OFF:04X}u")
    A(f"#define SEAMDEMO_META_OFF 0x{META_OFF:04X}u")
    A(f"#define SEAMDEMO_NODE_OFF 0x{NODE_OFF:04X}u")
    A(f"#define SEAMDEMO_CHAP_OFF 0x{CHAP_OFF:04X}u")
    A(f"#define SEAMDEMO_TEX_W {TEX_W}u")
    A(f"#define SEAMDEMO_TEX_H {TEX_H}u")
    A(f"#define SEAMDEMO_HGT_W {HGT_W}u")
    A(f"#define SEAMDEMO_GRID_W {gw}u")
    A(f"#define SEAMDEMO_GRID_H {gh}u")
    A(f"#define SEAMDEMO_SAMPLES_PER_PAGE {b.desc['act3']['samples_per_page']}u")
    A(f"#define SEAMDEMO_ACT3_SKIP_COUNT {len(b.plan.reserved)}")
    A("static const unsigned int seamdemo_act3_skip[SEAMDEMO_ACT3_SKIP_COUNT] = {")
    A("  " + ", ".join(str(s) for s in b.plan.reserved) + " };")
    A(f"#define SEAMDEMO_ACT3_SAMPLES {r['act3']['samples']}UL")
    A(f"#define SEAMDEMO_ACT3_CRC 0x{r['act3']['crc']:04X}u")
    A("")
    A(f"#define SEAMDEMO_CORPUS_RESULT 0x{r['corpus_result']:04X}u")
    A(f"/* decode-cell coverage: {cov['covered']}/{cov['cells']} cells "
      f"({cov['cells_reserved']} reserved), {cov['edges']} edges, "
      f"{cov['edges_seam']} seam-crossing, {cov['edges_mirror']} mirror-addressed */")
    A("")
    A("#endif")
    A("")
    return "\n".join(L)


# ==========================================================================
# fill: post-link payload injection
# ==========================================================================
def do_fill(b: Build, path: str) -> dict:
    with open(path, "rb") as f:
        rom = bytearray(f.read())
    if len(rom) != b.cm.size:
        raise SystemExit(f"{path}: linked image is {len(rom)} bytes, model expects {b.cm.size}")

    # Refuse to overwrite anything the linker actually emitted outside the
    # reserved slots.  The ExHiROM script puts .far_text/.far_rodata at the start
    # of rom_b, so a ROM that grows past the far arena must widen --far-slots
    # rather than silently lose code to the payload.
    res = set(b.plan.reserved)
    foreign = []
    for slot in b.plan.available:
        chunk = rom[slot * SLOT:(slot + 1) * SLOT]
        if any(chunk):
            foreign.append(slot)
    if foreign:
        raise SystemExit(
            "linked image already has content in payload slots "
            + ", ".join(f"{s} (file ${s * SLOT:06X})" for s in foreign[:8])
            + (" ..." if len(foreign) > 8 else "")
            + " -- widen --far-slots or shrink the ROM"
        )

    for off, blob in b.writes:
        rom[off:off + len(blob)] = blob
    with open(path, "wb") as f:
        f.write(rom)

    # Re-run the oracle against the bytes actually on disk.
    check = ora.run_all(b.cm, bytes(rom), b.desc)
    for k in ("act1", "act2", "act3"):
        if check[k]["crc"] != b.result[k]["crc"]:
            raise SystemExit(
                f"{k}: on-disk fold ${check[k]['crc']:04X} != predicted "
                f"${b.result[k]['crc']:04X}"
            )
    if check["corpus_result"] != b.result["corpus_result"]:
        raise SystemExit("corpus_result disagrees between the in-memory and on-disk images")
    rep = report(b)
    rep["fill"] = {"path": os.path.abspath(path), "verified": True}
    return rep


def check_extents(b: Build, path: str) -> dict:
    """Diff a LINKED (pre-fill) image's non-zero extents against `plan_slots()`.

    The P0 CRCs are predicted before the ROM is linked, which is only legitimate
    if the linker's output lives entirely inside the reserved slots.  This is the
    check that proves it on the real artefact rather than trusting the reserved
    set: it reports every slot the linker actually wrote to, so a ROM that
    outgrows `--far-slots` is a named failure instead of a payload that silently
    overwrites `.far_text`."""
    with open(path, "rb") as f:
        rom = f.read()
    if len(rom) != b.cm.size:
        raise SystemExit(f"{path}: linked image is {len(rom)} bytes, model expects {b.cm.size}")
    used = [s for s in range(b.plan.n) if any(rom[s * SLOT:(s + 1) * SLOT])]
    res = set(b.plan.reserved)
    stray = [s for s in used if s not in res]
    unused_reserved = [s for s in b.plan.reserved if s not in set(used)]
    # How much of the LAST used reserved slot is actually occupied -- the headroom
    # number P1-P3 need when deciding whether to widen --far-slots.
    tail = max(used) if used else -1
    fill_pct = 0.0
    if tail >= 0:
        chunk = rom[tail * SLOT:(tail + 1) * SLOT]
        last_nz = max((i for i, v in enumerate(chunk) if v), default=-1) + 1
        fill_pct = 100.0 * last_nz / SLOT
    return {
        "path": os.path.abspath(path),
        "slots_used_by_linker": used,
        "slots_reserved": list(b.plan.reserved),
        "stray": stray,
        "reserved_but_empty": unused_reserved,
        "last_used_slot": tail,
        "last_used_slot_fill_pct": round(fill_pct, 1),
        "ok": not stray,
    }


def assert_payload_only(b: Build) -> None:
    """The CRCs are computed before the ROM is linked, so no traversal may read
    a byte the linker owns.  `Image.slots_read` is the evidence."""
    img = ora.Image(b.cm, b.image)
    ora.run_act1(img, b.desc)
    ora.run_act2(img, b.desc)
    ora.run_act3(img, b.desc)
    bad = sorted(img.slots_read & set(b.plan.reserved))
    if bad:
        raise AssertionError(
            "traversals read reserved slots " + ", ".join(str(s) for s in bad)
            + " -- the pre-link CRC would not match the linked ROM"
        )


# ==========================================================================
# selfcheck
# ==========================================================================
def hand_fold_act3(b: Build) -> int:
    """An INDEPENDENT recomputation of act 3's fold.

    Deliberately written the naive way -- rebuild the expected page bytes from
    `terrain8`/`pattern` and fold them directly, never reading the image and
    never calling the oracle -- so that a generator bug that lays the atlas down
    at the wrong offset makes these two numbers disagree."""
    h = 0
    for slot, gx, gy, u, v in ora.act3_path(b.desc):
        base = slot * SLOT
        h = fold(h, slot & 0xFF)
        h = fold(h, (slot >> 8) & 0xFF)
        h = fold(h, ora.texel(base, gx, gy, u, v))
        h = fold(h, ora.height(gx, gy, u >> 2, v >> 2))
        h = fold(h, base & 0xFF)          # meta[0] == low byte of the slot's file start
    return h


def hand_fold_act2(b: Build) -> int:
    """Independent recomputation of act 2: walk the Node objects, not the image."""
    by_far = {nd.far: nd for nd in b.nodes}
    h = 0
    p = b.desc["act2"]["entry_far"]
    for _ in range(len(b.nodes)):
        nd = by_far[p]
        for byte in node_bytes(nd):
            h = fold(h, byte)
        for tgt in nd.peek:
            h = fold(h, by_far[tgt - 1].weight)   # peeks point at the weight byte
        p = nd.nxt
    h = fold(h, len(b.nodes) & 0xFF)
    h = fold(h, (len(b.nodes) >> 8) & 0xFF)
    return h


def selfcheck(verbose: bool = False) -> int:
    fails = 0

    def ok(name: str, cond: bool, detail: str = "") -> None:
        nonlocal fails
        print(f"  [{'PASS' if cond else 'FAIL'}] {name}" + (f"  {detail}" if detail else ""))
        if not cond:
            fails += 1

    dig, tot = ora._sin_digest()
    print(f"sin table: fold ${dig:04X} (baked ${ora.SIN256_DIGEST:04X}), "
          f"sum {tot} (baked {ora.SIN256_SUM})")
    ok("SIN256 is reproducible on this platform",
       dig == ora.SIN256_DIGEST and tot == ora.SIN256_SUM)

    print(f"\n-- miniature: {MINI[0]} 0x{MINI[1]:X} --")
    m = build(MINI[0], MINI[1], far_slots=0)
    r = m.result
    print(f"  slots {m.plan.n} ({len(m.plan.available)} available, "
          f"reserved {list(m.plan.reserved)}), nodes {len(m.nodes)}, "
          f"payload {sum(len(x) for _, x in m.writes)} bytes")
    print(f"  act1 ${r['act1']['crc']:04X} ({r['act1']['ops']} ops)  "
          f"act2 ${r['act2']['crc']:04X}  act3 ${r['act3']['crc']:04X}  "
          f"corpus ${r['corpus_result']:04X}")
    ok("act1 halted (the stream terminates)", r["act1"]["halted"])
    h2, h3 = hand_fold_act2(m), hand_fold_act3(m)
    ok("act2 fold: image-read oracle == independent recomputation",
       h2 == r["act2"]["crc"], f"${h2:04X} vs ${r['act2']['crc']:04X}")
    ok("act3 fold: image-read oracle == independent recomputation",
       h3 == r["act3"]["crc"], f"${h3:04X} vs ${r['act3']['crc']:04X}")
    ok("corpus_result == fold(act1, act2, act3)",
       ora.corpus_result(r["act1"]["crc"], r["act2"]["crc"], r["act3"]["crc"])
       == r["corpus_result"])
    m2 = build(MINI[0], MINI[1], far_slots=0)
    ok("generation is deterministic (byte-identical rebuild)", m2.image == m.image)
    assert_payload_only(m)
    ok("no traversal reads a reserved slot (miniature)", True)

    print("\n-- full cartridge: exhirom 0x600000 --")
    f = build("exhirom", 0x600000)
    cov = coverage(f)
    fr = f.result
    print(f"  slots {f.plan.n} ({len(f.plan.available)} available, "
          f"reserved {list(f.plan.reserved)}), nodes {len(f.nodes)}, "
          f"payload {sum(len(x) for _, x in f.writes)} bytes "
          f"({100.0 * sum(len(x) for _, x in f.writes) / f.cm.size:.1f}% of the image)")
    print(f"  act1 ${fr['act1']['crc']:04X} ({fr['act1']['ops']} ops, "
          f"{fr['act1']['marks']} marks)  act2 ${fr['act2']['crc']:04X}  "
          f"act3 ${fr['act3']['crc']:04X}  corpus ${fr['corpus_result']:04X}")
    print(f"  decode cells {cov['cells']} = {cov['cells_canonical']} canonical + "
          f"{cov['cells_mirror']} mirror; {cov['cells_reserved']} reserved, "
          f"{cov['cells_available']} available; covered {cov['covered']}")
    print(f"  edges {cov['edges']} total, {cov['edges_seam']} seam-crossing, "
          f"{cov['edges_mirror']} mirror-addressed, {cov['edges_bank']} bank-crossing; "
          f"min in-degree {cov['min_indegree_available']}")
    ok("every AVAILABLE decode cell has in-degree > 0",
       not cov["uncovered_available"],
       "uncovered: " + ", ".join(cov["uncovered_available"][:8]) if
       cov["uncovered_available"] else "")
    ok("covered + reserved == all decode cells",
       cov["covered"] + cov["cells_reserved"] == cov["cells"],
       f"{cov['covered']} + {cov['cells_reserved']} vs {cov['cells']}")
    ok("act1 halted (the stream terminates)", fr["act1"]["halted"])
    ok("act1 crosses the device seam inside one instruction",
       len(f.straddle_offsets) == 1
       and f.straddle_offsets[0] == f.cm.devices[0].file_end,
       ", ".join(f"${x:06X}" for x in f.straddle_offsets))
    ok("act1 marks one PC per chapter",
       fr["act1"]["marks"] >= len(f.plan.available) - 1,
       f"{fr['act1']['marks']} marks / {len(f.plan.available)} available slots")
    ok("act3 sweeps every available slot",
       fr["act3"]["pages"] == len(f.plan.available),
       f"{fr['act3']['pages']} / {len(f.plan.available)}")
    h2f, h3f = hand_fold_act2(f), hand_fold_act3(f)
    ok("act2 fold: image-read oracle == independent recomputation",
       h2f == fr["act2"]["crc"], f"${h2f:04X} vs ${fr['act2']['crc']:04X}")
    ok("act3 fold: image-read oracle == independent recomputation",
       h3f == fr["act3"]["crc"], f"${h3f:04X} vs ${fr['act3']['crc']:04X}")
    assert_payload_only(f)
    ok("no traversal reads a reserved slot (6 MiB)", True)
    ok("payload never overlaps the linked-code range",
       all(not (off < f.plan.code_hi and off + len(blob) > f.plan.code_lo)
           for off, blob in f.writes))
    ok("fold/pattern are the canary tool's, not a second copy",
       fold is ora._canary.fold and pattern is ora._canary.pattern)

    print(f"\n{'ALL PASS' if not fails else str(fails) + ' FAILURE(S)'}")
    return 1 if fails else 0


# ==========================================================================
def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="snes-seamdemo-gen.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("emit-header", "report", "fill", "check-extents"):
        p = sub.add_parser(name)
        p.add_argument("--mapping", default="exhirom")
        p.add_argument("--size", type=parse_size, default=0x600000)
        p.add_argument("--far-slots", type=int, default=1,
                       help="32 KiB slots reserved after the code for .far_text/.far_rodata")
        p.add_argument("--seed", type=lambda s: int(s, 0), default=SEED)
        if name in ("fill", "check-extents"):
            p.add_argument("--rom", required=True)
            p.add_argument("--report" if name == "fill" else "--json")
        else:
            p.add_argument("--out", required=True)
    sc = sub.add_parser("selfcheck")
    sc.add_argument("--verbose", action="store_true")
    args = ap.parse_args(argv[1:])

    if args.cmd == "selfcheck":
        return selfcheck(args.verbose)

    b = build(args.mapping, args.size, far_slots=args.far_slots, seed=args.seed)
    assert_payload_only(b)

    if args.cmd == "emit-header":
        with open(args.out, "w") as f:
            f.write(emit_header(b))
        cov = coverage(b)
        print(f"header {args.out}: {len(b.nodes)} nodes, "
              f"{cov['covered']}/{cov['cells']} decode cells covered, "
              f"corpus_result ${b.result['corpus_result']:04X}")
        return 0

    if args.cmd == "check-extents":
        ext = check_extents(b, args.rom)
        if args.json:
            with open(args.json, "w") as f:
                json.dump(ext, f, indent=2)
        print(f"linker wrote slots {ext['slots_used_by_linker']}; "
              f"reserved {ext['slots_reserved']}; "
              f"last used slot {ext['last_used_slot']} is "
              f"{ext['last_used_slot_fill_pct']}% full")
        if ext["stray"]:
            print("  FAIL: linker output in payload slots "
                  + ", ".join(f"{s} (file ${s * SLOT:06X})" for s in ext["stray"])
                  + " -- widen --far-slots")
            return 1
        print("  PASS: all linker output is inside the reserved slots")
        return 0

    if args.cmd == "report":
        with open(args.out, "w") as f:
            json.dump(report(b), f, indent=2)
        print(f"report {args.out}: {sum(len(x) for _, x in b.writes)} payload bytes")
        return 0

    rep = do_fill(b, args.rom)
    if args.report:
        with open(args.report, "w") as f:
            json.dump(rep, f, indent=2)
    o = rep["oracle"]
    print(f"fill {args.rom}: {rep['payload_bytes']} payload bytes, "
          f"act1 ${o['act1_crc']:04X} act2 ${o['act2_crc']:04X} act3 ${o['act3_crc']:04X} "
          f"-> corpus_result ${o['corpus_result']:04X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
