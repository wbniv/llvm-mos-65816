#!/usr/bin/env bash
# dev/ci-watch.sh — live, visible monitor for a GitHub Actions run (host-side; uses gh).
#
# Streams a timestamped milestone line on every job/step transition (started / ✓ / ✗),
# emits a heartbeat while a long step runs (so a 90-min toolchain build still shows life),
# and exits with the run's conclusion (0 = success, 1 = otherwise). Prints an opening
# snapshot + the web-UI URL — GitHub exposes in-progress step *logs* only in that UI
# (the REST/CLI log endpoints 404 until a job completes), so this tracks structure, not log text.
#
# Meant to be backgrounded by an agent (run_in_background) or watched in a terminal.
#   dev/ci-watch.sh                 # latest run of $WORKFLOW (default snes-smoke)
#   dev/ci-watch.sh <RUN_ID>        # a specific run
#   dev/ci-watch.sh --once [RUN_ID] # one snapshot, no loop
# Env: WORKFLOW (default snes-smoke) · INTERVAL secs (default 30) · HEARTBEAT secs (default 300).
set -euo pipefail

usage() { grep '^#' "$0" | sed 's/^# \?//'; exit 0; }
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

WORKFLOW="${WORKFLOW:-snes-smoke}"; INTERVAL="${INTERVAL:-30}"; HEARTBEAT="${HEARTBEAT:-300}"
once=0; [ "${1:-}" = "--once" ] && { once=1; shift; }
command -v gh >/dev/null || { echo "ci-watch: gh not found"; exit 2; }

RID="${1:-}"
[ -n "$RID" ] || RID="$(gh run list --workflow="$WORKFLOW" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
[ -n "${RID:-}" ] || { echo "ci-watch: no run found for workflow '$WORKFLOW'"; exit 1; }

epoch() { { [ -n "${1:-}" ] && [ "$1" != "null" ] && date -d "$1" +%s 2>/dev/null; } || echo 0; }
hms() { local s=${1:-0}; [ "$s" -lt 0 ] && s=0
        if [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s/3600)) $(((s%3600)/60)); else printf '%dm%02ds' $((s/60)) $((s%60)); fi; }
icon() { case "$1" in  # status conclusion
  completed) case "${2:-}" in success) printf '\033[32m✓\033[0m';; skipped) printf '\033[90m⊘\033[0m';;
                               cancelled) printf '\033[31m⏹\033[0m';; *) printf '\033[31m✗\033[0m';; esac;;
  in_progress) printf '\033[33m⏳\033[0m';; *) printf '\033[90m·\033[0m';; esac; }

START_E=$(epoch "$(gh run view "$RID" --json createdAt --jq .createdAt 2>/dev/null)")
URL="$(gh run view "$RID" --json url --jq .url 2>/dev/null)"
echo "ci-watch: run $RID ($WORKFLOW) — live step logs: $URL"

declare -A prev; first=1; last_out=$(date +%s)
while :; do
  now=$(date +%s); el=$(( now - START_E ))
  data="$(gh run view "$RID" --json status,conclusion,jobs --jq '
    "RUN\t\(.status)\t\(.conclusion // "")",
    (.jobs[] as $j | $j.steps[] | "STEP\t\($j.name)\t\(.number)\t\(.name)\t\(.status)\t\(.conclusion // "")\t\(.startedAt // "")\t\(.completedAt // "")")
  ' 2>/dev/null || true)"
  [ -n "$data" ] || { sleep "$INTERVAL"; continue; }

  rstatus=""; rconcl=""; changed=0
  while IFS=$'\t' read -r kind job num name st cc t0 t1; do
    [ "$kind" = "RUN" ] && { rstatus="$job"; rconcl="$num"; continue; }   # RUN row: job=status, num=concl
    key="$job#$num"; state="$st/$cc"
    if [ "$first" -eq 0 ] && [ "${prev[$key]:-}" != "$state" ]; then
      if [ "$st" = "in_progress" ]; then
        printf '[+%s] %s ▸ %s  %s started\n' "$(hms $el)" "$job" "$name" "$(icon "$st" "$cc")"; changed=1; last_out=$now
      elif [ "$st" = "completed" ]; then
        printf '[+%s] %s ▸ %s  %s %s (%s)\n' "$(hms $el)" "$job" "$name" "$(icon "$st" "$cc")" "$cc" "$(hms $(( $(epoch "$t1") - $(epoch "$t0") )))"; changed=1; last_out=$now
      fi
    fi
    prev[$key]="$state"
  done <<< "$data"

  if [ "$first" -eq 1 ]; then
    echo "── snapshot [+$(hms $el)] ──────────────────────────────"
    printf '%s\n' "$data" | awk -F'\t' '$1=="STEP"{printf "  %-8s %2d. %s [%s%s]\n",$2,$3,$4,$5,($6==""?"":" "$6)}'
    echo "────────────────────────────────────────────────────────"
    first=0
  fi

  if [ "$rstatus" = "completed" ]; then
    echo; echo "═══ RUN COMPLETE [+$(hms $el)]  $(icon completed "$rconcl") ${rconcl:-?} ═══"
    gh run view "$RID" --json jobs --jq '.jobs[] | "\(.conclusion)\t\(.name)"' 2>/dev/null \
      | while IFS=$'\t' read -r c n; do printf '  %s %s (%s)\n' "$(icon completed "$c")" "$n" "$c"; done
    [ "$rconcl" = "success" ] && exit 0 || exit 1
  fi
  [ "$once" -eq 1 ] && exit 0

  if [ "$changed" -eq 0 ] && [ $(( now - last_out )) -ge "$HEARTBEAT" ]; then
    active="$(printf '%s\n' "$data" | awk -F'\t' '$1=="STEP"&&$5=="in_progress"{print $2" ▸ "$4; exit}')"
    printf '[+%s] … still running: %s\n' "$(hms $el)" "${active:-(between steps)}"; last_out=$now
  fi
  sleep "$INTERVAL"
done
