#!/usr/bin/env bash
# dev/package-release.sh — assemble a relocatable, self-contained distribution of
# the llvm-mos-65816 toolchain (clang + lld + binutils) MERGED with the SNES SDK
# into ONE prefix, and emit a deterministic archive + .sha256.
#
# PLATFORM-parameterized. Only the HOST executables (clang/lld/llvm-*) differ per
# platform; the 65816 TARGET artifacts (MOS compiler-rt builtins, clang resource
# headers, SNES SDK) are host-agnostic and copied ONCE from the canonical native
# Linux build (build/llvm-mos-install + build/install). So a cross package =
# [cross-built host binaries from build/llvm-mos-install-<PLATFORM>] +
# [the identical native target artifacts]. See
# docs/plans/2026-06-25-cross-platform-toolchain-builds.md.
#
#   PLATFORM=linux-x86_64    (default)  native build, run+emulator gate, .tar.xz
#   PLATFORM=linux-arm64                cross (g++-aarch64), qemu self-test, .tar.xz
#   PLATFORM=windows-x86_64             cross (mingw-w64), wine self-test, .zip
#
# This tarball is the human download AND the source the apt .deb repacks
# (apt.indri.studio). It is an interim/preview build, published while the
# #320 (far-pointer) / #321 (16-bit-register) codegen patches are upstreamed.
#
# Inputs (already built):
#   build/llvm-mos-install/             <- dev/run.sh toolchain   (native clang / lld / llvm-*)
#   build/llvm-mos-install-<PLATFORM>/  <- dev/run.sh cross-toolchain <PLATFORM>  (cross host bins)
#   build/install/                      <- dev/run.sh build        (SNES SDK + platforms; host-agnostic)
# Output:
#   dist/llvm-mos-65816-<stamp>-<archtag>.{tar.xz|zip}  (+ .sha256)
#
# Relocatability: the toolchain bin/ and the SDK bin/ (.cfg + mos-*-clang drivers) +
# mos-platform/ are merged into one prefix. The .cfg files are relocatable via clang's
# <CFGDIR> token. A self-test compiles a SNES ROM from the *moved* prefix to prove it
# before packaging (natively, or under qemu/wine for a cross host).

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: dev/package-release.sh [PLATFORM=<p>] [-h]

Assemble dist/llvm-mos-65816-<stamp>-<archtag>.{tar.xz|zip} from the built
toolchain (build/llvm-mos-install[-<PLATFORM>]) + SNES SDK (build/install).

  PLATFORM   linux-x86_64 (default) | linux-arm64 | windows-x86_64

Environment overrides:
  TOOLCHAIN_INSTALL  HOST-binary install prefix   (default build/llvm-mos-install[-<PLATFORM>])
  NATIVE_INSTALL     native toolchain prefix       (default build/llvm-mos-install) — target libs + strip tool
  SDK_INSTALL        SDK install prefix            (default build/install)
  DIST_DIR           output directory              (default dist)
  STAMP              version stamp                  (default <UTC-date>-<short-sha>)
  STRIP              1=strip debug (default), 0=keep
  RELEASE_DOCS_DIR   if set, its contents are copied into <tree>/docs/
  CROSS_SELFTEST     1=run the qemu/wine functional self-test for a cross PLATFORM (default 1)
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

# PLATFORM may arrive as the first positional arg (PLATFORM=x) or the env var.
for a in "$@"; do case "$a" in PLATFORM=*) PLATFORM="${a#PLATFORM=}" ;; esac; done
PLATFORM="${PLATFORM:-linux-x86_64}"

# --- per-platform profile -------------------------------------------------
# ARCH_TAG : the tag in the artifact name (matches the conventional triple form)
# EXE      : executable suffix on the target host ("" / ".exe")
# ARCHIVE  : tarxz | zip
# RUNNER   : how the warning-free self-test runs the produced compiler
#            native | qemu (qemu-aarch64-static) | wine (wine64) — qemu/wine run in the cross image
# CLANG_REAL = the real (non-symlink) clang binary basename in the install. On Linux it's the
# version-suffixed clang-23 (clang is a symlink to it); on a Windows-target install LLVM makes
# clang.exe the real binary and there is NO clang-23.exe.
case "$PLATFORM" in
  linux-x86_64)   PROFILE_SUFFIX="";               ARCH_TAG="linux-x86_64";   EXE="";     ARCHIVE="tarxz"; RUNNER="native"; CLANG_REAL="clang-23" ;;
  linux-arm64)    PROFILE_SUFFIX="-linux-arm64";   ARCH_TAG="linux-aarch64";  EXE="";     ARCHIVE="tarxz"; RUNNER="qemu";   CLANG_REAL="clang-23" ;;
  windows-x86_64) PROFILE_SUFFIX="-windows-x86_64";ARCH_TAG="windows-x86_64"; EXE=".exe"; ARCHIVE="zip";   RUNNER="wine";   CLANG_REAL="clang" ;;
  *) echo "FATAL: unknown PLATFORM '$PLATFORM' (want: linux-x86_64|linux-arm64|windows-x86_64)" >&2; exit 1 ;;
esac
IS_NATIVE=0; [[ "$RUNNER" == "native" ]] && IS_NATIVE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Host binaries come from the per-PLATFORM install; the host-agnostic TARGET artifacts
# (lib/clang builtins+headers) and the multi-format strip tool come from the NATIVE install.
NATIVE_INSTALL="${NATIVE_INSTALL:-$ROOT/build/llvm-mos-install}"
TOOLCHAIN_INSTALL="${TOOLCHAIN_INSTALL:-$ROOT/build/llvm-mos-install${PROFILE_SUFFIX}}"
SDK_INSTALL="${SDK_INSTALL:-$ROOT/build/install}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
STRIP="${STRIP:-1}"
CROSS_SELFTEST="${CROSS_SELFTEST:-1}"
# Bundle the reader docs (.md + .pdf) so they ship with the release and the clean-room
# report can list them. Default: GENERATE them from THIS repo (dev/build-release-docs.sh —
# reproducible, no dependency on the indri.studio sibling). An explicit RELEASE_DOCS_DIR=<path>
# overrides; RELEASE_DOCS_DIR= (empty) disables doc bundling. The `${VAR-__auto__}` form keeps
# the sentinel only when the var is UNSET (so an explicit empty value still disables).
RELEASE_DOCS_DIR="${RELEASE_DOCS_DIR-__auto__}"

# --- preflight -------------------------------------------------------------
[[ -x "$TOOLCHAIN_INSTALL/bin/$CLANG_REAL$EXE" ]] || {
    echo "FATAL: $PLATFORM toolchain not built at $TOOLCHAIN_INSTALL (need bin/$CLANG_REAL$EXE)" >&2
    if [[ "$IS_NATIVE" == 1 ]]; then echo "  build it:  dev/run.sh toolchain" >&2
    else echo "  build it:  dev/run.sh cross-toolchain $PLATFORM" >&2; fi
    exit 1
}
[[ -x "$NATIVE_INSTALL/bin/llvm-objcopy" ]] || {
    echo "FATAL: native toolchain not built at $NATIVE_INSTALL (need bin/llvm-objcopy for strip + target libs)" >&2
    echo "  build it:  dev/run.sh toolchain" >&2
    exit 1
}
[[ -f "$SDK_INSTALL/bin/mos-snes.cfg" ]] || {
    echo "FATAL: SNES SDK not built at $SDK_INSTALL" >&2
    echo "  build it:  MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build" >&2
    exit 1
}
command -v xz >/dev/null || { echo "FATAL: xz not installed" >&2; exit 1; }
[[ "$ARCHIVE" == "zip" ]] && { command -v zip >/dev/null || { echo "FATAL: zip not installed (needed for $PLATFORM)" >&2; exit 1; }; }

# --- stamp / names ---------------------------------------------------------
SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)"
DIRTY=""
if ! git -C "$ROOT" diff --quiet 2>/dev/null || ! git -C "$ROOT" diff --cached --quiet 2>/dev/null; then
    DIRTY="-dirty"
fi
STAMP="${STAMP:-$(date -u +%Y%m%d)-${SHA}${DIRTY}}"
NAME="llvm-mos-65816-${STAMP}-${ARCH_TAG}"
STAGE="$DIST_DIR/$NAME"
SOURCE_EPOCH="$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || echo 0)"

is_elf() { [[ "$(od -An -N4 -tx1 "$1" 2>/dev/null | tr -d ' \n')" == "7f454c46" ]]; }
is_pe()  { [[ "$(od -An -N2 -tx1 "$1" 2>/dev/null | tr -d ' \n')" == "4d5a" ]]; }  # "MZ"

echo "==> staging $NAME  [PLATFORM=$PLATFORM, host bins from $(basename "$TOOLCHAIN_INSTALL"), target libs from $(basename "$NATIVE_INSTALL")]"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/lib"

# --- 1. toolchain HOST bin/ via an ALLOW-LIST ------------------------------
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
if [[ "$EXE" == "" ]]; then
    # Linux host (native or arm64): real binaries + symlinks copied verbatim (cp -a
    # preserves the relative multicall symlinks, which resolve fine on the target).
    for f in "${KEEP_REAL[@]}" "${KEEP_LINKS[@]}"; do
        src="$TOOLCHAIN_INSTALL/bin/$f"
        if [[ -e "$src" || -L "$src" ]]; then
            cp -a "$src" "$STAGE/bin/"
        else
            echo "  WARN: expected toolchain bin/$f missing — skipping" >&2
        fi
    done
else
    # Windows host: the LLVM Windows-target install makes clang.exe the REAL binary (no
    # clang-23.exe) and every multicall name a symlink to it. Symlinks don't survive a zip
    # for Windows users, and clang.exe is ~120 MB stripped — copying all 5 clang aliases +
    # 4 lld aliases would bloat the zip by GBs. So ship a CURATED set: the real binaries +
    # a minimal copy set (the MOS C driver, the linker clang invokes, and binutils aliases).
    # clang/lld dispatch on argv[0], so a renamed copy behaves as that tool. C++ users run
    # `mos-clang.exe --driver-mode=g++`.
    WIN_REAL=( clang lld clang-format
        llvm-ar llvm-cxxfilt llvm-dwarfdump llvm-mc llvm-mlb llvm-nm
        llvm-objcopy llvm-objdump llvm-readobj llvm-size llvm-strings llvm-symbolizer )
    for f in "${WIN_REAL[@]}"; do
        src="$TOOLCHAIN_INSTALL/bin/$f$EXE"
        if [[ -f "$src" && ! -L "$src" ]]; then cp "$src" "$STAGE/bin/$f$EXE"
        else echo "  WARN: expected real windows bin/$f$EXE missing — skipping" >&2; fi
    done
    # alias .exe → the real .exe it is a copy of (resolves the install's symlink intent)
    declare -A WIN_COPY=(
        [mos-clang]=clang          [ld.lld]=lld
        [llvm-ranlib]=llvm-ar      [llvm-strip]=llvm-objcopy
        [llvm-readelf]=llvm-readobj [llvm-addr2line]=llvm-symbolizer
    )
    for name in "${!WIN_COPY[@]}"; do
        tgt="$STAGE/bin/${WIN_COPY[$name]}$EXE"
        if [[ -f "$tgt" ]]; then cp "$tgt" "$STAGE/bin/$name$EXE"
        else echo "  WARN: cannot make windows $name$EXE (target ${WIN_COPY[$name]}$EXE absent)" >&2; fi
    done
    # mingw runtime DLLs the produced .exe link against (posix-threads libstdc++). Without
    # these alongside the .exe, the compiler won't start on Windows / under wine. dev/cross-
    # toolchain.sh deposits them into the install bin/ (they live only in the cross image).
    shopt -s nullglob
    for dll in "$TOOLCHAIN_INSTALL"/bin/*.dll; do cp "$dll" "$STAGE/bin/"; done
    shopt -u nullglob
    if ! ls "$STAGE"/bin/*.dll >/dev/null 2>&1; then
        echo "FATAL: no mingw runtime DLLs in $TOOLCHAIN_INSTALL/bin — the .exe won't start." >&2
        echo "  dev/cross-toolchain.sh windows-x86_64 should have copied libstdc++-6/libgcc_s_seh-1/libwinpthread-1." >&2
        exit 1
    fi
fi

# --- 2. clang resource dir (bin/../lib/clang/<ver>) — host-agnostic, from NATIVE ---
# Carries the 65816 compiler-rt builtins + the resource headers; identical for every host.
cp -a "$NATIVE_INSTALL"/lib/clang "$STAGE/lib/"

# --- 3. overlay the SNES SDK into the SAME prefix (host-agnostic) -----------
# .cfg files + mos-*-clang driver names + the platform trees + the SDK cmake package.
cp -a "$SDK_INSTALL"/mos-platform "$STAGE/"
[[ -d "$SDK_INSTALL/lib" ]] && cp -a "$SDK_INSTALL"/lib/. "$STAGE/lib/"
if [[ "$IS_NATIVE" == 1 ]]; then
    # native: copy the whole SDK bin/ verbatim (incl. its x86-64 host helper tools
    # elftocpm65/ft2-* and the mos-*-clang driver symlink matrix). Unchanged behavior.
    cp -a "$SDK_INSTALL"/bin/. "$STAGE/bin/"
else
    # cross: the SDK bin/ also holds x86-64 ELF *host* helper tools (elftocpm65, ft2-*)
    # that can't run on the target host — skip them. Keep the .cfg files (text) and the
    # driver matrix.
    for f in "$SDK_INSTALL"/bin/*; do
        base="$(basename "$f")"
        if [[ "$base" == *.cfg ]]; then
            cp "$f" "$STAGE/bin/"
        elif [[ -L "$f" ]]; then
            # mos-<platform>-clang driver name → mos-clang. On Linux (arm64) keep the
            # symlink (resolves to the arm64 clang). On Windows symlinks don't work and a
            # full per-platform .exe copy matrix would be gigabytes → skip the convenience
            # names; users invoke `mos-clang.exe --config <CFGDIR>/<platform>.cfg`.
            if [[ "$EXE" == "" ]]; then cp -a "$f" "$STAGE/bin/"; fi
        else
            : # real ELF host tool (elftocpm65, ft2-*) → cross can't run it, skip
        fi
    done
fi

# --- 4. strip (clang-23 ships unstripped ~120 MB — the dominant size lever) -
# Always strip with the NATIVE llvm-objcopy (runs on this build host; multi-format:
# handles ELF and PE/COFF) — never the un-runnable cross binary.
if [[ "$STRIP" == "1" ]]; then
    echo "==> stripping binaries with the native llvm-objcopy (multi-format ELF/PE)"
    OBJCOPY="$NATIVE_INSTALL/bin/llvm-objcopy"
    while IFS= read -r -d '' bin; do
        if [[ -f "$bin" && ! -L "$bin" ]] && { is_elf "$bin" || is_pe "$bin"; }; then
            "$OBJCOPY" --strip-unneeded "$bin" 2>/dev/null || true
        fi
    done < <(find "$STAGE/bin" -maxdepth 1 -type f -print0)
fi

# --- 5. structural checks (all platforms) ----------------------------------
if find "$STAGE" -xtype l | grep -q .; then
    echo "FATAL: dangling symlinks in staged tree:" >&2
    find "$STAGE" -xtype l >&2
    exit 1
fi
# Confirm the produced compiler is actually the expected host arch (a stale/native
# clang-23 leaking into a cross package would pass every other check but be useless).
READOBJ="$NATIVE_INSTALL/bin/llvm-readobj"
ARCH_LINE="$("$READOBJ" --file-headers "$STAGE/bin/$CLANG_REAL$EXE" 2>/dev/null | grep -iE 'Arch|Machine|Format' | head -4 || true)"
echo "==> $CLANG_REAL$EXE host arch:"; echo "$ARCH_LINE" | sed 's/^/    /'
case "$PLATFORM" in
  linux-x86_64)   echo "$ARCH_LINE" | grep -qiE 'x86-64|x86_64|elf64-x86-64' || { echo "FATAL: clang-23 is not x86-64 ELF" >&2; exit 1; } ;;
  linux-arm64)    echo "$ARCH_LINE" | grep -qiE 'aarch64|elf64-littleaarch64' || { echo "FATAL: clang-23 is not aarch64 ELF" >&2; exit 1; } ;;
  windows-x86_64) echo "$ARCH_LINE" | grep -qiE 'coff-x86-64|x86-64|pe' || { echo "FATAL: clang.exe is not x86-64 PE/COFF" >&2; exit 1; } ;;
esac

# --- 6. WARNING-FREE self-test (the gate) ----------------------------------
# This is a public release: zero warnings tolerated. Compile a SNES ROM from the
# *moved* prefix, capturing stderr, and fail on a broken prefix OR on any warning.
if [[ "$IS_NATIVE" == 1 ]]; then
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
else
    # Cross host: the produced compiler can't run natively. Compile a reference ROM with
    # the NATIVE toolchain (same codegen), then run the cross compiler under qemu/wine in
    # the cross image and require BYTE-IDENTICAL ROM output + zero warnings. ROM identity
    # transitively inherits the native build's clean-room emulator gate, so the cross
    # package needs no separate emulator run.
    if [[ "$CROSS_SELFTEST" == "1" ]]; then
        echo "==> cross self-test: native reference ROM, then $RUNNER-run the cross compiler and require identical bytes"
        REF_DIR="$(mktemp -d)"; trap 'rm -rf "$REF_DIR"' EXIT
        if ! "$NATIVE_INSTALL/bin/mos-clang" --config "$SDK_INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 \
                -Os -o "$REF_DIR/ref.sfc" "$ROOT/examples/snes/hello.c" 2>"$REF_DIR/ref.err"; then
            echo "FATAL: native reference compile failed (cannot establish the cross identity baseline)" >&2
            sed 's/^/    /' "$REF_DIR/ref.err" >&2; exit 1
        fi
        REF_SHA="$(sha256sum "$REF_DIR/ref.sfc" | cut -d' ' -f1)"
        set +e
        REF_SHA="$REF_SHA" RUNNER="$RUNNER" STAGE_REL="dist/$NAME" \
            "$ROOT/dev/run.sh" cross-selftest "$PLATFORM"
        selftest_st=$?
        set -e
        case "$selftest_st" in
          0) : ;;  # full functional + ROM-byte-identity pass (linux-arm64 under qemu)
          2) # wine cannot run the windows binary (emulator limitation) — structural gate
             # passed in step 5; functional warning-free check deferred to real Windows.
             FUNCTIONAL_DEFERRED=1
             echo "==> windows functional self-test DEFERRED — wine cannot run the binary (see above)." >&2
             echo "    PASSED structurally: correct x86-64 PE, runtime DLLs bundled, no dangling links, the" >&2
             echo "    compiler's front-end runs + resolves its config/resource dirs under wine. Codegen" >&2
             echo "    identity is inherited from the linux-x86_64/arm64 legs (one compiler, one source tree)." >&2
             ;;
          *) echo "FATAL: cross self-test FAILED for $PLATFORM (see above) — not a publish candidate." >&2
             exit 1 ;;
        esac
    else
        echo "==> CROSS_SELFTEST=0 — skipping the qemu/wine functional self-test (NOT a publish-grade build)"
    fi
fi

# --- 7. license + reader docs + generated README ---------------------------
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$STAGE/"
# __auto__ (the unset default): generate the reader docs FROM THIS REPO so the package
# is self-contained (no indri.studio sibling dependency). .md always; .pdf best-effort.
if [[ "$RELEASE_DOCS_DIR" == "__auto__" ]]; then
    echo "==> generating reader docs from this repo (dev/build-release-docs.sh)"
    if "$ROOT/dev/build-release-docs.sh" "$ROOT/build/release-docs" >&2; then
        RELEASE_DOCS_DIR="$ROOT/build/release-docs"
    else
        echo "WARN: reader-doc generation failed — packaging WITHOUT bundled docs" >&2
        RELEASE_DOCS_DIR=""
    fi
fi
if [[ -n "$RELEASE_DOCS_DIR" && -d "$RELEASE_DOCS_DIR" ]]; then
    echo "==> bundling docs from $RELEASE_DOCS_DIR ($(find "$RELEASE_DOCS_DIR" -maxdepth 1 -name '*.md' | wc -l) md, $(find "$RELEASE_DOCS_DIR" -maxdepth 1 -name '*.pdf' | wc -l) pdf)"
    mkdir -p "$STAGE/docs"
    cp -a "$RELEASE_DOCS_DIR"/. "$STAGE/docs/"
fi

# Platform-specific README heading + invocation.
case "$PLATFORM" in
  linux-x86_64)   RM_HOST="Linux x86-64"; RM_BIN="bin/mos-clang";     RM_CFG="bin/mos-snes.cfg" ;;
  linux-arm64)    RM_HOST="Linux arm64 (aarch64)"; RM_BIN="bin/mos-clang"; RM_CFG="bin/mos-snes.cfg" ;;
  windows-x86_64) RM_HOST="Windows x86-64"; RM_BIN="bin\\mos-clang.exe"; RM_CFG="bin\\mos-snes.cfg" ;;
esac
cat > "$STAGE/README.md" <<EOF
# llvm-mos-65816 — interim preview toolchain ($RM_HOST)

An optimizing C cross-compiler for the WDC 65816 (the Super Nintendo's CPU),
built on [llvm-mos](https://github.com/llvm-mos/llvm-mos) with the #320
(far-pointer / 24-bit addressing) and #321 (native 16-bit register) codegen
patches, plus the SNES SDK platform.

**Preview build** — published while those patches are upstreamed. Once they land
in upstream llvm-mos / llvm-mos-sdk, prefer the upstream releases.

Provenance: llvm-mos-65816 @ ${SHA} · host $RM_HOST · built $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Use it

This tree is relocatable — extract anywhere; keep \`bin/\` and \`mos-platform/\`
as siblings. Compile a SNES ROM:

\`\`\`sh
$RM_BIN --config $RM_CFG -mcpu=mosw65816 -Os -o hello.sfc hello.c
\`\`\`

Opt into the native 16-bit codegen (the point of this fork):

\`\`\`sh
$RM_BIN --config $RM_CFG -mcpu=mosw65816 \\
    -Xclang -target-feature -Xclang +mos-a16 \\
    -Xclang -target-feature -Xclang +mos-xy16 \\
    -Os -o hello.sfc hello.c
\`\`\`
EOF
if [[ "$PLATFORM" == "windows-x86_64" ]]; then
cat >> "$STAGE/README.md" <<'EOF'

> **Windows note.** The per-platform convenience drivers (`mos-snes-clang.exe`, …)
> are not shipped; invoke `mos-clang.exe --config bin\<platform>.cfg` instead. For C++,
> add `--driver-mode=g++`. The bundled `*.dll` (libstdc++/libgcc/libwinpthread) must stay
> next to the `.exe`.
EOF
fi
cat >> "$STAGE/README.md" <<EOF

Licensed Apache-2.0 with LLVM exceptions — see \`LICENSE\` / \`NOTICE\`.
EOF

# --- 8. deterministic archive + checksum -----------------------------------
echo "==> packaging ($ARCHIVE)"
if [[ "$ARCHIVE" == "zip" ]]; then
    ARCHFILE="$NAME.zip"
    ( cd "$DIST_DIR" && rm -f "$ARCHFILE" && find "$NAME" -print | sort | zip -q -X -9 "$ARCHFILE" -@ )
else
    ARCHFILE="$NAME.tar.xz"
    ( cd "$DIST_DIR" \
      && XZ_OPT="-9e" tar \
            --sort=name --mtime="@${SOURCE_EPOCH}" \
            --owner=0 --group=0 --numeric-owner \
            -cJf "$ARCHFILE" "$NAME" )
fi
( cd "$DIST_DIR" && sha256sum "$ARCHFILE" > "$ARCHFILE.sha256" )

# --- 9. clean-room PUBLISH GATE (native only) ------------------------------
# The warning-free self-test above proves the relocated prefix links cleanly; this
# proves the published artifact actually BOOTS and COMPUTES correctly in bsnes-jg. It
# runs only for the NATIVE package: a cross package's ROM output is proven byte-identical
# to the native compiler's in step 6, so it inherits this gate transitively. Override
# (NOT for a real release) with SKIP_RELEASE_TEST=1; if Docker is absent the gate FAILS.
if [[ "$IS_NATIVE" == 1 && "${SKIP_RELEASE_TEST:-0}" != "1" ]]; then
    echo "==> clean-room gate: run the tarball's compiler output in bsnes-jg (METHOD=local)"
    if ! "$ROOT/dev/test-release.sh" METHOD=local TARBALL="$DIST_DIR/$ARCHFILE"; then
        echo "FATAL: clean-room release test FAILED — the published artifact does not build a correct ROM." >&2
        echo "  tarball stays at $DIST_DIR/$ARCHFILE but is NOT a publish candidate. Do not upload it." >&2
        exit 1
    fi
    # Keep the verification report alongside the release artifact (embeds the log +
    # screenshots + package/docs details — see dev/release-report.py). Both forms:
    # the self-contained .html and the .md (previews via `task md`, feeds the PDF pipeline).
    REPORT_SRC="$ROOT/build/release-test/release-report-latest.html"
    if [[ -f "$REPORT_SRC" ]]; then
        cp -f "$REPORT_SRC" "$DIST_DIR/$NAME-release-report.html"
        echo "==> release report: $DIST_DIR/$NAME-release-report.html"
        REPORT_MD="$(ls -t "$ROOT"/build/release-test/release-report-*-local-*.md 2>/dev/null | head -1 || true)"
        [[ -n "$REPORT_MD" && -f "$REPORT_MD" ]] && cp -f "$REPORT_MD" "$DIST_DIR/$NAME-release-report.md"
    fi
elif [[ "$IS_NATIVE" != 1 ]]; then
    echo "==> cross package: skipping the bsnes emulator gate (ROM byte-identity to native in step 6 covers it)"
fi

SIZE="$(du -h "$DIST_DIR/$ARCHFILE" | cut -f1)"
SHA256="$(cut -d' ' -f1 < "$DIST_DIR/$ARCHFILE.sha256")"
REPORT_NOTE=""
[[ -f "$DIST_DIR/$NAME-release-report.html" ]] && REPORT_NOTE="
    report:  $DIST_DIR/$NAME-release-report.html"
if [[ "${FUNCTIONAL_DEFERRED:-0}" == 1 ]]; then
    DONE_NOTE="structural gate passed; functional warning-free check DEFERRED to real Windows (wine can't run the binary)"
else
    DONE_NOTE="self-test passed"
fi
cat <<EOF

==> done  ($PLATFORM — $DONE_NOTE)
    tree:    $STAGE  ($(du -sh "$STAGE" | cut -f1))
    archive: $DIST_DIR/$ARCHFILE  ($SIZE)
    sha256:  $SHA256$REPORT_NOTE
EOF
[[ "${FUNCTIONAL_DEFERRED:-0}" == 1 ]] && cat <<EOF
    ⚠ BEFORE PUBLISHING $ARCH_TAG: run  mos-clang.exe --config bin\\mos-snes.cfg -Os examples/snes/hello.c
      on real Windows and confirm a warning-free SNES ROM. (Codegen is identical to the linux
      builds by construction; this confirms the binary runs natively, which wine cannot verify.)
EOF
if [[ "$IS_NATIVE" == 1 ]]; then cat <<EOF

Next (publish to apt.indri.studio):
    task release-upload          # push tarball to r2://indri-apt/sources/
    (cd ../indri.studio/apt && task build && task verify)
EOF
fi
