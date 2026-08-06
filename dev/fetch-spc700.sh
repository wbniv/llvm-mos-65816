#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${SNES_ROMPATH:-$ROOT/dev/roms}/s_smp/spc700.rom"
PARAMETER="${SPC700_SSM_PARAMETER:-/llvm-mos-65816/snes/spc700_ipl_b64}"
REGION="${SPC700_AWS_REGION:-us-west-2}"
PROFILE="${SPC700_AWS_PROFILE:-65816-terraform}"
EXPECTED_SIZE=64
EXPECTED_SHA1=97e352553e94242ae823547cd853eecda55c20f0

usage() {
  cat <<'EOF'
Usage: dev/fetch-spc700.sh [--check]

Fetch the gitignored SPC700 IPL from AWS SSM Parameter Store, verify it, and
write it atomically to dev/roms/s_smp/spc700.rom. A valid cached copy causes no
AWS call. --check only validates the local copy and never contacts AWS.

Environment: SPC700_AWS_PROFILE (default 65816-terraform),
SPC700_AWS_REGION (default us-west-2), SPC700_SSM_PARAMETER, SNES_ROMPATH.
EOF
}

sha1_file() {
  if command -v sha1sum >/dev/null 2>&1; then
    sha1sum "$1" | awk '{print $1}'
  else
    shasum -a 1 "$1" | awk '{print $1}'
  fi
}

valid_ipl() {
  [ -f "$1" ] && [ "$(wc -c <"$1" | tr -d ' ')" = "$EXPECTED_SIZE" ] &&
    [ "$(sha1_file "$1")" = "$EXPECTED_SHA1" ]
}

check_only=0
case "${1:-}" in
  "") ;;
  --check) check_only=1 ;;
  -h|--help) usage; exit 0 ;;
  *) echo "FATAL: unknown argument: $1" >&2; usage >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { usage >&2; exit 2; }

if valid_ipl "$DEST"; then
  echo "    ok  SPC700 IPL present and verified (sha1 $EXPECTED_SHA1, 64 B)"
  exit 0
fi

if [ "$check_only" = 1 ]; then
  echo "MISSING OR INVALID: $DEST (expected 64 B, sha1 $EXPECTED_SHA1)" >&2
  exit 1
fi

echo "==> SPC700 IPL missing or invalid — fetching from SSM"
echo "    parameter: $PARAMETER ($REGION, profile $PROFILE)"
command -v aws >/dev/null 2>&1 || {
  echo "    FATAL: AWS CLI not found; install it or supply the IPL out-of-band." >&2
  exit 1
}
if ! aws configure list-profiles 2>/dev/null | grep -Fxq "$PROFILE"; then
  echo "    FATAL: AWS profile '$PROFILE' not found." >&2
  echo "           Configure the project profile or set SPC700_AWS_PROFILE." >&2
  echo "           Stopgap: SPC700_AWS_PROFILE=invest-terraform dev/fetch-spc700.sh" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
tmp="$(mktemp "$(dirname "$DEST")/.spc700.rom.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
value="$(aws --profile "$PROFILE" --region "$REGION" ssm get-parameter \
  --name "$PARAMETER" --with-decryption --query Parameter.Value --output text)"
if ! printf '%s' "$value" | base64 --decode >"$tmp" 2>/dev/null; then
  echo "    FATAL: SSM value is not valid base64 — refusing to write the IPL." >&2
  exit 1
fi
size="$(wc -c <"$tmp" | tr -d ' ')"
if [ "$size" != "$EXPECTED_SIZE" ]; then
  echo "    FATAL: fetched $size B, expected $EXPECTED_SIZE B — refusing to write a partial IPL." >&2
  echo "           The SSM parameter is corrupt; re-seed with dev/seed-spc700.sh." >&2
  exit 1
fi
actual_sha1="$(sha1_file "$tmp")"
if [ "$actual_sha1" != "$EXPECTED_SHA1" ]; then
  echo "    FATAL: fetched sha1 $actual_sha1, expected $EXPECTED_SHA1 — refusing to write." >&2
  exit 1
fi
chmod 0644 "$tmp"
mv -f "$tmp" "$DEST"
trap - EXIT
echo "    wrote ${DEST#"$ROOT/"} (64 B)"
echo "    PASS  sha1 $EXPECTED_SHA1"
