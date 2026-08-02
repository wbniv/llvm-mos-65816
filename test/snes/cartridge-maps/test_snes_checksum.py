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

from snes_cartmap import (  # noqa: E402
    CART_TYPE_ROM_RAM,
    CART_TYPE_ROM_RAM_BATTERY,
    OFF_CART_TYPE,
    OFF_CHECKSUM,
    OFF_COMPLEMENT,
    OFF_MAP_MODE,
    OFF_RAM_SIZE,
    OFF_REGION,
    OFF_ROM_SIZE,
    REGION_BYTE,
    CartMap,
    video_standard_from_region_byte,
)


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

    def test_reject_lorom_copier_header(self):
        """Same fixture, LoROM: the copier-header rejection is mapping-agnostic
        (checked before any mapping-specific address math even runs), but had
        never actually been exercised on LoROM input until this row existed."""
        p = self.write("lorom-copier.sfc", bytes(512) + bytes(build_image("lorom", 1 << 20)))
        r = run("--mapping", "lorom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("copier header", r.stderr)

    def test_reject_lorom_above_4_mib(self):
        p = self.write("lorom-big.sfc", bytes(6 << 20))
        r = run("--mapping", "lorom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("cannot address more than 4 MiB", r.stderr)

    def test_reject_lorom_truncated_image(self):
        """A LoROM image cut mid-bank -- not a whole multiple of 32 KiB -- is
        not a buildable mask ROM, whatever its content."""
        p = self.write("lorom-truncated.sfc", bytes((1 << 20) - 0x100))
        r = run("--mapping", "lorom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("not a multiple of 32 KiB", r.stderr)

    def test_reject_hirom_truncated_image(self):
        """HiROM banks are a full 64 KiB; an image that is a whole number of
        32 KiB units but NOT of 64 KiB ones is still not buildable."""
        p = self.write("hirom-truncated.sfc", bytes((2 << 20) + 0x8000))
        r = run("--mapping", "hirom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("not a whole number of them", r.stderr)

    def test_reject_lorom_ambiguous_three_device_decomposition(self):
        """3.5 MiB (2 + 1 + 0.5 MiB) fits under LoROM's 4 MiB ceiling but
        decomposes into three mask ROMs -- an ambiguously padded image the
        size alone cannot resolve into a buildable two-chip cartridge."""
        p = self.write("lorom-3.5m.sfc", bytes((2 << 20) + (1 << 20) + (512 << 10)))
        r = run("--mapping", "lorom", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("3 mask ROMs", r.stderr)

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


def legacy_patch(rom: bytearray, hirom: bool, fastrom: bool) -> bytearray:
    """The pre-rewrite tools/snes-checksum.py, transcribed verbatim from main's
    `5038454` version. It is the compatibility oracle for `--fastrom`: the
    rewritten tool must reproduce it byte-for-byte on every image the old one
    accepted, or main's SVX2 FastROM ROMs silently change."""
    rom = bytearray(rom)
    base = 0xFFB0 if hirom else 0x7FB0
    MAPMODE_OFF, ROMSIZE_OFF = base + 0x25, base + 0x27
    COMPLEMENT_OFF, CHECKSUM_OFF = base + 0x2C, base + 0x2E
    size_kib = len(rom) // 1024
    rom[ROMSIZE_OFF] = size_kib.bit_length() - 1
    rom[MAPMODE_OFF] = 0x21 if hirom else 0x20
    if fastrom:
        rom[MAPMODE_OFF] |= 0x10
    rom[COMPLEMENT_OFF:COMPLEMENT_OFF + 2] = b"\xff\xff"
    rom[CHECKSUM_OFF:CHECKSUM_OFF + 2] = b"\x00\x00"
    checksum = sum(rom) & 0xFFFF
    complement = checksum ^ 0xFFFF
    rom[COMPLEMENT_OFF] = complement & 0xFF
    rom[COMPLEMENT_OFF + 1] = complement >> 8
    rom[CHECKSUM_OFF] = checksum & 0xFF
    rom[CHECKSUM_OFF + 1] = checksum >> 8
    return rom


class TestSpeed(Fixture):
    """Cartridge bus speed is a model attribute; the map-mode byte derives from
    it. Guards the `--fastrom` contract main's video ROMs are built against."""

    def test_model_derives_the_map_mode_byte(self):
        for mapping, size, slow, fast in (
            ("lorom", 1 << 20, 0x20, 0x30),
            ("hirom", 4 << 20, 0x21, 0x31),
            ("exhirom", 6 << 20, 0x25, 0x35),
        ):
            with self.subTest(m=mapping):
                self.assertEqual(CartMap(mapping, size).map_mode, slow)
                self.assertEqual(CartMap(mapping, size).speed, "slow")
                self.assertEqual(CartMap(mapping, size, fast=True).map_mode, fast)
                self.assertEqual(CartMap(mapping, size, speed="fast").map_mode, fast)
                self.assertEqual(CartMap(mapping, size, speed="fast").speed, "fast")
                self.assertEqual(CartMap.speed_from_map_mode(fast), "fast")
                self.assertEqual(CartMap.speed_from_map_mode(slow), "slow")

    def test_unknown_speed_is_rejected(self):
        with self.assertRaises(ValueError):
            CartMap("hirom", 4 << 20, speed="turbo")

    def test_speed_does_not_disturb_anything_else(self):
        """Only the one header byte may differ between a slow and a fast build
        of the same image -- and the checksum that byte feeds."""
        for mapping, size in (("lorom", 1 << 20), ("hirom", 4 << 20),
                              ("exhirom", 6 << 20)):
            with self.subTest(m=mapping):
                cm = CartMap(mapping, size)
                img = bytes(build_image(mapping, size))
                s = self.write(f"{mapping}-slow.sfc", img)
                f = self.write(f"{mapping}-fast.sfc", img)
                self.assertEqual(run("--mapping", mapping, s).returncode, 0)
                self.assertEqual(
                    run("--mapping", mapping, "--fastrom", f).returncode, 0)
                a, b = open(s, "rb").read(), open(f, "rb").read()
                base = cm.header_file_offset
                differ = {i for i in range(len(a)) if a[i] != b[i]}
                allowed = {base + 0x25, base + 0x2C, base + 0x2D,
                           base + 0x2E, base + 0x2F}
                # (the high halves need not move -- +0x10 on the sum usually
                # does not carry -- so this is a subset, but 0x25 always moves)
                self.assertLessEqual(
                    differ, allowed,
                    "a speed change must touch only the map-mode byte and the "
                    "checksum/complement pair",
                )
                self.assertIn(base + 0x25, differ)
                self.assertEqual(b[base + 0x25], a[base + 0x25] | 0x10)

    def test_fast_and_fastrom_and_speed_fast_are_the_same_flag(self):
        img = bytes(build_image("hirom", 4 << 20))
        outs = []
        for flag in (["--fast"], ["--fastrom"], ["--speed", "fast"]):
            p = self.write(f"h{len(outs)}.sfc", img)
            r = run("--mapping", "hirom", *flag, p)
            self.assertEqual(r.returncode, 0, r.stderr)
            outs.append(open(p, "rb").read())
        self.assertEqual(outs[0], outs[1])
        self.assertEqual(outs[1], outs[2])

    def test_matches_the_pre_rewrite_tool_byte_for_byte(self):
        """Both constituencies at once: the LoROM/HiROM shapes main's callers
        use (`--fastrom`, `--hirom --fastrom`), slow and fast."""
        for mapping, size in (("lorom", 32 << 10), ("lorom", 1 << 20),
                              ("lorom", 4 << 20), ("hirom", 64 << 10),
                              ("hirom", 1 << 20), ("hirom", 4 << 20)):
            for fast in (False, True):
                with self.subTest(m=mapping, size=hex(size), fast=fast):
                    img = bytes(build_image(mapping, size))
                    p = self.write(f"{mapping}-{size}-{fast}.sfc", img)
                    args = ["--mapping", mapping] + (["--fastrom"] if fast else [])
                    r = run(*args, p)
                    self.assertEqual(r.returncode, 0, r.stderr)
                    self.assertEqual(
                        open(p, "rb").read(),
                        bytes(legacy_patch(bytearray(img), mapping == "hirom", fast)),
                    )

    def test_inspect_reads_the_speed_back_from_the_header(self):
        """A FastROM image inspects clean without being told it is fast."""
        img = bytes(build_image("hirom", 4 << 20))
        p = self.write("fast.sfc", img)
        self.assertEqual(run("--mapping", "hirom", "--fastrom", p).returncode, 0)
        r = run("--inspect", "--mapping", "hirom", p)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("fast ROM", r.stdout)
        self.assertIn("$31", r.stdout)
        self.assertIn("PASS", r.stdout)

    def test_inspect_with_an_explicit_wrong_speed_still_fails(self):
        """The read-back must not make the map-mode check unfalsifiable."""
        img = bytes(build_image("hirom", 4 << 20))
        p = self.write("fast2.sfc", img)
        run("--mapping", "hirom", "--fastrom", p)
        r = run("--inspect", "--mapping", "hirom", "--speed", "slow", p)
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("map mode byte $31", r.stdout)


class TestRegion(Fixture):
    """Video-standard region byte ($FFD9-family offset) -- one of the deferred
    ordinary-ROM canary rows. NTSC is the milestone's only tested standard
    until now; PAL rides on the same header/checksum machinery."""

    def test_model_derives_the_region_byte(self):
        for region, byte, standard in (("ntsc", 0x01, "ntsc"), ("pal", 0x02, "pal")):
            with self.subTest(region=region):
                self.assertEqual(REGION_BYTE[region], byte)
                self.assertEqual(video_standard_from_region_byte(byte), standard)

    def test_patch_writes_pal(self):
        img = bytes(build_image("hirom", 4 << 20))
        p = self.write("pal.sfc", img)
        r = run("--mapping", "hirom", "--region", "pal", p)
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(p, "rb") as f:
            rom = f.read()
        cm = CartMap("hirom", 4 << 20)
        self.assertEqual(rom[cm.header_file_offset + OFF_REGION], 0x02)
        i = run("--inspect", "--mapping", "hirom", "--region", "pal", p)
        self.assertEqual(i.returncode, 0, i.stdout + i.stderr)
        self.assertIn("PAL", i.stdout)

    def test_default_region_is_ntsc_even_over_garbage(self):
        """Unlike RAM-size/cartridge-type, the region byte IS always owned by
        the patcher (matching map mode/ROM size) -- a leftover/garbage byte
        from an unpatched build must not survive a plain patch."""
        img = bytearray(build_image("hirom", 4 << 20))
        cm = CartMap("hirom", 4 << 20)
        img[cm.header_file_offset + OFF_REGION] = 0xAB  # garbage, no --region given
        p = self.write("default.sfc", bytes(img))
        r = run("--mapping", "hirom", p)
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(p, "rb") as f:
            rom = f.read()
        self.assertEqual(rom[cm.header_file_offset + OFF_REGION], 0x01)

    def test_inspect_enforces_an_explicit_region_mismatch(self):
        img = bytes(build_image("hirom", 4 << 20))
        p = self.write("mismatch.sfc", img)
        run("--mapping", "hirom", "--region", "pal", p)
        r = run("--inspect", "--mapping", "hirom", "--region", "ntsc", p)
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("region byte $02", r.stdout)


class TestSRAM(Fixture):
    """Save-RAM header fields ($FFD8 size, $FFD6 cartridge type) -- volatile
    and battery-backed variants, for LoROM and HiROM/ExHiROM. The address
    model's own SRAM-aperture derivation is covered in
    test_snes_cartmap.py::TestSRAMAperture; these are the CLI-level golden
    fixtures over the same model."""

    def test_volatile_ram_patches_and_inspects_clean(self):
        for mapping, size in (("lorom", 4 << 20), ("hirom", 4 << 20), ("exhirom", 6 << 20)):
            with self.subTest(m=mapping):
                img = bytes(build_image(mapping, size))
                p = self.write(f"{mapping}-vol.sfc", img)
                r = run("--mapping", mapping, "--ram", "8k", p)
                self.assertEqual(r.returncode, 0, r.stderr)
                with open(p, "rb") as f:
                    rom = f.read()
                cm = CartMap(mapping, size)
                base = cm.header_file_offset
                self.assertEqual(rom[base + OFF_RAM_SIZE], CartMap.ram_header_byte(8 << 10))
                self.assertEqual(rom[base + OFF_CART_TYPE], CART_TYPE_ROM_RAM)
                i = run("--inspect", "--mapping", mapping, "--ram", "8k", p)
                self.assertEqual(i.returncode, 0, i.stdout + i.stderr)
                self.assertIn("8 KiB save RAM", i.stdout)

    def test_battery_backed_ram_patches_and_inspects_clean(self):
        for mapping, size in (("lorom", 4 << 20), ("exhirom", 6 << 20)):
            with self.subTest(m=mapping):
                img = bytes(build_image(mapping, size))
                p = self.write(f"{mapping}-batt.sfc", img)
                r = run("--mapping", mapping, "--ram", "32k", "--battery", p)
                self.assertEqual(r.returncode, 0, r.stderr)
                with open(p, "rb") as f:
                    rom = f.read()
                cm = CartMap(mapping, size)
                self.assertEqual(rom[cm.header_file_offset + OFF_CART_TYPE],
                                  CART_TYPE_ROM_RAM_BATTERY)
                i = run("--inspect", "--mapping", mapping, "--ram", "32k", "--battery", p)
                self.assertEqual(i.returncode, 0, i.stdout + i.stderr)

    def test_battery_without_ram_is_rejected(self):
        p = self.write("nobatt.sfc", bytes(build_image("hirom", 4 << 20)))
        r = run("--mapping", "hirom", "--battery", p)
        self.assertEqual(r.returncode, 1)
        self.assertIn("--battery given without --ram", r.stderr)

    def test_inspect_enforces_a_ram_size_mismatch(self):
        p = self.write("mismatch.sfc", bytes(build_image("hirom", 4 << 20)))
        run("--mapping", "hirom", "--ram", "8k", p)
        r = run("--inspect", "--mapping", "hirom", "--ram", "32k", p)
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("RAM-size byte", r.stdout)

    def test_no_ram_flag_leaves_ram_and_cart_type_bytes_untouched(self):
        """Regression guard: a plain patch (no --ram) must not default-own the
        RAM-size/cartridge-type bytes the way map mode/ROM size/region are
        owned unconditionally -- a coprocessor test fixture pre-sets $FFD6
        (see TestNegativeFixtures) and relies on the patcher leaving it alone.
        This first version of --ram support broke exactly that until caught
        here: it wrote CART_TYPE_ROM_ONLY over the fixture's coprocessor byte,
        turning every unsupported-coprocessor negative fixture into a false
        pass."""
        cm = CartMap("hirom", 4 << 20)
        img = bytearray(build_image("hirom", 4 << 20))
        img[cm.header_file_offset + OFF_CART_TYPE] = 0x13  # SuperFX, pre-set
        img[cm.header_file_offset + OFF_RAM_SIZE] = 0x05  # pre-set, arbitrary
        p = self.write("untouched.sfc", bytes(img))
        r = run("--mapping", "hirom", p)  # no --ram
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(p, "rb") as f:
            rom = f.read()
        self.assertEqual(rom[cm.header_file_offset + OFF_CART_TYPE], 0x13)
        self.assertEqual(rom[cm.header_file_offset + OFF_RAM_SIZE], 0x05)


class TestHeaderVariants(Fixture):
    """Legacy vs. expanded internal header, and unheadered `.sfc` input. The
    extended-header block ($FFB0-$FFBF for LoROM, the matching offsets for
    HiROM/ExHiROM: maker code, game code, fixed bytes, expansion RAM/flash
    size, special version, cartridge sub-type) is a post-~1994 convention;
    older titles leave it as whatever the linker padded there. This tool never
    reads or writes that block (TITLE_OFF starts right after it), so both
    header vintages -- and the copier-header-free `.sfc` this builder always
    emits -- must patch and inspect identically."""

    #: The extended-header block is $00-$0F relative to the header base.
    EXT_HEADER_LEN = 0x10

    def test_legacy_zero_filled_extended_header_is_ignored(self):
        cm = CartMap("exhirom", 6 << 20)
        img = bytearray(build_image("exhirom", 6 << 20))
        base = cm.header_file_offset
        img[base : base + self.EXT_HEADER_LEN] = bytes(self.EXT_HEADER_LEN)
        p = self.write("legacy.sfc", bytes(img))
        self.assertEqual(run("--mapping", "exhirom", p).returncode, 0)
        r = run("--inspect", "--mapping", "exhirom", p)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("PASS", r.stdout)

    def test_expanded_header_fields_are_ignored(self):
        """A plausible post-1994 extended header (maker/game code, non-zero
        expansion fields) must patch and inspect just as cleanly as the
        legacy, zero-filled one -- because this tool never reads or writes
        that block. The checksum LEGITIMATELY differs (it sums the whole
        image, extended header included); what must stay identical is every
        byte the tool actually derives from the mapping/model -- map mode,
        ROM-size, region, title -- regardless of what vintage of header
        surrounds them."""
        cm = CartMap("exhirom", 6 << 20)
        legacy = bytearray(build_image("exhirom", 6 << 20))
        base = cm.header_file_offset
        legacy[base : base + self.EXT_HEADER_LEN] = bytes(self.EXT_HEADER_LEN)
        expanded = bytearray(legacy)
        expanded[base : base + 2] = b"01"  # maker code
        expanded[base + 2 : base + 6] = b"ABCD"  # game code
        expanded[base + 0x0C] = 0x01  # expansion flash size
        expanded[base + 0x0D] = 0x01  # expansion RAM size
        expanded[base + 0x0E] = 0x01  # special version
        expanded[base + 0x0F] = 0x02  # cartridge sub-type

        lp = self.write("legacy2.sfc", bytes(legacy))
        ep = self.write("expanded.sfc", bytes(expanded))
        self.assertEqual(run("--mapping", "exhirom", lp).returncode, 0)
        self.assertEqual(run("--mapping", "exhirom", ep).returncode, 0)
        with open(lp, "rb") as f:
            lout = f.read()
        with open(ep, "rb") as f:
            eout = f.read()
        # Every extended-header byte this fixture actually changed must show
        # up as different (the tool did not, say, silently zero it back out).
        # Offsets base+6..base+11 are the header's own "6 fixed 0x00 bytes"
        # field, left untouched in both images, so they are deliberately
        # excluded rather than asserted equal to the full 16-byte block.
        changed = {base, base + 1, base + 2, base + 3, base + 4, base + 5,
                   base + 0x0C, base + 0x0D, base + 0x0E, base + 0x0F}
        differ = {i for i in range(len(lout)) if lout[i] != eout[i]}
        self.assertEqual(differ & set(range(base, base + self.EXT_HEADER_LEN)), changed)
        # ...and the only OTHER thing allowed to move is the checksum pair
        # (content changed, so the sum must too); map mode/ROM-size/region/
        # title are structural/derived and must be identical either way.
        self.assertLessEqual(
            differ - set(range(base, base + self.EXT_HEADER_LEN)),
            {base + OFF_CHECKSUM, base + OFF_CHECKSUM + 1,
             base + OFF_COMPLEMENT, base + OFF_COMPLEMENT + 1},
        )
        for off in (OFF_MAP_MODE, OFF_ROM_SIZE, OFF_REGION):
            self.assertEqual(lout[base + off], eout[base + off])
        for p in (lp, ep):
            r = run("--inspect", "--mapping", "exhirom", p)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_unheadered_sfc_is_the_only_input_this_tool_accepts(self):
        """The builder always emits an unheadered `.sfc`; TestNegativeFixtures
        already proves a 512-byte copier header is rejected outright
        (`test_reject_copier_header`). This is the positive complement: every
        golden fixture above IS the unheadered-input path, exercised on every
        mapping."""
        for mapping, size in (("lorom", 1 << 20), ("hirom", 4 << 20), ("exhirom", 6 << 20)):
            with self.subTest(m=mapping):
                img = bytes(build_image(mapping, size))
                self.assertEqual(len(img) & 0x1FF, 0, "fixture itself must not be 512-aligned"
                                  " off by a copier header")
                p = self.write(f"{mapping}-plain.sfc", img)
                self.assertEqual(run("--mapping", mapping, p).returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
