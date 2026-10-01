#!/usr/bin/env bash
# Print the SDK-rebuild stamp for a toolchain install prefix: the prefix plus the sha256 of the
# installed clang, llc and lld binaries, on one line:
#
#   /work/build/llvm-mos-install clang=<sha256> llc=<sha256> lld=<sha256>
#
# dev/build.sh compares this against build/.mos-toolchain and wipes the SDK build tree when it
# differs. ninja tracks neither the compiler nor the linker binary, so a path-only stamp left
# build/install holding libraries built by the previous compiler after a toolchain rebuild.
# A missing binary hashes as "absent" (the stamp still changes when it appears).
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: dev/toolchain-stamp.sh [-h|--help] <toolchain-prefix>

Prints "<prefix> clang=<sha256> llc=<sha256> lld=<sha256>" for <prefix>/bin/{clang,llc,lld}
(symlinks are followed, so clang is the clang-23 binary). Used by dev/build.sh as the SDK
rebuild stamp.
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac

PREFIX="$1"
printf '%s' "$PREFIX"
for tool in clang llc lld; do
  f="$PREFIX/bin/$tool"
  if [ -f "$f" ]; then h="$(sha256sum "$f" | cut -d' ' -f1)"; else h=absent; fi
  printf ' %s=%s' "$tool" "$h"
done
printf '\n'
