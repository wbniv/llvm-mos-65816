#!/usr/bin/env python3
"""Golden fixtures for tools/snes-checksum.py.

Positive: 4 MiB ordinary HiROM, and 5/6/8 MiB ExHiROM.
Negative: 4 MiB + non-power-of-two, wrong header location, wrong mode byte,
incorrect mirror/checksum, a copier-headered image, and a recognised-but-
unsupported coprocessor cartridge.

The checksum values below are LITERALS recorded from a deterministic synthetic
image, so a change to the mirroring rule breaks the test instead of silently
recomputing a new "expected" value.

Run:  python3 test/snes/cartridge-maps/test_snes_checksum.py
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
TOOL = os.path.join(ROOT, "tools", "snes-checksum.py")
sys.path.insert(0, os.path.join(ROOT, "tools"))

from snes_cartmap import CartMap  # noqa: E402


def filler(size: int, seed: int) -> bytearray:
    """Deterministic, cheap, and NOT constant -- a constant fill would hide a
    mirroring bug (any multiplier gives the same total)."""
    out = bytearray(size)
    x = seed & 0xFFFF
    for i in range(0, size, 4096):
        x = (x * 1103515245 + 12345) & 0xFFFF
        out[i : i + 4096] = bytes(((x + j) & 0xFF) for j in range(min(4096, size - i)))
    return out


def build_image(mapping: str, size: int, seed: int = 1) -> bytearray:
    """A structurally valid, unpatched image: title, vectors, one real opcode
    at the reset target. Checksum/mode/size bytes are left for the tool."""
    cm = CartMap(mapping, size)
    rom = filler(size, seed)
    base = cm.header_file_offset
    rom[base : base + 0x50] = bytes(0x50)
    rom[base + 0x10 : base + 0x25] = b"CARTRIDGE SIZE TEST  "
    rom[base + 0x25] = 0x00  # map mode: left wrong on purpose; the tool owns it
    rom[base + 0x26] = 0x00  # cartridge type: ROM only
    rom[base + 0x27] = 0x00  # ROM size: left wrong on purpose
    rom[base + 0x29] = 0x01  # NTSC
    rom[base + 0x4C] = 0x00  # reset vector $8000
    rom[base + 0x4D] = 0x80
    # native + emulation NMI/IRQ into the near window
    for off in (0x3A, 0x3E, 0x4A, 0x4E):
        rom[base + off] = 0x10
        rom[base + off + 1] = 0x80
    rom[cm.cpu_to_file(0x00, 0x8000)] = 0x78  # sei -- a "most likely" reset opcode
    return rom


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, TOOL, *args], capture_output=True, text=True
    )


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def write(self, name: str, data: bytes) -> str:
        p = os.path.join(self.tmp.name, name)
        with open(p, "wb") as f:
            f.write(data)
        return p


class TestPositiveFixtures(Fixture):
    #: (mapping, size, expected checksum, expected map-mode byte, expected ROM-size byte)
    GOLDEN = [
        # Each value was cross-checked against a longhand recomputation written
        # independently of the model: sum(all) for a single device, and
        # sum(big) + k*sum(small) for 4+1 (k=4) and 4+2 (k=2).
        ("hirom", 4 << 20, 0xF3CE, 0x21, 0x0C),
        ("exhirom", 5 << 20, 0xCF4C, 0x25, 0x0D),
        ("exhirom", 6 << 20, 0xE7A6, 0x25, 0x0D),
        ("exhirom", 8 << 20, 0xF3D3, 0x25, 0x0D),
    ]

    def test_golden(self):
        for mapping, size, csum, mode, szbyte in self.GOLDEN:
            with self.subTest(m=mapping, size=hex(size)):
                cm = CartMap(mapping, size)
                p = self.write(f"{mapping}-{size}.sfc", build_image(mapping, size))
                r = run(f"--mapping", mapping, p)
                self.assertEqual(r.returncode, 0, r.stderr)
                with open(p, "rb") as f:
                    out = f.read()
                base = cm.header_file_offset
                got = out[base + 0x2E] | out[base + 0x2F] << 8
                self.assertEqual(got, csum, f"checksum drifted: got ${got:04X}")
                self.assertEqual(out[base + 0x25], mode, "map mode byte")
                self.assertEqual(out[base + 0x27], szbyte, "ROM-size byte")
                # complement is the ones' complement, and the pair is self-consistent
                comp = out[base + 0x2C] | out[base + 0x2D] << 8
                self.assertEqual(comp, csum ^ 0xFFFF)
                # ...and the patched image now passes its own inspection.
                i = run("--inspect", "--mapping", mapping, p)
                self.assertEqual(i.returncode, 0, i.stdout + i.stderr)
                self.assertIn("PASS", i.stdout)

    def test_patch_is_idempotent(self):
        p = self.write("6m.sfc", build_image("exhirom", 6 << 20))
        run("--mapping", "exhirom", p)
        with open(p, "rb") as f:
            once = f.read()
        run("--mapping", "exhirom", p)
        with open(p, "rb") as f:
            twice = f.read()
        self.assertEqual(once, twice)

    def test_inspect_does_not_modify(self):
        p = self.write("6m.sfc", build_image("exhirom", 6 << 20))
        run("--mapping", "exhirom", p)
        with open(p, "rb") as f:
            before = f.read()
        run("--inspect", "--mapping", "exhirom", p)
        with open(p, "rb") as f:
            self.assertEqual(f.read(), before)

    def test_inspect_reports_the_physical_decomposition(self):
        p = self.write("6m.sfc", build_image("exhirom", 6 << 20))
        run("--mapping", "exhirom", p)
        r = run("--inspect", "--mapping", "exhirom", p)
        self.assertIn("32Mbit @ $000000 + 16Mbit @ $400000", r.stdout)
        self.assertIn("6291456 bytes", r.stdout)
        self.assertIn("$40FFB0", r.stdout)
        self.assertIn("$25", r.stdout)

    def test_inspect_autodetects_the_mapping(self):
        """No --mapping: the tool must reach the same verdict bsnes-jg will."""
        p = self.write("6m.sfc", build_image("exhirom", 6 << 20))
        run("--mapping", "exhirom", p)
        r = run("--inspect", p)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("detects exhirom", r.stdout)

    def test_mirroring_actually_matters(self):
        """A byte in the SMALL device must move the checksum by its multiplier,
        not by one. This is the test that fails if the mirroring is dropped."""
        cm = CartMap("exhirom", 6 << 20)
        a = build_image("exhirom", 6 << 20)
        b = bytearray(a)
        b[0x500000] = (b[0x500000] + 1) & 0xFF
        # the small device is mirrored x2, so +1 there is +2 on the checksum
        self.assertEqual(
            (cm.checksum(bytes(b)) - cm.checksum(bytes(a))) & 0xFFFF, 2
        )
        c = bytearray(a)
        c[0x100000] = (c[0x100000] + 1) & 0xFF  # big device: counted once
        self.assertEqual(
            (cm.checksum(bytes(c)) - cm.checksum(bytes(a))) & 0xFFFF, 1
        )


class TestNegativeFixtures(Fixture):
    def test_reject_4_mib_plus_non_power_of_two(self):
        """7 MiB = 4 + 2 + 1 needs three mask ROMs: not a buildable cartridge."""
        p = self.write("7m.sfc", bytes(7 << 20))
        r = run("--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("3 mask ROMs", r.stderr)

    def test_reject_size_that_is_not_a_multiple_of_32k(self):
        p = self.write("odd.sfc", bytes((6 << 20) + 0x4000))
        r = run("--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("not a multiple of 32 KiB", r.stderr)

    def test_reject_exhirom_below_4_mib(self):
        p = self.write("small.sfc", bytes(2 << 20))
        r = run("--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("no header there", r.stderr)

    def test_reject_hirom_above_4_mib(self):
        p = self.write("big.sfc", bytes(6 << 20))
        r = run("--mapping", "hirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("cannot address more than 4 MiB", r.stderr)

    def test_reject_copier_header(self):
        """A 512-byte copier header must never contaminate cartridge offsets."""
        p = self.write("copier.sfc", bytes(512) + bytes(build_image("exhirom", 6 << 20)))
        r = run("--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("copier header", r.stderr)

    def test_inspect_fails_on_wrong_header_location(self):
        """A 6 MiB image whose header sits at the LoROM offset is not an
        ExHiROM cartridge, however well-formed that header is."""
        rom = filler(6 << 20, 5)
        base = 0x7FB0
        rom[base : base + 0x50] = bytes(0x50)
        rom[base + 0x10 : base + 0x25] = b"WRONG HEADER PLACE   "
        rom[base + 0x25] = 0x25
        rom[base + 0x4C], rom[base + 0x4D] = 0x00, 0x80
        rom[0x40FFB0 : 0x410000] = bytes(0x50)
        p = self.write("wrongloc.sfc", bytes(rom))
        r = run("--inspect", "--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("FAIL", r.stdout)

    def test_inspect_fails_on_wrong_mode_byte(self):
        p = self.write("6m.sfc", build_image("exhirom", 6 << 20))
        run("--mapping", "exhirom", p)
        with open(p, "r+b") as f:
            f.seek(0x40FFB0 + 0x25)
            f.write(b"\x21")  # claim ordinary HiROM
        r = run("--inspect", "--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("map mode byte $21 != $25", r.stdout)

    def test_inspect_fails_on_wrong_rom_size_byte(self):
        p = self.write("6m.sfc", build_image("exhirom", 6 << 20))
        run("--mapping", "exhirom", p)
        with open(p, "r+b") as f:
            f.seek(0x40FFB0 + 0x27)
            f.write(b"\x0c")  # claim 4 MiB logical
        r = run("--inspect", "--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("ROM-size byte $0C != $0D", r.stdout)

    def test_inspect_fails_on_incorrect_mirrored_checksum(self):
        """The exact failure a naive 'sum every byte once' implementation
        produces on a 4+2 MiB image."""
        cm = CartMap("exhirom", 6 << 20)
        rom = build_image("exhirom", 6 << 20)
        base = cm.header_file_offset
        rom[base + 0x25] = cm.map_mode
        rom[base + 0x27] = cm.rom_size_byte
        rom[base + 0x2C : base + 0x2E] = b"\xff\xff"
        rom[base + 0x2E : base + 0x30] = b"\x00\x00"
        naive = sum(rom) & 0xFFFF  # <-- the bug: no mirroring
        rom[base + 0x2C] = (naive ^ 0xFFFF) & 0xFF
        rom[base + 0x2D] = (naive ^ 0xFFFF) >> 8
        rom[base + 0x2E] = naive & 0xFF
        rom[base + 0x2F] = naive >> 8
        p = self.write("naive.sfc", bytes(rom))
        r = run("--inspect", "--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("checksum", r.stdout)
        self.assertNotEqual(naive, cm.checksum(bytes(rom)))

    def test_inspect_fails_on_a_reset_vector_into_padding(self):
        cm = CartMap("exhirom", 6 << 20)
        rom = build_image("exhirom", 6 << 20)
        rom[cm.cpu_to_file(0x00, 0x8000)] = 0xFF  # padding, not code
        p = self.write("nopc.sfc", bytes(rom))
        run("--mapping", "exhirom", p)
        r = run("--inspect", "--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("padding, not linked executable code", r.stdout)

    def test_inspect_fails_on_a_reset_vector_below_8000(self):
        cm = CartMap("exhirom", 6 << 20)
        rom = build_image("exhirom", 6 << 20)
        rom[cm.header_file_offset + 0x4C] = 0x00
        rom[cm.header_file_offset + 0x4D] = 0x10
        p = self.write("lowvec.sfc", bytes(rom))
        run("--mapping", "exhirom", p)
        r = run("--inspect", "--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("below $8000", r.stdout)

    def test_inspect_fails_on_a_non_ascii_title(self):
        cm = CartMap("exhirom", 6 << 20)
        rom = build_image("exhirom", 6 << 20)
        rom[cm.header_file_offset + 0x10] = 0x01
        p = self.write("badtitle.sfc", bytes(rom))
        run("--mapping", "exhirom", p)
        r = run("--inspect", "--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("printable ASCII", r.stdout)

    def test_recognises_but_refuses_unsupported_coprocessor_cartridges(self):
        """One negative fixture per known unsupported family: the tool must NAME
        the chip and fail, not emit a plausible-looking ROM."""
        cases = [(0x26, 0x13, "SuperFX"), (0x26, 0x32, "SA-1"),
                 (0x26, 0x43, "S-DD1"), (0x26, 0xF3, "Cx4"),
                 (0x26, 0xE5, "BS-X"), (0x26, 0xE3, "Super Game Boy"),
                 (0x26, 0xF6, "ST010"), (0x26, 0x55, "S-RTC")]
        cm = CartMap("exhirom", 6 << 20)
        for off, val, name in cases:
            with self.subTest(chip=name):
                rom = build_image("exhirom", 6 << 20)
                rom[cm.header_file_offset + off] = val
                p = self.write(f"cop{val:02x}.sfc", bytes(rom))
                run("--mapping", "exhirom", p)
                r = run("--inspect", "--mapping", "exhirom", p)
                self.assertEqual(r.returncode, 1, r.stdout)
                self.assertIn(name, r.stdout)
                self.assertIn("out of scope for this mapper suite", r.stdout)

    def test_unsupported_map_modes_are_named(self):
        cm = CartMap("exhirom", 6 << 20)
        for mode, name in ((0x23, "SA-1"), (0x22, "S-DD1"), (0x2A, "SPC7110")):
            with self.subTest(mode=hex(mode)):
                rom = build_image("exhirom", 6 << 20)
                p = self.write(f"m{mode:02x}.sfc", bytes(rom))
                run("--mapping", "exhirom", p)
                with open(p, "r+b") as f:
                    f.seek(cm.header_file_offset + 0x25)
                    f.write(bytes([mode]))
                r = run("--inspect", "--mapping", "exhirom", p)
                self.assertEqual(r.returncode, 1)
                self.assertIn(name, r.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
