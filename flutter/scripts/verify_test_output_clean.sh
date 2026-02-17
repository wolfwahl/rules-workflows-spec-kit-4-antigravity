#!/usr/bin/env bash
set -euo pipefail

LOG_FILE=""

usage() {
  cat <<'USAGE'
Usage: ./scripts/verify_test_output_clean.sh --log <file>

Checks test logs for known runtime warning noise that must not appear in a
"10/10" quality run.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log)
      LOG_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[test-output-clean] ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$LOG_FILE" ]]; then
  echo "[test-output-clean] ERROR: --log is required." >&2
  exit 2
fi

if [[ ! -f "$LOG_FILE" ]]; then
  echo "[test-output-clean] ERROR: log file not found: $LOG_FILE" >&2
  exit 1
fi

declare -a patterns=(
  'WARNING \(drift\):'
  'This warning will only appear on debug builds\.'
)

issues=0
for pattern in "${patterns[@]}"; do
  if rg -n "$pattern" "$LOG_FILE" >/dev/null; then
    issues=$((issues + 1))
    echo "[test-output-clean] ERROR: found warning pattern: $pattern" >&2
    rg -n "$pattern" "$LOG_FILE" | sed -n '1,20p' >&2
  fi
done

if [[ $issues -gt 0 ]]; then
  echo "[test-output-clean] ERROR: runtime warning noise detected in test output." >&2
  exit 1
fi

echo "[test-output-clean] OK"
