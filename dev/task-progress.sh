#!/usr/bin/env bash
# Descriptor 3 keeps progress visible through command substitutions and log capture.
if [ -z "${TASK_PROGRESS_FD:-}" ]; then
  exec 3>&2
  export TASK_PROGRESS_FD=3
fi
export JGX_PROGRESS_FD="$TASK_PROGRESS_FD"
export TASK_PROGRESS_STARTED="${TASK_PROGRESS_STARTED:-$(date +%s)}"
TASK_PROGRESS_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/task_progress.py"
if [ ! -f "$TASK_PROGRESS_PY" ]; then
  TASK_PROGRESS_PY="$(dirname "$TASK_PROGRESS_PY")/../tools/task_progress.py"
fi
task_progress() {
  python3 "$TASK_PROGRESS_PY" --total "$1" --done "$2" --label "$3" --detail "${4:-}"
}
task_clear() {
  if [ -t "$TASK_PROGRESS_FD" ]; then
    printf '\r\033[K' >&"$TASK_PROGRESS_FD"
  fi
}
task_run() {
  local total="$1" completed="$2" label="$3" detail="$4"
  shift 4
  python3 "$TASK_PROGRESS_PY" --total "$total" --done "$completed" \
    --label "$label" --detail "$detail" -- "$@"
}
