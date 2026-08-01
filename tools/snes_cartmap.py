#!/usr/bin/env python3
"""The ONE authoritative SNES cartridge address model for this repo.

Everything that needs to know where a byte of a `.sfc` file appears in 65816
address space -- the linker-script generator, the checksum/header tool, the
canary generator, the ROM-map visualiser, the host oracles -- imports this
module. Nothing reimplements the mapping. (Plan:
docs/plans/2026-07-30-exhirom-video-boundary-test.md, "Address model".)

Provenance: the decode is a line-by-line port of bsnes-jg's cartridge bus, not
a paraphrase of a wiki page.

  * `vendor/bsnes-jg/Database/boards.bml`  -- the per-board `map address=... base=... mask=...`
    lines, transcribed verbatim into BOARDS_BML below and checked against the
    vendored file by test_snes_cartmap.py (so a vendor bump that changes a
    board definition fails a host test instead of silently diverging).
  * `vendor/bsnes-jg/src/memory.hpp`       -- `Bus::mirror` / `Bus::reduce`, ported below.
  * `vendor/bsnes-jg/src/memory.cpp`       -- `Bus::map`, whose per-address body is
    `offset = reduce(A, mask); base = mirror(base, size); offset = base + mirror(offset, size - base)`.
  * `vendor/bsnes-jg/src/heuristics.cpp`   -- `scoreHeader` / header-address selection, ported
    as `score_header` / `detect_header_address` so the host can prove a generated
    image is detected as the mapping we intended.

The two directions:

    decode(bank, addr) -> file_offset | None      # emulator truth, every mirror
    windows()          -> canonical windows       # the ONE window we emit descriptors for
    file_to_cpu(off)   -> (bank, addr)            # checked inverse (canonical only)

`decode` is deliberately the mirror-aware one and `file_to_cpu` deliberately is
not: a descriptor that pointed at a mirror would still read correctly, which is
exactly the bug class this cartridge work exists to catch, so the emitting side
is restricted to canonical windows and the reading side accepts every mirror.

Usage as a CLI:  snes_cartmap.py --mapping exhirom --size 6M [--table|--windows|--holes|--selftest]
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from typing import Iterator, Optional

# --------------------------------------------------------------------------
# bsnes-jg board definitions, transcribed verbatim from
# vendor/bsnes-jg/Database/boards.bml.  Keep the text EXACTLY as it appears
# there: test_snes_cartmap.py greps the vendored file for these lines.
# --------------------------------------------------------------------------
BOARDS_BML = {
    "lorom": """\
    map address=00-7d,80-ff:8000-ffff mask=0x8000
""",
    "hirom": """\
    map address=00-3f,80-bf:8000-ffff
    map address=40-7d,c0-ff:0000-ffff
""",
    "exhirom": """\
    map address=00-3f:8000-ffff base=0x400000
    map address=40-7d:0000-ffff base=0x400000
    map address=80-bf:8000-ffff mask=0xc00000
    map address=c0-ff:0000-ffff mask=0xc00000
""",
}

MAPPINGS = tuple(BOARDS_BML)

#: Internal-header map-mode byte ($FFD5) per mapping, slow-ROM variant.
#: The FastROM variant is this | FAST_BIT ($30/$31/$35).
MAP_MODE = {"lorom": 0x20, "hirom": 0x21, "exhirom": 0x25}

#: Bit 4 of the map-mode byte is the cartridge SPEED, not part of the mapping:
#: set = FastROM (3.58 MHz bus when the CPU enables it via $420D), clear =
#: SlowROM (2.68 MHz).  Speed and mapping are orthogonal -- every mapping has
#: both variants -- so the model carries speed as its own attribute and derives
#: the byte, rather than letting callers OR a magic constant into the header.
FAST_BIT = 0x10

#: The two speeds, as the model names them.
SPEEDS = ("slow", "fast")

#: Where the internal header starts in the FILE for each mapping.  These are
#: the four addresses bsnes-jg's heuristics probe (heuristics.cpp:468-478).
HEADER_FILE_OFFSET = {"lorom": 0x007FB0, "hirom": 0x00FFB0, "exhirom": 0x40FFB0}

#: Offsets within the 0x50-byte header block.
OFF_MAP_MODE = 0x25
OFF_CART_TYPE = 0x26
OFF_ROM_SIZE = 0x27
OFF_RAM_SIZE = 0x28
OFF_REGION = 0x29
OFF_LICENSEE = 0x2A
OFF_VERSION = 0x2B
OFF_COMPLEMENT = 0x2C
OFF_CHECKSUM = 0x2E
OFF_VEC_NATIVE = 0x30  # $FFE0
OFF_VEC_EMU = 0x40  # $FFF0
OFF_RESET = 0x4C  # $FFFC

#: Banks the S-CPU hard-wires to WRAM; a cartridge map never reaches them.
WRAM_BANKS = (0x7E, 0x7F)


# --------------------------------------------------------------------------
# Ported bsnes-jg bus primitives (vendor/bsnes-jg/src/memory.hpp:186-208).
# --------------------------------------------------------------------------
def bus_mirror(addr: int, size: int) -> int:
    """Port of `Bus::mirror`. Folds `addr` into `[0, size)` the way the SNES
    address decoder mirrors a mask ROM that does not fill its slot."""
    if size == 0:
        return 0
    base = 0
    mask = 1 << 23
    while addr >= size:
        while not (addr & mask):
            mask >>= 1
        addr -= mask
        if size > mask:
            size -= mask
            base += mask
        mask >>= 1
    return base + addr


def bus_reduce(addr: int, mask: int) -> int:
    """Port of `Bus::reduce`. Deletes the bits set in `mask` from `addr`,
    compacting what is left (this is what turns a `mask=0xc00000` board line
    into "ignore A22/A23")."""
    while mask:
        bits = (mask & -mask) - 1
        addr = ((addr >> 1) & ~bits) | (addr & bits)
        mask = (mask & (mask - 1)) >> 1
    return addr


_MAP_RE = re.compile(
    r"map\s+address=(?P<banks>[0-9a-f,\-]+):(?P<addrs>[0-9a-f,\-]+)"
    r"(?:\s+base=(?P<base>0x[0-9a-f]+))?"
    r"(?:\s+mask=(?P<mask>0x[0-9a-f]+))?"
)


@dataclass(frozen=True)
class BoardMap:
    """One `map address=...` line from boards.bml."""

    banks: tuple[tuple[int, int], ...]
    addrs: tuple[tuple[int, int], ...]
    base: int
    mask: int

    def covers(self, bank: int, addr: int) -> bool:
        return any(lo <= bank <= hi for lo, hi in self.banks) and any(
            lo <= addr <= hi for lo, hi in self.addrs
        )


def _ranges(spec: str) -> tuple[tuple[int, int], ...]:
    out = []
    for part in spec.split(","):
        bits = part.split("-")
        lo = int(bits[0], 16)
        hi = int(bits[-1], 16)
        out.append((lo, hi))
    return tuple(out)


def parse_board(text: str) -> tuple[BoardMap, ...]:
    maps = []
    for line in text.strip().splitlines():
        m = _MAP_RE.search(line.strip())
        if not m:
            raise ValueError(f"unparsable board map line: {line!r}")
        maps.append(
            BoardMap(
                banks=_ranges(m.group("banks")),
                addrs=_ranges(m.group("addrs")),
                base=int(m.group("base") or "0", 16),
                mask=int(m.group("mask") or "0", 16),
            )
        )
    return tuple(maps)


BOARDS = {name: parse_board(text) for name, text in BOARDS_BML.items()}


# --------------------------------------------------------------------------
# Physical decomposition
# --------------------------------------------------------------------------
@dataclass(frozen=True)
class Device:
    """One physical mask ROM inside the cartridge."""

    index: int
    file_start: int
    length: int

    @property
    def file_end(self) -> int:  # exclusive
        return self.file_start + self.length

    @property
    def mbit(self) -> int:
        return self.length * 8 // 1024 // 1024

    @property
    def label(self) -> str:
        """Human size, never rounding a sub-megabit device down to '0Mbit'."""
        if self.length >= 1 << 20:
            return f"{self.mbit}Mbit"
        return f"{self.length * 8 // 1024}Kbit"


MIN_SIZE = 0x8000  # 32 KiB
MAX_DEVICES = 2  # a cartridge in this project's scope carries at most two mask ROMs


def decompose(size: int) -> tuple[Device, ...]:
    """Split a logical image length into descending physical mask ROMs.

    The decomposition is just the binary representation of `size`, largest
    power of two first -- which is how a real multi-chip cartridge is built and
    what the compound checksum rule assumes.  Sizes needing more than
    `MAX_DEVICES` chips, or not a whole multiple of the 32 KiB minimum, are
    rejected: those are the "invalid/truncated/ambiguously padded images that
    the host tools must reject" fixtures.
    """
    if size < MIN_SIZE:
        raise ValueError(f"image too small: {size} bytes (minimum {MIN_SIZE})")
    if size % MIN_SIZE:
        raise ValueError(
            f"image length {size} (0x{size:X}) is not a multiple of 32 KiB; "
            "a mask ROM cannot be a fractional size"
        )
    bits = [1 << i for i in reversed(range(size.bit_length())) if size & (1 << i)]
    if len(bits) > MAX_DEVICES:
        raise ValueError(
            f"image length {size} (0x{size:X}) decomposes into {len(bits)} mask ROMs "
            f"({' + '.join(f'0x{b:X}' for b in bits)}); at most {MAX_DEVICES} are supported. "
            "A non-power-of-two remainder is not a buildable cartridge."
        )
    devs, at = [], 0
    for i, length in enumerate(bits):
        devs.append(Device(index=i, file_start=at, length=length))
        at += length
    return tuple(devs)


@dataclass(frozen=True)
class Window:
    """A canonical (non-mirror) CPU window onto a contiguous file range."""

    bank_lo: int
    bank_hi: int
    addr_lo: int
    addr_hi: int
    file_start: int

    @property
    def bank_span(self) -> int:
        return self.bank_hi - self.bank_lo + 1

    @property
    def addr_span(self) -> int:
        return self.addr_hi - self.addr_lo + 1

    @property
    def length(self) -> int:
        return self.bank_span * self.addr_span

    @property
    def file_end(self) -> int:  # exclusive
        return self.file_start + self.length

    def cpu_of(self, off: int) -> tuple[int, int]:
        rel = off - self.file_start
        return self.bank_lo + rel // self.addr_span, self.addr_lo + rel % self.addr_span

    def __str__(self) -> str:
        return (
            f"${self.bank_lo:02X}-${self.bank_hi:02X}:{self.addr_lo:04X}-{self.addr_hi:04X}"
            f"  <- file ${self.file_start:06X}-${self.file_end - 1:06X}"
        )


@dataclass(frozen=True)
class DecodeCell:
    """One 32 KiB CPU view of cartridge ROM -- canonical OR mirror.

    `windows()` names the single blessed CPU address for each file byte; a
    DecodeCell is any address the decoder accepts, which is what a test that
    means to cover the whole decode has to enumerate."""

    bank: int
    addr_lo: int
    file_start: int
    canonical: bool

    @property
    def addr_hi(self) -> int:
        return self.addr_lo + 0x7FFF

    @property
    def far(self) -> int:
        """The 24-bit CPU address of this cell's first byte."""
        return self.bank << 16 | self.addr_lo

    @property
    def file_end(self) -> int:  # exclusive
        return self.file_start + 0x8000

    @property
    def key(self) -> tuple[int, int]:
        return self.bank, self.addr_lo

    def __str__(self) -> str:
        kind = "canonical" if self.canonical else "mirror   "
        return (f"${self.bank:02X}:{self.addr_lo:04X}-{self.addr_hi:04X}  {kind}"
                f"  <- file ${self.file_start:06X}-${self.file_end - 1:06X}")


class CartMap:
    """The address model for one concrete cartridge (mapping + exact length)."""

    def __init__(self, mapping: str, size: int, fast: bool = False,
                 speed: str | None = None):
        if mapping not in BOARDS:
            raise ValueError(f"unknown mapping {mapping!r}; expected one of {MAPPINGS}")
        if speed is not None:
            if speed not in SPEEDS:
                raise ValueError(f"unknown speed {speed!r}; expected one of {SPEEDS}")
            fast = speed == "fast"
        self.mapping = mapping
        self.size = size
        self.fast = fast
        self.board = BOARDS[mapping]
        self.devices = decompose(size)
        self._check_size_for_mapping()
        self._windows = tuple(self._build_windows())

    # ---- validity -------------------------------------------------------
    def _check_size_for_mapping(self) -> None:
        if self.mapping == "lorom" and self.size > 0x400000:
            raise ValueError(
                f"LoROM cannot address more than 4 MiB; got 0x{self.size:X}. "
                "Beyond that the cartridge needs the extended (ExHiROM) map."
            )
        if self.mapping == "hirom":
            if self.size > 0x400000:
                raise ValueError(
                    f"HiROM cannot address more than 4 MiB; got 0x{self.size:X}. "
                    "Beyond that the cartridge needs the extended (ExHiROM) map."
                )
            if self.size < 0x10000 or self.size % 0x10000:
                raise ValueError(
                    f"HiROM banks are a full 64 KiB; 0x{self.size:X} is not a whole "
                    "number of them"
                )
        if self.mapping == "exhirom":
            if self.size <= 0x400000:
                raise ValueError(
                    f"ExHiROM's boot region starts at file $400000; an image of "
                    f"0x{self.size:X} bytes has no header there. Use hirom."
                )
            if self.size > 0x800000:
                raise ValueError(
                    f"ExHiROM addresses at most 8 MiB; got 0x{self.size:X}."
                )

    @property
    def speed(self) -> str:
        """'slow' or 'fast' -- the cartridge bus speed the header advertises."""
        return "fast" if self.fast else "slow"

    @property
    def map_mode(self) -> int:
        """Header byte $FFD5, derived: mapping nibble OR the speed bit.  This is
        the ONE place the byte is composed; nothing else may OR in FAST_BIT."""
        return MAP_MODE[self.mapping] | (FAST_BIT if self.fast else 0x00)

    @staticmethod
    def speed_from_map_mode(byte: int) -> str:
        """The inverse of the speed half of `map_mode`, for reading a header."""
        return "fast" if byte & FAST_BIT else "slow"

    @property
    def header_file_offset(self) -> int:
        return HEADER_FILE_OFFSET[self.mapping]

    @property
    def logical_size(self) -> int:
        """The size the cartridge presents to the address decoder once the
        smaller device is mirrored across its slot.  A 4+2 MiB cartridge looks
        like 8 MiB, which is what the ROM-size header byte and the compound
        checksum both describe."""
        if len(self.devices) == 1:
            return self.size
        return self.devices[0].length * 2

    @property
    def rom_size_byte(self) -> int:
        """Header byte $FFD7: n such that 2^n KiB == the LOGICAL (mirrored)
        size.  6 MiB -> logical 8 MiB -> 8192 KiB -> 0x0D, which is what the
        48 Mbit commercial ExHiROM carts carry."""
        kib = self.logical_size // 1024
        n = kib.bit_length() - 1
        assert 1 << n == kib, f"logical size {kib} KiB is not a power of two"
        return n

    # ---- decode: emulator truth, mirrors included -----------------------
    def decode(self, bank: int, addr: int) -> Optional[int]:
        """CPU address -> file offset, or None if this address is not cartridge
        ROM.  Byte-for-byte the arithmetic bsnes-jg's `Bus::map` performs."""
        if not (0 <= bank <= 0xFF and 0 <= addr <= 0xFFFF):
            raise ValueError(f"address out of range: ${bank:02X}:{addr:04X}")
        if bank in WRAM_BANKS:
            return None  # WRAM is mapped over the cartridge
        full = bank << 16 | addr
        for bm in self.board:
            if not bm.covers(bank, addr):
                continue
            offset = bus_reduce(full, bm.mask)
            size = self.size
            base = bus_mirror(bm.base, size)
            return base + bus_mirror(offset, size - base)
        return None

    # ---- canonical windows ---------------------------------------------
    def _build_windows(self) -> Iterator[Window]:
        """The windows we are willing to put in a descriptor: for each file
        byte, exactly one CPU address, chosen to be the widest hole-free run.

        LoROM  : $00-$xx:8000-FFFF, 32 KiB per bank.
        HiROM  : $C0-$FF:0000-FFFF, full 64 KiB banks.
        ExHiROM: region A ($000000-$3FFFFF) through $C0-$FF, region B
                 ($400000+) through $40-$7D -- then, only for an 8 MiB image,
                 the tail past bank $7D through the $3E/$3F upper halves.
        """
        if self.mapping == "lorom":
            last = self.size // 0x8000 - 1  # last 32 KiB bank index
            # Bank indices $7E/$7F are WRAM, so a 4 MiB LoROM's top 64 KiB is
            # reachable only through the $80-$FF mirror of those two indices.
            yield Window(0x00, min(last, 0x7D), 0x8000, 0xFFFF, 0x000000)
            if last >= 0x7E:
                yield Window(0xFE, 0x80 | last, 0x8000, 0xFFFF, 0x7E * 0x8000)
            return
        if self.mapping == "hirom":
            banks = self.size // 0x10000
            yield Window(0xC0, 0xC0 + banks - 1, 0x0000, 0xFFFF, 0x000000)
            return
        # ExHiROM.
        yield Window(0xC0, 0xFF, 0x0000, 0xFFFF, 0x000000)  # region A, always 4 MiB
        tail = self.size - 0x400000
        full_banks = min(tail // 0x10000, 0x7E - 0x40)  # $40..$7D inclusive
        yield Window(0x40, 0x40 + full_banks - 1, 0x0000, 0xFFFF, 0x400000)
        rest = tail - full_banks * 0x10000
        if rest:
            # Past bank $7D the S-CPU hard-wires WRAM, so the last chunk is
            # only reachable through the $00-$3F upper-half mirrors, 32 KiB per
            # bank, and the low halves of those banks are unreachable holes.
            first = 0x40 + full_banks - 0x40  # == full_banks, the bank index within region B
            for i in range(rest // 0x10000):
                b = first + i
                yield Window(
                    b, b, 0x8000, 0xFFFF, 0x400000 + (full_banks + i) * 0x10000 + 0x8000
                )

    def windows(self) -> tuple[Window, ...]:
        return self._windows

    def file_to_cpu(self, off: int) -> tuple[int, int]:
        """Checked inverse: file offset -> the ONE canonical CPU address.

        Raises for an offset that no canonical window reaches (an addressing
        hole), rather than silently handing back a mirror."""
        if not 0 <= off < self.size:
            raise ValueError(f"file offset ${off:06X} outside a {self.size} byte image")
        for w in self._windows:
            if w.file_start <= off < w.file_end:
                bank, addr = w.cpu_of(off)
                back = self.decode(bank, addr)
                if back != off:
                    got = "not-ROM" if back is None else f"${back:06X}"
                    raise AssertionError(
                        f"model inconsistency: file ${off:06X} -> ${bank:02X}:{addr:04X} "
                        f"-> {got}"
                    )
                return bank, addr
        raise ValueError(
            f"file offset ${off:06X} is an addressing hole in {self.mapping} "
            f"0x{self.size:X}: no canonical CPU window reaches it"
        )

    def cpu_to_file(self, bank: int, addr: int) -> int:
        off = self.decode(bank, addr)
        if off is None:
            raise ValueError(f"${bank:02X}:{addr:04X} is not cartridge ROM")
        return off

    def physical(self, off: int) -> tuple[int, int]:
        """file offset -> (physical device index, offset within that device)."""
        for d in self.devices:
            if d.file_start <= off < d.file_end:
                return d.index, off - d.file_start
        raise ValueError(f"file offset ${off:06X} outside a {self.size} byte image")

    def describe(self, off: int) -> dict:
        """The plan's `file_offset -> {physical_rom, physical_offset, cpu_bank,
        cpu_address}` record, in one call."""
        dev, dev_off = self.physical(off)
        bank, addr = self.file_to_cpu(off)
        return {
            "file_offset": off,
            "physical_rom": dev,
            "physical_offset": dev_off,
            "cpu_bank": bank,
            "cpu_address": addr,
        }

    def holes(self) -> tuple[tuple[int, int], ...]:
        """File ranges no canonical window reaches, as (start, end-exclusive).

        For 8 MiB ExHiROM these are the two 32 KiB low halves of the $3E/$3F
        mirror banks -- file $7E0000-$7E7FFF and $7F0000-$7F7FFF -- because
        banks $7E/$7F are WRAM and the fallback window is upper-half only."""
        covered = sorted((w.file_start, w.file_end) for w in self._windows)
        out, at = [], 0
        for start, end in covered:
            if start > at:
                out.append((at, start))
            at = max(at, end)
        if at < self.size:
            out.append((at, self.size))
        return tuple(out)

    # ---- decode cells: every CPU view of ROM, mirrors included ----------
    #: Granularity of the decode-cell enumeration.  The board `map` lines only
    #: ever split a bank at $8000 (`address=...:0000-ffff` or `8000-ffff`), and
    #: `decompose` forces every device length to be a multiple of 32 KiB, so a
    #: 32 KiB cell is the finest unit at which `decode` can change slope.
    #: `decode_cells` asserts that, rather than assuming it.
    CELL = 0x8000

    def decode_cells(self) -> tuple["DecodeCell", ...]:
        """EVERY 32 KiB CPU view of cartridge ROM -- canonical and mirror alike.

        `windows()` answers "where may a descriptor point"; this answers "what
        can the decoder be asked to decode", which is the coverage denominator
        for a test that means to exercise the whole address decode rather than
        the one blessed path to each byte.  Derived entirely from `decode`, so
        a mirror the model knows about cannot be missed by an enumeration that
        forgot it.

        Cells are yielded in (bank, addr) order.  `canonical` is true for the
        one cell per file unit that `file_to_cpu` hands back.
        """
        canon = set()
        for w in self._windows:
            for off in range(w.file_start, w.file_end, self.CELL):
                canon.add(self.file_to_cpu(off))
        cells = []
        for bank in range(0x100):
            for addr in range(0x0000, 0x10000, self.CELL):
                start = self.decode(bank, addr)
                if start is None:
                    continue
                end = self.decode(bank, addr + self.CELL - 1)
                if end is None or end - start != self.CELL - 1:
                    raise AssertionError(
                        f"${bank:02X}:{addr:04X} does not decode to a contiguous "
                        f"{self.CELL}-byte run: first ${start:06X}, last "
                        + ("not-ROM" if end is None else f"${end:06X}")
                        + " -- the decode-cell granularity assumption is wrong "
                        "for this mapping/size"
                    )
                cells.append(
                    DecodeCell(bank=bank, addr_lo=addr, file_start=start,
                               canonical=(bank, addr) in canon)
                )
        got = {c.file_start for c in cells if c.canonical}
        want = {off for w in self._windows
                for off in range(w.file_start, w.file_end, self.CELL)}
        if got != want:
            raise AssertionError(
                f"decode_cells found {len(got)} canonical file units, windows() "
                f"describes {len(want)}"
            )
        return tuple(cells)

    def decode_regions(self) -> tuple[tuple[int, int, int, int, int, bool], ...]:
        """`decode_cells` merged into maximal runs, for human-readable reports.

        A run is (bank_lo, addr_lo, bank_hi, addr_hi, file_start, canonical);
        cells merge when they are adjacent in BOTH CPU and file order and agree
        on `canonical`, which is exactly when a reader may walk them with one
        incrementing 24-bit pointer."""
        out: list[list] = []
        for c in self.decode_cells():
            cpu = c.bank << 16 | c.addr_lo
            if out:
                b_lo, a_lo, b_hi, a_hi, fs, canon = out[-1]
                prev_end = (b_hi << 16 | a_hi) + 1
                if (cpu == prev_end and canon == c.canonical
                        and c.file_start == fs + (prev_end - (b_lo << 16 | a_lo))):
                    out[-1][2] = (cpu + self.CELL - 1) >> 16
                    out[-1][3] = (cpu + self.CELL - 1) & 0xFFFF
                    continue
            out.append([c.bank, c.addr_lo,
                        (cpu + self.CELL - 1) >> 16, (cpu + self.CELL - 1) & 0xFFFF,
                        c.file_start, c.canonical])
        return tuple(tuple(r) for r in out)

    def max_dma_span(self, off: int) -> int:
        """Bytes readable by one DMA command starting at `off`.

        The SNES DMA source address increments only its 16-bit half and does
        NOT carry into the bank byte, so a transfer stops at the end of the
        current 64 KiB A-bus bank -- and, separately, at the end of the
        canonical window."""
        bank, addr = self.file_to_cpu(off)
        for w in self._windows:
            if w.file_start <= off < w.file_end:
                return min(0x10000 - addr, w.file_end - off)
        raise ValueError(f"file offset ${off:06X} is an addressing hole")

    # ---- checksum -------------------------------------------------------
    def mirrored_image(self, data: bytes) -> bytes:
        """The logical, power-of-two image the address decoder sees: the large
        device once, then the small device repeated until it fills a slot the
        same size as the large one."""
        if len(data) != self.size:
            raise ValueError(f"expected {self.size} bytes, got {len(data)}")
        if len(self.devices) == 1:
            return data
        big, small = self.devices
        reps = big.length // small.length
        return data[: big.length] + data[big.length :] * reps

    def checksum(self, data: bytes) -> int:
        """Internal-header checksum over the mirrored logical image.

        Computed the definitional way -- materialise the mirrored image and sum
        it -- so it cannot silently disagree with `mirrored_image`.  The
        classic "sum(big) + k*sum(small)" shortcut is asserted against this in
        the host tests, not used here."""
        return sum(self.mirrored_image(data)) & 0xFFFF

    def checksum_by_formula(self, data: bytes) -> int:
        """The independent second implementation of the compound-size rule."""
        if len(self.devices) == 1:
            return sum(data) & 0xFFFF
        big, small = self.devices
        k = big.length // small.length
        return (sum(data[: big.length]) + k * sum(data[big.length :])) & 0xFFFF

    # ---- header detection (ported from heuristics.cpp) ------------------
    @staticmethod
    def score_header(data: bytes, address: int) -> int:
        """Port of `SuperFamicom::scoreHeader` (heuristics.cpp:982-1043)."""
        score = 0
        if len(data) < address + 0x50:
            return 0
        map_mode = data[address + 0x25] & ~FAST_BIT  # speed bit is not part of the mapping
        complement = data[address + 0x2C] | data[address + 0x2D] << 8
        checksum = data[address + 0x2E] | data[address + 0x2F] << 8
        reset = data[address + 0x4C] | data[address + 0x4D] << 8
        if reset < 0x8000:
            return 0
        opcode = data[(address & ~0x7FFF) | (reset & 0x7FFF)]
        if opcode in (0x78, 0x18, 0x38, 0x9C, 0x4C, 0x5C):
            score += 8
        if opcode in (0xC2, 0xE2, 0xAD, 0xAE, 0xAC, 0xAF, 0xA9, 0xA2, 0xA0, 0x20, 0x22):
            score += 4
        if opcode in (0x40, 0x60, 0x6B, 0xCD, 0xEC, 0xCC):
            score -= 4
        if opcode in (0x00, 0x02, 0xDB, 0x42, 0xFF):
            score -= 8
        if checksum + complement == 0xFFFF:
            score += 4
        if address == 0x7FB0 and map_mode == 0x20:
            score += 2
        if address == 0xFFB0 and map_mode == 0x21:
            score += 2
        return max(0, score)

    @classmethod
    def detect_header_address(cls, data: bytes) -> int:
        """Port of the `SuperFamicom::SuperFamicom` constructor's selection
        (heuristics.cpp:468-478).  Returns the file offset bsnes-jg will treat
        as the internal header -- i.e. which mapping it will pick."""
        lorom = cls.score_header(data, 0x007FB0)
        hirom = cls.score_header(data, 0x00FFB0)
        exlorom = cls.score_header(data, 0x407FB0)
        exhirom = cls.score_header(data, 0x40FFB0)
        if exlorom:
            exlorom += 4
        if exhirom:
            exhirom += 4
        if lorom >= hirom and lorom >= exlorom and lorom >= exhirom:
            return 0x007FB0
        if hirom >= exlorom and hirom >= exhirom:
            return 0x00FFB0
        if exlorom >= exhirom:
            return 0x407FB0
        return 0x40FFB0

    @classmethod
    def detect_scores(cls, data: bytes) -> dict[str, int]:
        s = {
            "lorom": cls.score_header(data, 0x007FB0),
            "hirom": cls.score_header(data, 0x00FFB0),
            "exlorom": cls.score_header(data, 0x407FB0),
            "exhirom": cls.score_header(data, 0x40FFB0),
        }
        if s["exlorom"]:
            s["exlorom"] += 4
        if s["exhirom"]:
            s["exhirom"] += 4
        return s

    # ---- reporting ------------------------------------------------------
    def summary(self) -> str:
        devs = " + ".join(
            f"{d.label} @ ${d.file_start:06X}" for d in self.devices
        )
        lines = [
            f"mapping           : {self.mapping} ({self.speed} ROM), "
            f"map mode ${self.map_mode:02X}",
            f"file length       : {self.size} bytes (0x{self.size:X}, "
            f"{self.size * 8 // 1024 // 1024} Mbit / {self.size // 1024 // 1024} MiB)",
            f"physical devices  : {devs}",
            f"logical (mirrored): 0x{self.logical_size:X} "
            f"({self.logical_size // 1024 // 1024} MiB) -> ROM-size byte "
            f"${self.rom_size_byte:02X}",
            f"header at file    : ${self.header_file_offset:06X}",
        ]
        lines.append("canonical windows :")
        for w in self._windows:
            lines.append(f"    {w}")
        h = self.holes()
        lines.append(f"addressing holes  : {'none' if not h else ''}")
        for start, end in h:
            lines.append(f"    ${start:06X}-${end - 1:06X}  ({end - start} bytes)")
        return "\n".join(lines)

    def truth_table(self) -> list[dict]:
        """Every window edge, each device boundary, and each 1 MiB divider --
        the rows the plan's file-offset/CPU-address table is made of."""
        marks = set()
        for w in self._windows:
            marks.update({w.file_start, w.file_end - 1})
            # first and last byte of the first and last bank in the window
            marks.add(w.file_start + w.addr_span - 1)
            marks.add(w.file_end - w.addr_span)
        for d in self.devices:
            marks.update({d.file_start, d.file_end - 1})
        for mb in range(0, self.size, 1 << 20):
            marks.add(mb)
        marks.add(self.header_file_offset)
        rows = []
        for off in sorted(m for m in marks if 0 <= m < self.size):
            try:
                rows.append(self.describe(off))
            except ValueError:
                rows.append({"file_offset": off, "hole": True})
        return rows


def parse_size(text: str) -> int:
    """`6M`, `6MiB`, `48Mbit`, `0x600000`, `6291456` all mean 6 MiB."""
    t = text.strip().lower().replace("_", "")
    m = re.fullmatch(r"(\d+(?:\.\d+)?)\s*(mbit|mb|mib|m|kib|kb|k|b)?", t)
    if t.startswith("0x"):
        return int(t, 16)
    if not m:
        raise argparse.ArgumentTypeError(f"unparsable size {text!r}")
    val, unit = float(m.group(1)), m.group(2) or "b"
    factor = {
        "mbit": 1024 * 1024 // 8,
        "mb": 1 << 20,
        "mib": 1 << 20,
        "m": 1 << 20,
        "kib": 1 << 10,
        "kb": 1 << 10,
        "k": 1 << 10,
        "b": 1,
    }[unit]
    out = val * factor
    if out != int(out):
        raise argparse.ArgumentTypeError(f"size {text!r} is not a whole number of bytes")
    return int(out)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="snes_cartmap.py",
        description="The authoritative SNES cartridge address model.",
    )
    ap.add_argument("--mapping", choices=MAPPINGS, required=True)
    ap.add_argument("--size", type=parse_size, required=True, help="e.g. 6M, 48Mbit, 0x600000")
    ap.add_argument("--speed", choices=SPEEDS, default="slow",
                    help="cartridge bus speed (default slow); sets map-mode bit 4")
    ap.add_argument("--fast", "--fastrom", dest="fast", action="store_true",
                    help="shorthand for --speed fast")
    ap.add_argument("--table", action="store_true", help="print the file/CPU truth table")
    ap.add_argument("--cells", action="store_true",
                    help="print every 32 KiB decode cell (canonical AND mirror)")
    ap.add_argument("--regions", action="store_true",
                    help="print the decode cells merged into maximal runs")
    ap.add_argument("--offset", type=lambda s: int(s, 0), help="describe one file offset")
    args = ap.parse_args(argv[1:])

    cm = CartMap(args.mapping, args.size,
                 speed="fast" if args.fast else args.speed)
    print(cm.summary())
    if args.offset is not None:
        d = cm.describe(args.offset)
        print(
            f"\nfile ${d['file_offset']:06X} -> ROM {d['physical_rom'] + 1} "
            f"+${d['physical_offset']:06X} = CPU ${d['cpu_bank']:02X}:{d['cpu_address']:04X}"
        )
    if args.cells or args.regions:
        cells = cm.decode_cells()
        ncan = sum(1 for c in cells if c.canonical)
        print(f"\ndecode cells      : {len(cells)} "
              f"({ncan} canonical + {len(cells) - ncan} mirror) "
              f"over {len({c.file_start for c in cells})} file units")
    if args.cells:
        for c in cells:
            print(f"    {c}")
    if args.regions:
        print("\ndecode regions (maximal runs):")
        for b_lo, a_lo, b_hi, a_hi, fs, canon in cm.decode_regions():
            n = ((b_hi << 16 | a_hi) - (b_lo << 16 | a_lo)) + 1
            print(f"    ${b_lo:02X}:{a_lo:04X}-${b_hi:02X}:{a_hi:04X}  "
                  f"{'canonical' if canon else 'mirror   '}  <- file ${fs:06X}"
                  f"-${fs + n - 1:06X}")
    if args.table:
        print("\nfile offset  device  dev offset  CPU address")
        for row in cm.truth_table():
            if row.get("hole"):
                print(f"  ${row['file_offset']:06X}    --      --          (addressing hole)")
            else:
                print(
                    f"  ${row['file_offset']:06X}    ROM {row['physical_rom'] + 1}   "
                    f"${row['physical_offset']:06X}     "
                    f"${row['cpu_bank']:02X}:{row['cpu_address']:04X}"
                )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
