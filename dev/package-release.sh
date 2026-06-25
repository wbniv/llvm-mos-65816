#!/usr/bin/env bash
# dev/package-release.sh — assemble a relocatable, self-contained Linux x86-64
# distribution of the llvm-mos-65816 toolchain (clang + lld + binutils) MERGED
# with the SNES SDK into ONE prefix, and emit a deterministic .tar.xz + .sha256.
#
# This tarball is the human download AND the source the apt .deb repacks
# (apt.indri.studio). It is an interim/preview build, published while the
# #320 (far-pointer) / #321 (16-bit-register) codegen patches are upstreamed.
#
# Inputs (already built):
#   build/llvm-mos-install/   <- dev/run.sh toolchain   (clang / lld / llvm-*)
#   build/install/            <- dev/run.sh build        (SNES SDK + platforms)
# Output:
#   dist/llvm-mos-65816-<stamp>-linux-x86_64.tar.xz  (+ .sha256)
#
# Relocatability: the toolchain bin/ and the SDK bin/ (.cfg + mos-*-clang
# drivers) + mos-platform/ are merged into one prefix. The SDK driver
# `mos-snes-clang -> mos-clang` dangles unless both bin/ halves share a prefix;
# the .cfg files are already relocatable via clang's <CFGDIR> token. A self-test
# compiles a SNES ROM from the *moved* prefix to prove it before packaging.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: dev/package-release.sh [-h]

Assemble dist/llvm-mos-65816-<stamp>-linux-x86_64.tar.xz from the built
toolchain (build/llvm-mos-install) + SNES SDK (build/install).

Environment overrides:
  TOOLCHAIN_INSTALL  toolchain install prefix    (default build/llvm-mos-install)
  SDK_INSTALL        SDK install prefix           (default build/install)
  DIST_DIR           output directory             (default dist)
  STAMP              version stamp                 (default <UTC-date>-<short-sha>)
  STRIP              1=strip ELF debug (default), 0=keep
  RELEASE_DOCS_DIR   if set, its contents are copied into <tree>/docs/
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN_INSTALL="${TOOLCHAIN_INSTALL:-$ROOT/build/llvm-mos-install}"
SDK_INSTALL="${SDK_INSTALL:-$ROOT/build/install}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
STRIP="${STRIP:-1}"
# Bundle the reader docs (.md + .pdf) so they ship with the release and the clean-room
# report can list them. Default to the sibling indri.studio generated docs WHEN PRESENT;
# an explicit RELEASE_DOCS_DIR=<path> overrides, RELEASE_DOCS_DIR= (empty) disables.
# (Set via ${VAR-default}, so only an UNSET var triggers the auto-detect.)
DEFAULT_DOCS_DIR="$ROOT/../indri.studio/public/docs"
RELEASE_DOCS_DIR="${RELEASE_DOCS_DIR-$([ -d "$DEFAULT_DOCS_DIR" ] && echo "$DEFAULT_DOCS_DIR" || true)}"

# --- preflight -------------------------------------------------------------
[[ -x "$TOOLCHAIN_INSTALL/bin/clang-23" ]] || {
    echo "FATAL: toolchain not built at $TOOLCHAIN_INSTALL" >&2
    echo "  build it:  dev/run.sh toolchain" >&2
    exit 1
}
[[ -f "$SDK_INSTALL/bin/mos-snes.cfg" ]] || {
    echo "FATAL: SNES SDK not built at $SDK_INSTALL" >&2
    echo "  build it:  MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build" >&2
    exit 1
}
command -v xz >/dev/null || { echo "FATAL: xz not installed" >&2; exit 1; }

# --- stamp / names ---------------------------------------------------------
SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)"
DIRTY=""
if ! git -C "$ROOT" diff --quiet 2>/dev/null || ! git -C "$ROOT" diff --cached --quiet 2>/dev/null; then
    DIRTY="-dirty"
fi
STAMP="${STAMP:-$(date -u +%Y%m%d)-${SHA}${DIRTY}}"
NAME="llvm-mos-65816-${STAMP}-linux-x86_64"
STAGE="$DIST_DIR/$NAME"
SOURCE_EPOCH="$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || echo 0)"

is_elf() { [[ "$(od -An -N4 -tx1 "$1" 2>/dev/null | tr -d ' \n')" == "7f454c46" ]]; }

echo "==> staging $NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/lib"

# --- 1. toolchain bin/ via an ALLOW-LIST -----------------------------------
# The install tree still carries clangd/clang-tidy/clang-refactor/etc (~350 MB)
# that a cross-compiler user never needs. The allow-list (not the build) is the
# authoritative filter: a new junk tool will simply not be shipped.
KEEP_REAL=(
    clang-23 clang-format
    lld
    llvm-ar llvm-cxxfilt llvm-dwarfdump llvm-mc llvm-mlb llvm-nm
    llvm-objcopy llvm-objdump llvm-readobj llvm-size llvm-strings llvm-symbolizer
)
KEEP_LINKS=(
    clang clang++ clang-cpp
    ld.lld ld64.lld lld-link wasm-ld
    llvm-addr2line llvm-ranlib llvm-readelf llvm-strip
    mos-clang mos-clang++ mos-clang-cpp
)
for f in "${KEEP_REAL[@]}" "${KEEP_LINKS[@]}"; do
    src="$TOOLCHAIN_INSTALL/bin/$f"
    if [[ -e "$src" || -L "$src" ]]; then
        cp -a "$src" "$STAGE/bin/"
    else
        echo "  WARN: expected toolchain bin/$f missing — skipping" >&2
    fi
done

# --- 2. clang resource dir (bin/../lib/clang/<ver>, derived at runtime) -----
cp -a "$TOOLCHAIN_INSTALL"/lib/clang "$STAGE/lib/"

# --- 3. overlay the WHOLE SNES SDK into the SAME prefix (~15 MB, all platforms) ---
# Merges the SDK's .cfg files + mos-*-clang driver symlinks into stage/bin (the
# toolchain provides the mos-clang they point at), the platform trees, and the
# SDK cmake package. No name collisions: the toolchain bin/ has no .cfg/driver,
# the SDK bin/ has no real compiler binary.
cp -a "$SDK_INSTALL"/bin/. "$STAGE/bin/"
cp -a "$SDK_INSTALL"/mos-platform "$STAGE/"
[[ -d "$SDK_INSTALL/lib" ]] && cp -a "$SDK_INSTALL"/lib/. "$STAGE/lib/"

# --- 4. strip (clang-23 ships unstripped ~120 MB — the dominant size lever) -
if [[ "$STRIP" == "1" ]]; then
    echo "==> stripping ELF binaries with the bundled llvm-objcopy"
    OBJCOPY="$STAGE/bin/llvm-objcopy"
    while IFS= read -r -d '' bin; do
        if [[ -f "$bin" && ! -L "$bin" ]] && is_elf "$bin"; then
            "$OBJCOPY" --strip-unneeded "$bin" 2>/dev/null || true
        fi
    done < <(find "$STAGE/bin" -maxdepth 1 -type f -print0)
fi

# --- 5. relocatability + WARNING-FREE self-test (the gate) -----------------
# This is a public release: zero warnings tolerated. Compile a SNES ROM from
# the *moved* prefix, capturing stderr, and fail on a broken prefix OR on any
# warning (e.g. an ld.lld data-layout mismatch from an SDK built with the
# default unpatched /opt/llvm-mos — fixed by `task release-sdk`).
echo "==> self-test: warning-free compile of a SNES ROM from the relocated prefix"
SELFTEST_DIR="$(mktemp -d)"
trap 'rm -rf "$SELFTEST_DIR"' EXIT
SELFTEST_ERR="$SELFTEST_DIR/stderr.log"
if ! "$STAGE/bin/mos-clang" --config "$STAGE/bin/mos-snes.cfg" -mcpu=mosw65816 \
        -Os -o "$SELFTEST_DIR/selftest.sfc" "$ROOT/examples/snes/hello.c" 2>"$SELFTEST_ERR"; then
    echo "FATAL: self-test failed — the relocated prefix is broken" >&2
    sed 's/^/    /' "$SELFTEST_ERR" >&2
    exit 1
fi
if grep -qiE 'warning|error' "$SELFTEST_ERR"; then
    echo "FATAL: release build is NOT warning-clean (public release — no warnings allowed)." >&2
    echo "  offending diagnostics:" >&2
    sed 's/^/    /' "$SELFTEST_ERR" >&2
    echo >&2
    echo "  The runtime libs must match the current backend's data layout. Rebuild, in order:" >&2
    echo "    task release-builtins   # toolchain mos compiler-rt (the stale-after-patch libcrt fix)" >&2
    echo "    task release-sdk        # SDK libc/crt0 against the patched toolchain" >&2
    echo "  then re-run  task package  ." >&2
    exit 1
fi
echo "    OK  $(stat -c%s "$SELFTEST_DIR/selftest.sfc") bytes — no warnings"
if find "$STAGE" -xtype l | grep -q .; then
    echo "FATAL: dangling symlinks in staged tree:" >&2
    find "$STAGE" -xtype l >&2
    exit 1
fi

# --- 6. license + optional docs + generated README -------------------------
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$STAGE/"
if [[ -n "$RELEASE_DOCS_DIR" && -d "$RELEASE_DOCS_DIR" ]]; then
    echo "==> bundling docs from $RELEASE_DOCS_DIR"
    mkdir -p "$STAGE/docs"
    cp -a "$RELEASE_DOCS_DIR"/. "$STAGE/docs/"
fi

cat > "$STAGE/README.md" <<EOF
# llvm-mos-65816 — interim preview toolchain (Linux x86-64)

An optimizing C cross-compiler for the WDC 65816 (the Super Nintendo's CPU),
built on [llvm-mos](https://github.com/llvm-mos/llvm-mos) with the #320
(far-pointer / 24-bit addressing) and #321 (native 16-bit register) codegen
patches, plus the SNES SDK platform.

**Preview build** — published while those patches are upstreamed. Once they land
in upstream llvm-mos / llvm-mos-sdk, prefer the upstream releases.

Provenance: llvm-mos-65816 @ ${SHA} · built $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Use it

This tree is relocatable — extract anywhere; keep \`bin/\` and \`mos-platform/\`
as siblings. Compile a SNES ROM:

\`\`\`sh
bin/mos-clang --config bin/mos-snes.cfg -mcpu=mosw65816 -Os -o hello.sfc hello.c
\`\`\`

Opt into the native 16-bit codegen (the point of this fork):

\`\`\`sh
bin/mos-clang --config bin/mos-snes.cfg -mcpu=mosw65816 \\
    -Xclang -target-feature -Xclang +mos-a16 \\
    -Xclang -target-feature -Xclang +mos-xy16 \\
    -Os -o hello.sfc hello.c
\`\`\`

Licensed Apache-2.0 with LLVM exceptions — see \`LICENSE\` / \`NOTICE\`.
EOF

# --- 7. deterministic tarball + checksum -----------------------------------
echo "==> packaging"
( cd "$DIST_DIR" \
  && XZ_OPT="-9e" tar \
        --sort=name --mtime="@${SOURCE_EPOCH}" \
        --owner=0 --group=0 --numeric-owner \
        -cJf "$NAME.tar.xz" "$NAME" )
( cd "$DIST_DIR" && sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256" )

# --- 8. clean-room PUBLISH GATE --------------------------------------------
# The warning-free self-test above proves the relocated prefix links cleanly; this
# proves the published artifact actually BOOTS and COMPUTES correctly. In a throwaway
# container with NO dev toolchain, acquire THIS tarball's mos-snes-clang, compile the
# reference Mandelbrot (default-8bit + +mos-a16), run each ROM in bsnes-jg (embedded
# SPC700 IPL → no BIOS/sound) and assert the WRAM CRC == an independent host oracle.
# A FAIL here means the tarball must NOT be published. Override (NOT for a real
# release) with SKIP_RELEASE_TEST=1; if Docker is absent the gate FAILS, not skips.
if [[ "${SKIP_RELEASE_TEST:-0}" == "1" ]]; then
    echo "==> SKIP_RELEASE_TEST=1 — clean-room emulator gate SKIPPED (not a publish-grade build)"
else
    echo "==> clean-room gate: run the tarball's compiler output in bsnes-jg (METHOD=local)"
    if ! "$ROOT/dev/test-release.sh" METHOD=local TARBALL="$DIST_DIR/$NAME.tar.xz"; then
        echo "FATAL: clean-room release test FAILED — the published artifact does not build a correct ROM." >&2
        echo "  tarball stays at $DIST_DIR/$NAME.tar.xz but is NOT a publish candidate. Do not upload it." >&2
        exit 1
    fi
    # Keep the verification report alongside the release artifact (embeds the log +
    # screenshots + package/docs details — see dev/release-report.py). Both forms:
    # the self-contained .html and the .md (previews via `task md`, feeds the PDF pipeline).
    REPORT_SRC="$ROOT/build/release-test/release-report-latest.html"
    if [[ -f "$REPORT_SRC" ]]; then
        cp -f "$REPORT_SRC" "$DIST_DIR/$NAME-release-report.html"
        echo "==> release report: $DIST_DIR/$NAME-release-report.html"
        # The .md sibling sits next to the timestamped .html (not the -latest pointer);
        # find the newest local report's .md and copy it too.
        REPORT_MD="$(ls -t "$ROOT"/build/release-test/release-report-*-local-*.md 2>/dev/null | head -1 || true)"
        [[ -n "$REPORT_MD" && -f "$REPORT_MD" ]] && cp -f "$REPORT_MD" "$DIST_DIR/$NAME-release-report.md"
    fi
fi

SIZE="$(du -h "$DIST_DIR/$NAME.tar.xz" | cut -f1)"
SHA256="$(cut -d' ' -f1 < "$DIST_DIR/$NAME.tar.xz.sha256")"
REPORT_NOTE=""
[[ -f "$DIST_DIR/$NAME-release-report.html" ]] && REPORT_NOTE="
    report:  $DIST_DIR/$NAME-release-report.html"
cat <<EOF

==> done  (warning-free self-test + clean-room emulator gate both PASSED)
    tree:    $STAGE  ($(du -sh "$STAGE" | cut -f1))
    tarball: $DIST_DIR/$NAME.tar.xz  ($SIZE)
    sha256:  $SHA256$REPORT_NOTE

Next (publish to apt.indri.studio):
    task release-upload          # push tarball to r2://indri-apt/sources/
    (cd ../indri.studio/apt && task build && task verify)
EOF
