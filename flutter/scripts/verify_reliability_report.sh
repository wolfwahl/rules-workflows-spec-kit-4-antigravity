#!/usr/bin/env bash
set -euo pipefail

REPORT_FILE=".specification/2026-02-11-17-35_Security-Reliability-Hardening/23_Reliability_Operational_Report.md"
FAIL_ON_UNKNOWN="false"

usage() {
  cat <<'EOF'
Usage: ./scripts/verify_reliability_report.sh [--report <file>] [--fail-on-unknown <true|false>]

Validates reliability report status markers:
- always fails on ALERT
- optionally fails on UNKNOWN (default: false)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)
      REPORT_FILE="${2:-}"
      shift 2
      ;;
    --fail-on-unknown)
      FAIL_ON_UNKNOWN="${2:-false}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$REPORT_FILE" ]]; then
  echo "[reliability-verify] ERROR: report file not found: $REPORT_FILE" >&2
  exit 1
fi

alert_count="$(
  grep -E '\|[[:space:]]*ALERT[[:space:]]*\|' "$REPORT_FILE" | wc -l | tr -d ' ' || true
)"
unknown_count="$(
  grep -E '\|[[:space:]]*UNKNOWN[[:space:]]*\|' "$REPORT_FILE" | wc -l | tr -d ' ' || true
)"

alert_count="${alert_count:-0}"
unknown_count="${unknown_count:-0}"

echo "[reliability-verify] Report: $REPORT_FILE"
echo "[reliability-verify] ALERT count: $alert_count"
echo "[reliability-verify] UNKNOWN count: $unknown_count"

if [[ "$alert_count" -gt 0 ]]; then
  echo "[reliability-verify] ERROR: reliability report contains ALERT status." >&2
  exit 1
fi

if [[ "$FAIL_ON_UNKNOWN" == "true" && "$unknown_count" -gt 0 ]]; then
  echo "[reliability-verify] ERROR: reliability report contains UNKNOWN status and strict mode is enabled." >&2
  exit 1
fi

if [[ "$unknown_count" -gt 0 ]]; then
  echo "[reliability-verify] WARNING: report contains UNKNOWN status (strict mode disabled)." >&2
fi

echo "[reliability-verify] OK"
