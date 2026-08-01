#!/usr/bin/env python3
"""Pure-host unit tests for the authoritative cartridge address model.

These run BEFORE any linker script exists (plan Phase 0 step 5) and need no
toolchain, no emulator and no ROM: they are the contract every other consumer
of `tools/snes_cartmap.py` is checked against.

Run:  python3 test/snes/cartridge-maps/test_snes_cartmap.py
      python3 test/snes/cartridge-maps/test_snes_cartmap.py --exhaustive
"""
from __future__ import annotations

import os
import random
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from snes_cartmap import (  # noqa: E402
    BOARDS_BML,
    CartMap,
    Device,
    bus_mirror,
    bus_reduce,
    decompose,
    parse_size,
)

BOARDS_BML_PATH = os.path.join(ROOT, "vendor", "bsnes-jg", "Database", "boards.bml")
EXHAUSTIVE = "--exhaustive" in sys.argv


class TestProvenance(unittest.TestCase):
    """The model claims to BE bsnes-jg's decoder. Prove the transcription."""

    def test_board_definitions_match_vendored_boards_bml(self):
        """Every `map address=...` line we transcribed must appear verbatim
        under the matching `board:` entry in vendor/bsnes-jg.

        This is not ceremony: the LoROM entry was first transcribed from memory
        as two masked lines and is actually one `mask=0x8000` line. A vendor
        bump that changes a board definition must fail here, not in an
        emulator six hours later."""
        if not os.path.exists(BOARDS_BML_PATH):
            self.skipTest(f"vendored boards.bml absent at {BOARDS_BML_PATH}")
        with open(BOARDS_BML_PATH, encoding="utf-8") as f:
            text = f.read()
        want_board = {"lorom": "LOROM", "hirom": "HIROM", "exhirom": "EXHIROM"}
        for name, transcript in BOARDS_BML.items():
            marker = f"\nboard: {want_board[name]}\n  memory type=ROM content=Program\n"
            self.assertIn(marker, text, f"no `board: {want_board[name]}` ROM entry")
            block = text.split(marker, 1)[1]
            block = block.split("\n\n", 1)[0]
            got = "\n".join(
                l for l in block.splitlines() if l.strip().startswith("map address=")
            )
            self.assertEqual(
                got.strip(),
                transcript.strip(),
                f"{name}: transcription drifted from vendor/bsnes-jg/Database/boards.bml",
            )


class TestBusPrimitives(unittest.TestCase):
    def test_mirror_identity_below_size(self):
        for size in (0x8000, 0x400000, 0x600000):
            for a in (0, 1, size - 1):
                self.assertEqual(bus_mirror(a, size), a)

    def test_mirror_power_of_two_is_modulo(self):
        for a in (0x400000, 0x7FFFFF, 0xC00000, 0xFFFFFF):
            self.assertEqual(bus_mirror(a, 0x400000), a & 0x3FFFFF)

    def test_mirror_compound_size_folds_into_the_small_device(self):
        # A 2 MiB device in a 4 MiB slot: $200000 folds back to $000000.
        self.assertEqual(bus_mirror(0x200000, 0x200000), 0)
        self.assertEqual(bus_mirror(0x2FFFFF, 0x200000), 0x0FFFFF)

    def test_reduce_deletes_masked_bits(self):
        self.assertEqual(bus_reduce(0xC00000, 0xC00000), 0x000000)
        self.assertEqual(bus_reduce(0xFFFFFF, 0xC00000), 0x3FFFFF)
        self.assertEqual(bus_reduce(0x808000, 0xC00000), 0x008000)
        self.assertEqual(bus_reduce(0x008000, 0x8000), 0x000000)
        self.assertEqual(bus_reduce(0x018000, 0x8000), 0x008000)


class TestDecomposition(unittest.TestCase):
    def test_six_mib_is_four_plus_two(self):
        d = decompose(6 << 20)
        self.assertEqual(d, (Device(0, 0, 4 << 20), Device(1, 4 << 20, 2 << 20)))
        self.assertEqual([x.mbit for x in d], [32, 16])

    def test_five_mib_is_four_plus_one(self):
        d = decompose(5 << 20)
        self.assertEqual([x.length for x in d], [4 << 20, 1 << 20])

    def test_power_of_two_is_one_device(self):
        self.assertEqual(len(decompose(8 << 20)), 1)
        self.assertEqual(len(decompose(4 << 20)), 1)

    def test_reject_three_device_decomposition(self):
        # 7 MiB = 4 + 2 + 1: the plan's "invalid 4 MiB + non-power-of-two".
        with self.assertRaisesRegex(ValueError, "3 mask ROMs"):
            decompose(7 << 20)

    def test_reject_non_multiple_of_32k(self):
        with self.assertRaisesRegex(ValueError, "not a multiple of 32 KiB"):
            decompose((6 << 20) + 512)

    def test_reject_too_small(self):
        with self.assertRaisesRegex(ValueError, "too small"):
            decompose(0x4000)


class TestSizeParsing(unittest.TestCase):
    def test_equivalent_spellings(self):
        for s in ("6M", "6MiB", "48Mbit", "0x600000", "6291456"):
            self.assertEqual(parse_size(s), 6291456, s)


# --------------------------------------------------------------------------
# The truth tables. These literals are the specification: they are written out
# by hand from the board definitions, NOT generated from the code under test.
# --------------------------------------------------------------------------
class TestExHiROM6MiBTruthTable(unittest.TestCase):
    """48 Mbit ExHiROM, 4 MiB + 2 MiB -- the normative test cartridge."""

    def setUp(self):
        self.cm = CartMap("exhirom", 6 << 20)

    def test_size_and_devices(self):
        self.assertEqual(self.cm.size, 6291456)
        self.assertEqual([d.mbit for d in self.cm.devices], [32, 16])
        self.assertEqual(self.cm.logical_size, 8 << 20)
        self.assertEqual(self.cm.rom_size_byte, 0x0D)
        self.assertEqual(self.cm.map_mode, 0x25)
        self.assertEqual(self.cm.header_file_offset, 0x40FFB0)

    def test_file_to_cpu_truth_table(self):
        # (file offset, canonical CPU bank, CPU address, physical device)
        table = [
            (0x000000, 0xC0, 0x0000, 0),  # first byte of ROM 1
            (0x00FFFF, 0xC0, 0xFFFF, 0),  # last byte of bank $C0
            (0x010000, 0xC1, 0x0000, 0),  # cross into bank $C1
            (0x1FFFFF, 0xDF, 0xFFFF, 0),  # 2 MiB divider
            (0x200000, 0xE0, 0x0000, 0),
            (0x3FFFFF, 0xFF, 0xFFFF, 0),  # last byte of ROM 1 / of region A
            (0x400000, 0x40, 0x0000, 1),  # first byte of ROM 2 / of region B
            (0x407FFF, 0x40, 0x7FFF, 1),  # last byte of bank $40's low half
            (0x408000, 0x40, 0x8000, 1),  # start of the boot/near window
            (0x40FFB0, 0x40, 0xFFB0, 1),  # the internal header
            (0x40FFFC, 0x40, 0xFFFC, 1),  # the reset vector
            (0x40FFFF, 0x40, 0xFFFF, 1),
            (0x410000, 0x41, 0x0000, 1),
            (0x4FFFFF, 0x4F, 0xFFFF, 1),
            (0x500000, 0x50, 0x0000, 1),
            (0x5FFFFF, 0x5F, 0xFFFF, 1),  # last addressable byte of the image
        ]
        for off, bank, addr, dev in table:
            with self.subTest(off=hex(off)):
                self.assertEqual(
                    self.cm.file_to_cpu(off), (bank, addr), f"file ${off:06X} forward"
                )
                self.assertEqual(self.cm.cpu_to_file(bank, addr), off, "inverse")
                self.assertEqual(self.cm.physical(off)[0], dev, "physical device")

    def test_boot_bank_00_mirrors_bank_40_upper_half(self):
        """The 65816 fetches RESET from $00:FFFC with PBR=$00. In ExHiROM,
        banks $00-$3F upper halves are the SECOND region -- so the reset vector
        is read from file $40FFFC, not $00FFFC. This is the single fact that
        makes the ExHiROM boot layout different from HiROM's."""
        self.assertEqual(self.cm.decode(0x00, 0xFFFC), 0x40FFFC)
        self.assertEqual(self.cm.decode(0x00, 0xFFB0), 0x40FFB0)
        self.assertEqual(self.cm.decode(0x00, 0x8000), 0x408000)
        # ...and it is the same byte the canonical $40 window addresses.
        self.assertEqual(self.cm.decode(0x00, 0xFFFC), self.cm.decode(0x40, 0xFFFC))

    def test_bank_00_low_half_is_not_cartridge(self):
        for addr in (0x0000, 0x2000, 0x4200, 0x7FFF):
            self.assertIsNone(self.cm.decode(0x00, addr))

    def test_wram_banks_are_never_cartridge(self):
        for bank in (0x7E, 0x7F):
            for addr in (0x0000, 0x8000, 0xFFFF):
                self.assertIsNone(self.cm.decode(bank, addr))

    def test_known_mirrors_decode_to_the_same_byte(self):
        """Accepted mirrors. A descriptor must never name these, but a read
        through them must still land on the right byte -- and MIRROR_PROBE
        canaries rely on exactly this."""
        mirrors = [
            # region A: $80-$BF upper halves mirror $C0-$FF upper halves
            ((0x80, 0x8000), (0xC0, 0x8000)),
            ((0xBF, 0xFFFF), (0xFF, 0xFFFF)),
            # region B: $20-$3F upper halves mirror $00-$1F (2 MiB device in a 4 MiB slot)
            ((0x20, 0x8000), (0x00, 0x8000)),
            ((0x3F, 0xFFFF), (0x1F, 0xFFFF)),
            # region B: $60-$7D mirror $40-$5D
            ((0x60, 0x0000), (0x40, 0x0000)),
            ((0x7D, 0xFFFF), (0x5D, 0xFFFF)),
        ]
        for (mb, ma), (cb, ca) in mirrors:
            with self.subTest(mirror=f"${mb:02X}:{ma:04X}"):
                self.assertEqual(self.cm.decode(mb, ma), self.cm.decode(cb, ca))

    def test_canonical_windows(self):
        ws = self.cm.windows()
        self.assertEqual(len(ws), 2)
        self.assertEqual((ws[0].bank_lo, ws[0].bank_hi), (0xC0, 0xFF))
        self.assertEqual((ws[0].file_start, ws[0].file_end), (0x000000, 0x400000))
        self.assertEqual((ws[1].bank_lo, ws[1].bank_hi), (0x40, 0x5F))
        self.assertEqual((ws[1].file_start, ws[1].file_end), (0x400000, 0x600000))

    def test_no_addressing_holes(self):
        self.assertEqual(self.cm.holes(), ())

    def test_windows_cover_every_byte_exactly_once(self):
        total = sum(w.length for w in self.cm.windows())
        self.assertEqual(total, self.cm.size)

    def test_max_dma_span_stops_at_the_bank_edge(self):
        """The DMA source address increments only its 16-bit half; it does not
        carry into the bank byte."""
        self.assertEqual(self.cm.max_dma_span(0x000000), 0x10000)
        self.assertEqual(self.cm.max_dma_span(0x00FF00), 0x100)
        self.assertEqual(self.cm.max_dma_span(0x3FFF00), 0x100)
        # ...and at the physical device boundary, because the window changes.
        self.assertEqual(self.cm.max_dma_span(0x3F0000), 0x10000)
        self.assertEqual(self.cm.max_dma_span(0x400000), 0x10000)

    def test_describe_matches_the_plans_record_shape(self):
        d = self.cm.describe(0x400000)
        self.assertEqual(
            d,
            {
                "file_offset": 0x400000,
                "physical_rom": 1,
                "physical_offset": 0,
                "cpu_bank": 0x40,
                "cpu_address": 0x0000,
            },
        )


class TestExHiROM8MiBTruthTable(unittest.TestCase):
    """64 Mbit ExHiROM -- one 8 MiB device, and the WRAM-capped tail."""

    def setUp(self):
        self.cm = CartMap("exhirom", 8 << 20)

    def test_single_device_and_header(self):
        self.assertEqual([d.mbit for d in self.cm.devices], [64])
        self.assertEqual(self.cm.logical_size, 8 << 20)
        self.assertEqual(self.cm.rom_size_byte, 0x0D)

    def test_file_to_cpu_truth_table(self):
        table = [
            (0x000000, 0xC0, 0x0000),
            (0x3FFFFF, 0xFF, 0xFFFF),
            (0x400000, 0x40, 0x0000),
            (0x40FFB0, 0x40, 0xFFB0),
            (0x7DFFFF, 0x7D, 0xFFFF),  # last full bank before WRAM
            (0x7E8000, 0x3E, 0x8000),  # tail: only the upper-half mirror reaches it
            (0x7EFFFF, 0x3E, 0xFFFF),
            (0x7F8000, 0x3F, 0x8000),
            (0x7FFFFF, 0x3F, 0xFFFF),  # last byte of an 8 MiB image
        ]
        for off, bank, addr in table:
            with self.subTest(off=hex(off)):
                self.assertEqual(self.cm.file_to_cpu(off), (bank, addr))
                self.assertEqual(self.cm.cpu_to_file(bank, addr), off)

    def test_wram_capped_holes(self):
        """Banks $7E/$7F are WRAM, so 64 KiB of an 8 MiB ExHiROM image is
        physically present but unreachable. The model must SAY so rather than
        hand back a mirror -- a canary placed here would read as garbage."""
        self.assertEqual(self.cm.holes(), ((0x7E0000, 0x7E8000), (0x7F0000, 0x7F8000)))
        for off in (0x7E0000, 0x7E7FFF, 0x7F0000, 0x7F7FFF):
            with self.subTest(off=hex(off)):
                with self.assertRaisesRegex(ValueError, "addressing hole"):
                    self.cm.file_to_cpu(off)

    def test_hole_bytes_have_no_cpu_address_at_all(self):
        """Not merely 'not canonical' -- no CPU address decodes to them."""
        holes = set()
        for start, end in self.cm.holes():
            holes.update(range(start, end, 0x800))
        reachable = set()
        for bank in range(0x00, 0x100):
            for addr in (0x0000, 0x0800, 0x8000, 0x8800, 0xF800, 0xFFFF):
                off = self.cm.decode(bank, addr)
                if off is not None:
                    reachable.add(off)
        self.assertEqual(holes & reachable, set())


class TestHiROM4MiBTruthTable(unittest.TestCase):
    """The ordinary-map baseline the extended map builds on."""

    def setUp(self):
        self.cm = CartMap("hirom", 4 << 20)

    def test_header_and_size(self):
        self.assertEqual(self.cm.map_mode, 0x21)
        self.assertEqual(self.cm.header_file_offset, 0x00FFB0)
        self.assertEqual(self.cm.rom_size_byte, 0x0C)
        self.assertEqual(len(self.cm.devices), 1)

    def test_file_to_cpu_truth_table(self):
        table = [
            (0x000000, 0xC0, 0x0000),
            (0x008000, 0xC0, 0x8000),
            (0x00FFB0, 0xC0, 0xFFB0),
            (0x00FFFC, 0xC0, 0xFFFC),
            (0x010000, 0xC1, 0x0000),
            (0x3FFFFF, 0xFF, 0xFFFF),
        ]
        for off, bank, addr in table:
            with self.subTest(off=hex(off)):
                self.assertEqual(self.cm.file_to_cpu(off), (bank, addr))
                self.assertEqual(self.cm.cpu_to_file(bank, addr), off)

    def test_lorom_area_mirrors_are_upper_half_only(self):
        """$00:8000-$FFFF mirrors $C0:8000-$FFFF -- which is why the unchanged
        crt0 boots on HiROM. The low halves of $00-$3F are NOT cartridge, so
        half of every bank below $C0 is an addressing hole in the mirror view."""
        self.assertEqual(self.cm.decode(0x00, 0xFFFC), 0x00FFFC)
        self.assertEqual(self.cm.decode(0x00, 0x8000), 0x008000)
        self.assertIsNone(self.cm.decode(0x00, 0x7FFF))
        self.assertEqual(self.cm.decode(0x01, 0x8000), 0x018000)

    def test_no_holes_in_the_canonical_window(self):
        self.assertEqual(self.cm.holes(), ())
        (w,) = self.cm.windows()
        self.assertEqual((w.bank_lo, w.bank_hi), (0xC0, 0xFF))


class TestMappingLimits(unittest.TestCase):
    def test_hirom_rejects_more_than_4_mib(self):
        with self.assertRaisesRegex(ValueError, "cannot address more than 4 MiB"):
            CartMap("hirom", 6 << 20)

    def test_lorom_rejects_more_than_4_mib(self):
        with self.assertRaisesRegex(ValueError, "cannot address more than 4 MiB"):
            CartMap("lorom", 6 << 20)

    def test_exhirom_rejects_4_mib_or_less(self):
        with self.assertRaisesRegex(ValueError, "no header there"):
            CartMap("exhirom", 4 << 20)

    def test_exhirom_rejects_more_than_8_mib(self):
        with self.assertRaisesRegex(ValueError, "at most 8 MiB"):
            CartMap("exhirom", 12 << 20)

    def test_exhirom_rejects_seven_mib(self):
        with self.assertRaisesRegex(ValueError, "3 mask ROMs"):
            CartMap("exhirom", 7 << 20)

    def test_exhirom_5_mib_is_a_legal_stretch_fixture(self):
        cm = CartMap("exhirom", 5 << 20)
        self.assertEqual([d.mbit for d in cm.devices], [32, 8])
        self.assertEqual(cm.logical_size, 8 << 20)
        self.assertEqual(cm.rom_size_byte, 0x0D)
        self.assertEqual(cm.holes(), ())


class TestRoundTrip(unittest.TestCase):
    """file -> CPU -> file for every mapped byte, and CPU -> file -> canonical
    for every CPU address."""

    CASES = [("hirom", 4 << 20), ("exhirom", 5 << 20), ("exhirom", 6 << 20), ("exhirom", 8 << 20),
             ("lorom", 4 << 20), ("lorom", 512 << 10)]

    def test_file_to_cpu_round_trips(self):
        rng = random.Random(0x816)
        for mapping, size in self.CASES:
            cm = CartMap(mapping, size)
            holes = cm.holes()
            offs = set()
            for w in cm.windows():
                offs.update({w.file_start, w.file_start + 1, w.file_end - 1})
                for b in range(w.bank_lo, w.bank_hi + 1):
                    base = w.file_start + (b - w.bank_lo) * w.addr_span
                    offs.update({base, base + w.addr_span - 1})
            offs.update(rng.randrange(size) for _ in range(4000))
            for off in offs:
                if any(s <= off < e for s, e in holes):
                    continue
                with self.subTest(m=mapping, size=hex(size), off=hex(off)):
                    bank, addr = cm.file_to_cpu(off)
                    self.assertEqual(cm.cpu_to_file(bank, addr), off)

    def test_every_cpu_address_decodes_into_the_image(self):
        step = 1 if EXHAUSTIVE else 0x40
        for mapping, size in self.CASES:
            cm = CartMap(mapping, size)
            for bank in range(0x100):
                for addr in range(0, 0x10000, step):
                    off = cm.decode(bank, addr)
                    if off is None:
                        continue
                    self.assertTrue(
                        0 <= off < size,
                        f"{mapping} 0x{size:X}: ${bank:02X}:{addr:04X} -> ${off:06X} out of image",
                    )

    def test_canonical_window_is_a_fixed_point(self):
        """Decoding a canonical CPU address and re-deriving the canonical
        address for that offset must return the same CPU address -- i.e. the
        canonical window really is canonical, not itself a mirror."""
        for mapping, size in self.CASES:
            cm = CartMap(mapping, size)
            for w in cm.windows():
                probes = {w.file_start, w.file_end - 1,
                          min(w.file_start + w.addr_span, w.file_end - 1)}
                for off in probes:
                    bank, addr = cm.file_to_cpu(off)
                    self.assertEqual(cm.file_to_cpu(cm.cpu_to_file(bank, addr)), (bank, addr))


class TestChecksum(unittest.TestCase):
    def _image(self, size, seed):
        rng = random.Random(seed)
        return bytes(rng.randrange(256) for _ in range(size))

    def test_power_of_two_is_a_plain_sum(self):
        cm = CartMap("hirom", 4 << 20)
        data = self._image(4 << 20, 1)
        self.assertEqual(cm.checksum(data), sum(data) & 0xFFFF)

    def test_compound_size_mirrors_the_small_device(self):
        """6 MiB = 4 + 2: the 2 MiB device is mirrored twice to fill a 4 MiB
        slot, so the logical image is 8 MiB and the checksum is
        sum(big) + 2 * sum(small)."""
        cm = CartMap("exhirom", 6 << 20)
        data = self._image(6 << 20, 2)
        big, small = data[: 4 << 20], data[4 << 20 :]
        self.assertEqual(cm.checksum(data), (sum(big) + 2 * sum(small)) & 0xFFFF)

    def test_five_mib_mirrors_the_1_mib_device_four_times(self):
        cm = CartMap("exhirom", 5 << 20)
        data = self._image(5 << 20, 3)
        big, small = data[: 4 << 20], data[4 << 20 :]
        self.assertEqual(cm.checksum(data), (sum(big) + 4 * sum(small)) & 0xFFFF)

    def test_definitional_and_formula_implementations_agree(self):
        """`checksum` materialises the mirrored image and sums it; a separate
        implementation applies the classic multiplier rule. Two independent
        paths to the same number (plan verification gate 4)."""
        for mapping, size in (("hirom", 4 << 20), ("exhirom", 5 << 20),
                              ("exhirom", 6 << 20), ("exhirom", 8 << 20)):
            with self.subTest(m=mapping, size=hex(size)):
                cm = CartMap(mapping, size)
                data = self._image(size, size)
                self.assertEqual(cm.checksum(data), cm.checksum_by_formula(data))

    def test_mirrored_image_length_equals_logical_size(self):
        for mapping, size in (("exhirom", 5 << 20), ("exhirom", 6 << 20)):
            cm = CartMap(mapping, size)
            self.assertEqual(len(cm.mirrored_image(self._image(size, 7))), cm.logical_size)

    def test_mirrored_image_agrees_with_the_bus_decode(self):
        """The checksum's mirroring model and the ADDRESS DECODER's mirroring
        model must be the same claim. For each byte of the mirrored logical
        image that a CPU window actually reaches, the byte read through the bus
        must equal the byte at that logical position."""
        cm = CartMap("exhirom", 6 << 20)
        data = self._image(6 << 20, 11)
        # $20-$3F upper halves are the mirrored copy of the 2 MiB device;
        # logical position = 4 MiB + (mirror index) within the 4 MiB slot.
        for bank, addr in ((0x20, 0x8000), (0x2F, 0xC000), (0x3F, 0xFFFF)):
            off = cm.decode(bank, addr)
            logical = 0x400000 + ((bank << 16 | addr) - 0x000000)
            self.assertEqual(data[off], cm.mirrored_image(data)[logical])


class TestHeaderDetection(unittest.TestCase):
    """Ported bsnes-jg heuristics: prove a generated image is DETECTED as the
    mapping we intended, not merely accepted."""

    def _exhirom_image(self, reset_opcode=0x78):
        cm = CartMap("exhirom", 6 << 20)
        data = bytearray(6 << 20)
        h = cm.header_file_offset
        data[h : h + 21] = b"EXHIROM CANARY 6MIB  "
        data[h + 0x25] = cm.map_mode
        data[h + 0x27] = cm.rom_size_byte
        data[h + 0x4C] = 0x00  # reset vector $8000
        data[h + 0x4D] = 0x80
        data[0x408000] = reset_opcode
        csum = cm.checksum(bytes(data))
        data[h + 0x2C] = (~csum) & 0xFF
        data[h + 0x2D] = ((~csum) >> 8) & 0xFF
        data[h + 0x2E] = csum & 0xFF
        data[h + 0x2F] = (csum >> 8) & 0xFF
        return cm, bytes(data)

    def test_exhirom_image_is_detected_as_exhirom(self):
        cm, data = self._exhirom_image()
        self.assertEqual(CartMap.detect_header_address(data), 0x40FFB0)
        self.assertEqual(CartMap.detect_header_address(data), cm.header_file_offset)

    def test_exhirom_beats_the_other_three_candidates(self):
        _, data = self._exhirom_image()
        s = CartMap.detect_scores(data)
        self.assertGreater(s["exhirom"], s["lorom"])
        self.assertGreater(s["exhirom"], s["hirom"])
        self.assertGreater(s["exhirom"], s["exlorom"])

    def test_a_zero_filled_image_scores_nothing(self):
        """Padding must not accidentally look like a header. A zero reset
        vector is below $8000, which bsnes rejects outright."""
        data = bytes(6 << 20)
        self.assertEqual(CartMap.detect_scores(data), {"lorom": 0, "hirom": 0,
                                                       "exlorom": 0, "exhirom": 0})

    def test_an_ff_filled_image_scores_nothing(self):
        data = b"\xff" * (6 << 20)
        for k, v in CartMap.detect_scores(data).items():
            self.assertEqual(v, 0, k)

    def test_negative_wrong_header_location(self):
        """A 6 MiB image carrying a plausible header at the LoROM offset and
        nothing at $40FFB0 must NOT be detected as ExHiROM."""
        cm = CartMap("exhirom", 6 << 20)
        data = bytearray(6 << 20)
        data[0x7FB0 + 0x25] = 0x20
        data[0x7FB0 + 0x4C] = 0x00
        data[0x7FB0 + 0x4D] = 0x80
        data[0x0000] = 0x78
        self.assertNotEqual(CartMap.detect_header_address(bytes(data)), 0x40FFB0)
        self.assertEqual(CartMap.detect_header_address(bytes(data)), 0x007FB0)
        del cm

    def test_negative_wrong_mode_byte_still_detects_by_location(self):
        """bsnes falls back to the header ADDRESS when the mode byte is
        implausible, so a wrong $FFD5 does not by itself break detection --
        which is precisely why the checksum tool must police the mode byte
        rather than trusting the emulator to notice."""
        cm, data = self._exhirom_image()
        bad = bytearray(data)
        bad[cm.header_file_offset + 0x25] = 0x20  # claim LoROM
        self.assertEqual(CartMap.detect_header_address(bytes(bad)), 0x40FFB0)

    def test_negative_bad_reset_opcode_loses_the_score(self):
        _, good = self._exhirom_image(reset_opcode=0x78)
        _, bad = self._exhirom_image(reset_opcode=0xDB)  # stp
        self.assertGreater(
            CartMap.detect_scores(good)["exhirom"], CartMap.detect_scores(bad)["exhirom"]
        )


class TestDecodeCells(unittest.TestCase):
    """`decode_cells` is the coverage DENOMINATOR for the seamdemo cartridge
    (docs/plans/2026-08-01-exhirom-three-act-synthesis-cart.md): a test that
    means to exercise the whole address decode has to enumerate every CPU view
    of ROM, not just the one blessed window per byte.  If this enumeration is
    wrong the coverage assertion is vacuous, so it is checked against `decode`
    itself rather than against a written-down list."""

    CASES = (("exhirom", 0x600000), ("exhirom", 0x800000),
             ("hirom", 0x400000), ("hirom", 0x10000), ("lorom", 0x400000))

    def test_cells_partition_the_decoding_address_space(self):
        """Every CPU address that decodes to ROM belongs to exactly one cell,
        and its offset is that cell's start plus the in-cell displacement."""
        for mapping, size in self.CASES:
            with self.subTest(mapping=mapping, size=hex(size)):
                cm = CartMap(mapping, size)
                index = {c.key: c for c in cm.decode_cells()}
                step = 1 if EXHAUSTIVE else 0x111
                for bank in range(0x100):
                    for addr in range(0, 0x10000, step):
                        off = cm.decode(bank, addr)
                        key = (bank, addr & 0x8000)
                        if off is None:
                            self.assertNotIn(key, index,
                                             f"${bank:02X}:{addr:04X} decodes to nothing "
                                             "but its cell exists")
                            continue
                        self.assertIn(key, index,
                                      f"${bank:02X}:{addr:04X} decodes to ${off:06X} "
                                      "but no cell covers it")
                        self.assertEqual(off, index[key].file_start + (addr & 0x7FFF))

    def test_canonical_cells_are_exactly_the_windows(self):
        for mapping, size in self.CASES:
            with self.subTest(mapping=mapping, size=hex(size)):
                cm = CartMap(mapping, size)
                got = sorted(c.file_start for c in cm.decode_cells() if c.canonical)
                want = sorted(off for w in cm.windows()
                              for off in range(w.file_start, w.file_end, cm.CELL))
                self.assertEqual(got, want)
                # ... and each one is the address `file_to_cpu` hands back.
                for c in cm.decode_cells():
                    if c.canonical:
                        self.assertEqual(cm.file_to_cpu(c.file_start), c.key)

    def test_every_cell_lies_inside_the_image(self):
        for mapping, size in self.CASES:
            with self.subTest(mapping=mapping, size=hex(size)):
                cm = CartMap(mapping, size)
                for c in cm.decode_cells():
                    self.assertGreaterEqual(c.file_start, 0)
                    self.assertLessEqual(c.file_end, cm.size)

    def test_regions_reexpand_to_cells(self):
        """The merged view is a presentation of the same facts, not new ones."""
        for mapping, size in self.CASES:
            with self.subTest(mapping=mapping, size=hex(size)):
                cm = CartMap(mapping, size)
                rebuilt = []
                for b_lo, a_lo, b_hi, a_hi, fs, canon in cm.decode_regions():
                    lo, hi = (b_lo << 16 | a_lo), (b_hi << 16 | a_hi)
                    for k, cpu in enumerate(range(lo, hi + 1, cm.CELL)):
                        rebuilt.append(((cpu >> 16) & 0xFF, cpu & 0xFFFF,
                                        fs + k * cm.CELL, canon))
                self.assertEqual(
                    rebuilt,
                    [(c.bank, c.addr_lo, c.file_start, c.canonical)
                     for c in cm.decode_cells()])

    def test_exhirom_6mib_shape(self):
        """The seamdemo cartridge's exact numbers, pinned.

        380 = 64 upper halves in $00-$3F + 124 in $40-$7D (banks $7E/$7F are
        WRAM) + 64 in $80-$BF + 128 in $C0-$FF; 192 of them are canonical (the
        6 MiB image is 192 units of 32 KiB) and the other 188 are mirrors."""
        cm = CartMap("exhirom", 0x600000)
        cells = cm.decode_cells()
        self.assertEqual(len(cells), 380)
        self.assertEqual(sum(1 for c in cells if c.canonical), 192)
        self.assertEqual(sum(1 for c in cells if not c.canonical), 188)
        self.assertEqual(len({c.file_start for c in cells}), 192)
        # The four aliases of the linked-code unit are the ones a payload
        # generator has to leave alone.
        code = [c for c in cells if c.file_start == 0x408000]
        self.assertEqual(sorted(c.key for c in code),
                         [(0x00, 0x8000), (0x20, 0x8000), (0x40, 0x8000), (0x60, 0x8000)])


if __name__ == "__main__":
    sys.argv = [a for a in sys.argv if a != "--exhaustive"]
    unittest.main(verbosity=2)
