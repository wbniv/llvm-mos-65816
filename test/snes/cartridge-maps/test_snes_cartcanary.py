#!/usr/bin/env python3
"""Host tests for the canary generator -- above all, that the oracle DISCRIMINATES.

An oracle that is merely "computed the same way on both sides" proves nothing:
the first version of the padding pattern was XOR-linear and the fold was XOR, so
every span folded to $0000 -- and to $0000 for the WRONG bank too. These tests
pin the properties that make the oracle a test rather than a tautology.

Run:  python3 test/snes/cartridge-maps/test_snes_cartcanary.py
"""
from __future__ import annotations

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from snes_cartmap import CartMap  # noqa: E402

# The generator is a hyphenated CLI (repo convention for tools/), so it is loaded
# by path rather than imported by name.
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location(
    "snes_cartcanary", os.path.join(ROOT, "tools", "snes-cartcanary.py")
)
gen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gen)

CONFIGS = [("hirom", 4 << 20), ("exhirom", 6 << 20), ("exhirom", 8 << 20)]


def fold_bytes(bs) -> int:
    h = 0
    for b in bs:
        h = gen.fold(h, b)
    return h


class TestPatternDiscriminates(unittest.TestCase):
    def test_pattern_is_not_xor_linear(self):
        """p(a) ^ p(b) ^ p(c) != p(a^b^c) for some triple -- the property whose
        absence made every fold collapse to zero."""
        bad = [
            (a, b)
            for a in (0x1000, 0x2000, 0x40000)
            for b in (0x1, 0x100, 0x10000)
            if gen.pattern(a) ^ gen.pattern(b) ^ gen.pattern(0) != gen.pattern(a ^ b)
        ]
        self.assertTrue(bad, "pattern is XOR-linear; folds will collapse")

    def test_fold_of_an_aligned_run_is_not_zero(self):
        """The exact degeneracy that shipped and was caught: a power-of-two
        aligned, power-of-two length run must not fold to zero."""
        for base in (0x000000, 0x00FF00, 0x1FFF80, 0x3FFE00, 0x400000):
            for n in (256, 1024, 4096):
                with self.subTest(base=hex(base), n=n):
                    h = fold_bytes(gen.pattern(base + i) for i in range(n))
                    self.assertNotEqual(h, 0)

    def test_a_wrong_bank_changes_every_span_fold(self):
        """Simulate the classic bug -- the cursor's bank byte off by one -- and
        require the fold to change. This is what the oracle actually asserts."""
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            _, spans = gen.sites(cm)
            self.assertTrue(spans)
            for s in spans:
                with self.subTest(m=mapping, size=hex(size), span=s.tag):
                    wrong = 0
                    for _, n, base in s.segments:
                        for i in range(n):
                            wrong = gen.fold(wrong, gen.pattern(base + i + 0x10000))
                    self.assertNotEqual(s.want, wrong, "bank-off-by-one is invisible")

    def test_a_single_flipped_byte_changes_every_span_fold(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            _, spans = gen.sites(cm)
            for s in spans:
                with self.subTest(m=mapping, span=s.tag):
                    data = []
                    for _, n, base in s.segments:
                        data += [gen.pattern(base + i) for i in range(n)]
                    for idx in (0, len(data) // 2, len(data) - 1):
                        bad = list(data)
                        bad[idx] ^= 0x01
                        self.assertNotEqual(s.want, fold_bytes(bad))

    def test_a_dropped_and_a_duplicated_byte_change_the_fold(self):
        """The plan's negative fixtures: a skipped byte and a duplicated byte."""
        cm = CartMap("exhirom", 6 << 20)
        _, spans = gen.sites(cm)
        s = spans[0]
        data = []
        for _, n, base in s.segments:
            data += [gen.pattern(base + i) for i in range(n)]
        self.assertNotEqual(s.want, fold_bytes(data[:5] + data[6:]))       # skipped
        self.assertNotEqual(s.want, fold_bytes(data[:5] + [data[5]] + data[5:]))  # duplicated
        self.assertNotEqual(s.want, fold_bytes(list(reversed(data))))      # order

    def test_spans_do_not_collide(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            _, spans = gen.sites(cm)
            folds = [s.want for s in spans]
            self.assertEqual(len(folds), len(set(folds)), f"{mapping}: colliding folds")

    def test_canary_bytes_within_a_config_are_mostly_distinct(self):
        """Not a hard requirement byte-for-byte (a byte has 256 values), but a
        near-total collision would mean the pattern is not offset-sensitive."""
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            canaries, _ = gen.sites(cm)
            vals = [c.want for c in canaries]
            self.assertGreaterEqual(len(set(vals)), max(2, len(vals) - 1))


class TestSpanShapes(unittest.TestCase):
    def test_required_fixtures_are_present(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            _, spans = gen.sites(cm)
            tags = {s.tag for s in spans}
            with self.subTest(m=mapping, size=hex(size)):
                self.assertIn("BANK_SPAN", tags)
                self.assertIn("MULTIBANK_SPAN", tags)
                if mapping == "exhirom":
                    self.assertIn("EDGE_4M", tags)

    def test_bank_span_crosses_exactly_one_bank_boundary(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            _, spans = gen.sites(cm)
            s = next(x for x in spans if x.tag == "BANK_SPAN")
            self.assertEqual(s.banks, 2, f"{mapping}: BANK_SPAN touches {s.banks} banks")

    def test_multibank_span_touches_at_least_three_banks(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            _, spans = gen.sites(cm)
            s = next(x for x in spans if x.tag == "MULTIBANK_SPAN")
            self.assertGreaterEqual(s.banks, 3, f"{mapping}: only {s.banks} banks")

    def test_edge_4m_begins_below_and_ends_above_the_device_boundary(self):
        cm = CartMap("exhirom", 6 << 20)
        _, spans = gen.sites(cm)
        s = next(x for x in spans if x.tag == "EDGE_4M")
        self.assertLess(s.off, 0x400000)
        self.assertGreater(s.off + s.length, 0x400000)
        # It must be TWO segments in different regions -- an incrementing pointer
        # cannot make this crossing, which is the whole point of the fixture.
        self.assertEqual(len(s.segments), 2)
        self.assertEqual(s.segments[0][0] >> 16, 0xFF)
        self.assertEqual(s.segments[1][0] >> 16, 0x40)
        self.assertEqual(s.segments[1][0] & 0xFFFF, 0x0000)

    def test_no_segment_crosses_a_64_kib_bank(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            _, spans = gen.sites(cm)
            for s in spans:
                for a, n, _ in s.segments:
                    with self.subTest(m=mapping, span=s.tag, seg=hex(a)):
                        self.assertLessEqual((a & 0xFFFF) + n, 0x10000)
                        self.assertLessEqual(n, 0xFFFF, "length must fit a 16-bit counter")

    def test_segments_concatenate_back_to_the_source_object(self):
        """No gaps, no duplicated bytes: the file offsets the segment list walks
        must be exactly [off, off+length)."""
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            _, spans = gen.sites(cm)
            for s in spans:
                with self.subTest(m=mapping, span=s.tag):
                    seen = []
                    for a, n, base in s.segments:
                        self.assertEqual(cm.cpu_to_file(a >> 16, a & 0xFFFF), base)
                        seen += list(range(base, base + n))
                    self.assertEqual(seen, list(range(s.off, s.off + s.length)))

    def test_spans_and_canaries_never_overlap_linked_code(self):
        """Their expected values come from the padding pattern, so they must not
        land on bytes the linker owns."""
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            lo, hi = gen.code_region(cm)
            canaries, spans = gen.sites(cm)
            for c in canaries:
                self.assertFalse(lo <= c.off < hi, f"{c.tag} is inside linked code")
            for s in spans:
                self.assertFalse(s.off < hi and s.off + s.length > lo, f"{s.tag} overlaps code")


class TestSparseFill(unittest.TestCase):
    """The pattern is written only where the ROM reads. That is a size
    optimisation for the published images, so it must be provably complete:
    every compared byte covered, and nothing claimed outside."""

    def test_every_read_site_is_covered_by_a_fill_range(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            ranges = gen.fill_ranges(cm)

            def covered(o, _r=ranges):
                return any(a <= o < b for a, b in _r)

            canaries, spans = gen.sites(cm)
            for c in canaries:
                with self.subTest(m=mapping, tag=c.tag):
                    self.assertTrue(covered(c.off), f"{c.tag} not filled")
            for s in spans:
                for _, n, base in s.segments:
                    for o in (base, base + n - 1):
                        with self.subTest(m=mapping, span=s.tag, off=hex(o)):
                            self.assertTrue(covered(o))
            for tag, canon, mirror, _ in gen.mirror_probes(cm):
                for far in (canon, mirror):
                    off = cm.cpu_to_file(far >> 16, far & 0xFFFF)
                    with self.subTest(m=mapping, tag=tag, off=hex(off)):
                        self.assertTrue(covered(off), f"{tag} not filled")

    def test_fill_ranges_are_sorted_disjoint_and_small(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            ranges = gen.fill_ranges(cm)
            with self.subTest(m=mapping, size=hex(size)):
                for (a, b), (c, d) in zip(ranges, ranges[1:]):
                    self.assertLess(a, b)
                    self.assertLess(b, c, "ranges overlap or are unmerged")
                total = sum(b - a for a, b in ranges)
                # If this ever approaches the whole image the fill has stopped
                # being sparse and the published ROM stops compressing.
                self.assertLess(total, size // 8)

    def test_fill_ranges_never_touch_linked_code(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            lo, hi = gen.code_region(cm)
            for a, b in gen.fill_ranges(cm):
                with self.subTest(m=mapping, rng=(hex(a), hex(b))):
                    self.assertFalse(a < hi and b > lo)

    def test_zero_padding_scores_as_no_header_anywhere(self):
        """Sparse fill leaves the decoy header locations zero, which bsnes
        rejects outright (a reset vector below $8000)."""
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            data = bytearray(size)
            for a, b in gen.fill_ranges(cm):
                data[a:b] = bytes(gen.pattern(o) for o in range(a, b))
            with self.subTest(m=mapping, size=hex(size)):
                for probe in (0x007FB0, 0x00FFB0, 0x407FB0):
                    if probe == cm.header_file_offset:
                        continue
                    self.assertEqual(
                        CartMap.score_header(bytes(data), probe), 0,
                        f"padding scores as a header at ${probe:06X}")


class TestLayout(unittest.TestCase):
    def test_regions_tile_the_image_in_file_order(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            regs = gen.layout(cm)
            with self.subTest(m=mapping, size=hex(size)):
                self.assertEqual(sum(r.length for r in regs), size)
                at = 0
                for r in regs:
                    self.assertEqual(r.file_start, at)
                    at += r.length

    def test_every_reachable_region_origin_is_its_modelled_cpu_address(self):
        """A region's ORIGIN must be the canonical CPU address of its first file
        byte -- otherwise the linker and the model disagree about where a symbol
        lives, which is the failure this whole exercise exists to prevent."""
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            holes = cm.holes()
            for r in gen.layout(cm):
                if r.name in ("rom", "romhdr"):
                    continue  # deliberately linked at the bank-$00 mirror
                if any(s <= r.file_start < e for s, e in holes):
                    continue  # unreachable pad; ORIGIN is a linker convenience
                with self.subTest(m=mapping, size=hex(size), region=r.name):
                    bank, addr = cm.file_to_cpu(r.file_start)
                    self.assertEqual(r.origin, bank << 16 | addr)

    def test_near_window_maps_to_the_boot_bank(self):
        """The linker puts code at CPU $008000. Under each mapping that must be
        the same physical byte the region's file offset says."""
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            regs = {r.name: r for r in gen.layout(cm)}
            with self.subTest(m=mapping):
                self.assertEqual(cm.cpu_to_file(0x00, 0x8000), regs["rom"].file_start)
                self.assertEqual(cm.cpu_to_file(0x00, 0xFFFC),
                                 regs["romhdr"].file_start + 0x4C)

    def test_exhirom_boot_code_lives_in_the_second_region(self):
        for size in (6 << 20, 8 << 20):
            cm = CartMap("exhirom", size)
            regs = {r.name: r for r in gen.layout(cm)}
            self.assertEqual(regs["rom"].file_start, 0x408000)
            self.assertEqual(regs["romhdr"].file_start, 0x40FFB0)
            self.assertEqual(cm.header_file_offset, regs["romhdr"].file_start)

    def test_8_mib_layout_pads_the_unreachable_holes(self):
        cm = CartMap("exhirom", 8 << 20)
        regs = gen.layout(cm)
        names = [r.name for r in regs]
        self.assertIn("pad_3elo", names)
        self.assertIn("rom_3e", names)
        self.assertIn("pad_3flo", names)
        self.assertIn("rom_3f", names)
        for r in regs:
            if r.name.startswith("pad_"):
                self.assertTrue(any(s <= r.file_start < e for s, e in cm.holes()))

    def test_linker_script_is_generated_and_self_consistent(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            ld = gen.emit_linker_script(cm)
            with self.subTest(m=mapping, size=hex(size)):
                self.assertIn("OUTPUT_FORMAT {", ld)
                for r in gen.layout(cm):
                    self.assertIn(f"FULL({r.name})", ld)
                    self.assertIn(f"{r.name:<{max(len(x.name) for x in gen.layout(cm))}} : ORIGIN", ld)
                self.assertIn("ASSERT(", ld)

    def test_checked_in_platform_matches_the_generated_6_mib_layout(self):
        """platforms/snes-exhirom/link.ld is the reusable, checked-in ExHiROM
        platform. It must be byte-identical to what the model generates, so the
        platform and the generator cannot drift apart."""
        path = os.path.join(ROOT, "platforms", "snes-exhirom", "link.ld")
        if not os.path.exists(path):
            self.skipTest("platforms/snes-exhirom/link.ld not present")
        with open(path, encoding="utf-8") as f:
            on_disk = f.read()
        self.assertEqual(on_disk, gen.emit_linker_script(CartMap("exhirom", 6 << 20)))


class TestOracle(unittest.TestCase):
    def test_oracle_differs_between_configurations(self):
        oracles = {}
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            text = gen.emit_header(cm, f"{mapping}{size}")
            line = next(l for l in text.splitlines() if "CANARY_ORACLE" in l)
            oracles[(mapping, size)] = line
        self.assertEqual(len(set(oracles.values())), len(oracles),
                         "two cartridge configurations share an oracle")

    def test_header_addresses_are_canonical(self):
        """Every emitted address must round-trip through the model's checked
        inverse -- i.e. no descriptor names a mirror."""
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            canaries, spans = gen.sites(cm)
            for c in canaries:
                with self.subTest(m=mapping, tag=c.tag):
                    self.assertEqual(cm.file_to_cpu(c.off), (c.far >> 16, c.far & 0xFFFF))
            for s in spans:
                for a, _, base in s.segments:
                    self.assertEqual(cm.file_to_cpu(base), (a >> 16, a & 0xFFFF))

    def test_mirror_probes_are_genuine_mirrors_of_one_byte(self):
        for mapping, size in CONFIGS:
            cm = CartMap(mapping, size)
            probes = gen.mirror_probes(cm)
            self.assertTrue(probes)
            for tag, canon, mirror, want in probes:
                with self.subTest(m=mapping, tag=tag):
                    self.assertNotEqual(canon, mirror)
                    off = cm.cpu_to_file(canon >> 16, canon & 0xFFFF)
                    self.assertEqual(cm.cpu_to_file(mirror >> 16, mirror & 0xFFFF), off)
                    self.assertEqual(want, gen.pattern(off))
                    # the canonical address really is the canonical one
                    self.assertEqual(cm.file_to_cpu(off), (canon >> 16, canon & 0xFFFF))


if __name__ == "__main__":
    unittest.main(verbosity=2)
