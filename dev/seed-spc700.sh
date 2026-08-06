#!/usr/bin/env bash
set -euo pipefail

PARAMETER="${SPC700_SSM_PARAMETER:-/llvm-mos-65816/snes/spc700_ipl_b64}"
REGION="${SPC700_AWS_REGION:-us-west-2}"
PROFILE="${SPC700_AWS_PROFILE:-65816-terraform}"
EXPECTED_SIZE=64
EXPECTED_SHA1=97e352553e94242ae823547cd853eecda55c20f0

usage() {
  cat <<'EOF'
Usage: dev/seed-spc700.sh [--force] ROM

Validate a 64-byte SPC700 IPL and store its base64 representation as the
SecureString /llvm-mos-65816/snes/spc700_ipl_b64 in us-west-2. Refuses to
overwrite an existing parameter unless --force is supplied.

Environment: SPC700_AWS_PROFILE (default 65816-terraform),
SPC700_AWS_REGION (default us-west-2), SPC700_SSM_PARAMETER.
EOF
}

force=0
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --force) force=1; shift ;;
esac
[ "$#" = 1 ] || { usage >&2; exit 2; }
rom="$1"
[ -f "$rom" ] || { echo "FATAL: ROM not found: $rom" >&2; exit 1; }
size="$(wc -c <"$rom" | tr -d ' ')"
[ "$size" = "$EXPECTED_SIZE" ] || {
  echo "FATAL: $rom is $size B, expected $EXPECTED_SIZE B; SSM was not changed." >&2; exit 1;
}
if command -v sha1sum >/dev/null 2>&1; then
  actual_sha1="$(sha1sum "$rom" | awk '{print $1}')"
else
  actual_sha1="$(shasum -a 1 "$rom" | awk '{print $1}')"
fi
[ "$actual_sha1" = "$EXPECTED_SHA1" ] || {
  echo "FATAL: $rom has sha1 $actual_sha1, expected $EXPECTED_SHA1; SSM was not changed." >&2; exit 1;
}

command -v aws >/dev/null 2>&1 || { echo "FATAL: AWS CLI not found." >&2; exit 1; }
if ! aws configure list-profiles 2>/dev/null | grep -Fxq "$PROFILE"; then
  echo "FATAL: AWS profile '$PROFILE' not found; set SPC700_AWS_PROFILE if needed." >&2
  exit 1
fi

if [ "$force" = 0 ]; then
  set +e
  lookup="$(aws --profile "$PROFILE" --region "$REGION" ssm get-parameter \
    --name "$PARAMETER" --query Parameter.Name --output text 2>&1)"
  rc=$?
  set -e
  if [ "$rc" = 0 ]; then
    echo "FATAL: parameter $PARAMETER already exists; use --force to overwrite it." >&2
    exit 1
  fi
  if ! printf '%s' "$lookup" | grep -q 'ParameterNotFound'; then
    echo "FATAL: could not check whether $PARAMETER exists: $lookup" >&2
    exit 1
  fi
fi

value="$(base64 <"$rom" | tr -d '\n')"
args=(--name "$PARAMETER" --type SecureString --value "$value")
[ "$force" = 0 ] || args+=(--overwrite)
aws --profile "$PROFILE" --region "$REGION" ssm put-parameter "${args[@]}" >/dev/null
echo "PASS: seeded $PARAMETER ($REGION, profile $PROFILE; 64 B, sha1 $EXPECTED_SHA1)"
