"""Regression guard for tools/torture_filter.py's sanitize-before-truncate ordering.

_first() cuts a diagnostic line to 200 chars; sanitize() strips the FUZZ_ROOT prefix (and
collapses tempdir paths). If the cap ran before the strip, the manifest's third column
would depend on FUZZ_ROOT's absolute length: a longer root eats more of the 200-char
budget before it's ever removed. These tests build the same diagnostic under two roots
whose lengths differ by 60+ chars and assert the sanitized+capped result is identical.
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parents[1] / "tools"))
import torture_filter as tf  # noqa: E402

SHORT_ROOT = "/r"
LONG_ROOT = "/" + "root-directory-name" * 4  # 80 chars — differs from SHORT_ROOT by 78+.
assert len(LONG_ROOT) - len(SHORT_ROOT) >= 60

# Long enough that, pre-fix (cap-then-strip), the two roots would retain a different
# number of real characters after the root prefix was removed.
TAIL = "clang really does not like this construct at all, here is why: " * 4


def _diag_line(root):
    return "%s/vendor/c-torture/execute/foo.c:12:3: error: %s" % (root, TAIL)


def test_first_sanitizes_before_capping(monkeypatch):
    monkeypatch.setattr(tf, "ROOT", Path(SHORT_ROOT))
    short_result = tf._first(_diag_line(SHORT_ROOT), ("error:",))

    monkeypatch.setattr(tf, "ROOT", Path(LONG_ROOT))
    long_result = tf._first(_diag_line(LONG_ROOT), ("error:",))

    assert short_result == long_result
    assert len(short_result) <= 200
    assert "/vendor/c-torture" not in short_result  # root prefix was stripped
    assert SHORT_ROOT not in short_result
    assert LONG_ROOT not in long_result


def test_classify_diag_is_root_length_independent(monkeypatch):
    monkeypatch.setattr(tf, "ROOT", Path(SHORT_ROOT))
    reason_short, diag_short = tf.classify(_diag_line(SHORT_ROOT))

    monkeypatch.setattr(tf, "ROOT", Path(LONG_ROOT))
    reason_long, diag_long = tf.classify(_diag_line(LONG_ROOT))

    assert reason_short == reason_long == "compile-error"
    assert diag_short == diag_long


def test_sanitize_strips_root_and_tmp(monkeypatch):
    monkeypatch.setattr(tf, "ROOT", Path(SHORT_ROOT))
    assert tf.sanitize(SHORT_ROOT + "/vendor/c-torture/execute/foo.c: error") == (
        "vendor/c-torture/execute/foo.c: error"
    )
    assert tf.sanitize("see /tmp/torture-shim-abc123/x.o") == "see <tmp>"


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
