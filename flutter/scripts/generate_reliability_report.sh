#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="<path_to>_Reliability_Operational_Report.md"

usage() {
  cat <<'EOF'
Usage: ./scripts/generate_reliability_report.sh [--output <file>]

Generates a reliability operational report from automation inputs.
No manual snapshot file is required.

Input model:
- Auto-detected from repo:
  - app version from pubspec.yaml
- Optional CI/env overrides (all optional):
  - RELIABILITY_SNAPSHOT_UTC
  - RELIABILITY_FLAVOR
  - RELIABILITY_PLATFORM
  - RELIABILITY_TIME_WINDOW
  - RELIABILITY_OPERATIONAL_OWNER
  - RELIABILITY_CRASH_FREE_SESSIONS_PCT
  - RELIABILITY_ERROR_RATE_PER_1K_SESSIONS
  - RELIABILITY_MTTR_SEV2_PLUS_HOURS_30D
  - RELIABILITY_MTTD_MINUTES
  - RELIABILITY_SEV1_OPEN_COUNT ... RELIABILITY_SEV4_OPEN_COUNT
  - RELIABILITY_INCIDENT_REOPEN_RATE_PCT
  - RELIABILITY_INCIDENT_TOTAL_30D
  - RELIABILITY_FLAKY_BACKLOG_COUNT
  - RELIABILITY_CI_FAILURE_RATE_PCT_7D
  - RELIABILITY_CRASHLYTICS_SOURCE
  - RELIABILITY_INCIDENT_SOURCE
  - RELIABILITY_CI_SOURCE
  - RELIABILITY_LOG_SOURCE
  - RELIABILITY_NOTES
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_FILE="${2:-}"
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

generated_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

app_version="$(
  awk '/^version:[[:space:]]*/ {print $2; exit}' pubspec.yaml 2>/dev/null | tr -d '\r'
)"
if [[ -z "${app_version:-}" ]]; then
  app_version="n/a"
fi

SNAPSHOT_UTC="${RELIABILITY_SNAPSHOT_UTC:-$generated_utc}"
APP_VERSION="${RELIABILITY_APP_VERSION:-$app_version}"
FLAVOR="${RELIABILITY_FLAVOR:-prod}"
PLATFORM="${RELIABILITY_PLATFORM:-android,ios}"
TIME_WINDOW="${RELIABILITY_TIME_WINDOW:-24h}"
OPERATIONAL_OWNER="${RELIABILITY_OPERATIONAL_OWNER:-automation}"

CRASH_FREE_SESSIONS_PCT="${RELIABILITY_CRASH_FREE_SESSIONS_PCT:-}"
ERROR_RATE_PER_1K_SESSIONS="${RELIABILITY_ERROR_RATE_PER_1K_SESSIONS:-}"
MTTR_SEV2_PLUS_HOURS_30D="${RELIABILITY_MTTR_SEV2_PLUS_HOURS_30D:-}"
MTTD_MINUTES="${RELIABILITY_MTTD_MINUTES:-}"

SEV1_OPEN_COUNT="${RELIABILITY_SEV1_OPEN_COUNT:-}"
SEV2_OPEN_COUNT="${RELIABILITY_SEV2_OPEN_COUNT:-}"
SEV3_OPEN_COUNT="${RELIABILITY_SEV3_OPEN_COUNT:-}"
SEV4_OPEN_COUNT="${RELIABILITY_SEV4_OPEN_COUNT:-}"
INCIDENT_REOPEN_RATE_PCT="${RELIABILITY_INCIDENT_REOPEN_RATE_PCT:-}"
INCIDENT_TOTAL_30D="${RELIABILITY_INCIDENT_TOTAL_30D:-}"

FLAKY_BACKLOG_COUNT="${RELIABILITY_FLAKY_BACKLOG_COUNT:-}"
CI_FAILURE_RATE_PCT_7D="${RELIABILITY_CI_FAILURE_RATE_PCT_7D:-}"

CRASHLYTICS_SOURCE="${RELIABILITY_CRASHLYTICS_SOURCE:-automated source not configured}"
INCIDENT_SOURCE="${RELIABILITY_INCIDENT_SOURCE:-automated source not configured}"
CI_SOURCE="${RELIABILITY_CI_SOURCE:-automated source not configured}"
LOG_SOURCE="${RELIABILITY_LOG_SOURCE:-automated source not configured}"
NOTES="${RELIABILITY_NOTES:-automation-only report generation; external sources pending integration}"

is_number() {
  local value="${1:-}"
  [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

fmt_metric() {
  local value="${1:-}"
  if [[ -z "$value" ]]; then
    echo "n/a"
  else
    echo "$value"
  fi
}

status_compare() {
  local value="$1"
  local operator="$2"
  local threshold="$3"

  if ! is_number "$value"; then
    echo "UNKNOWN"
    return
  fi

  case "$operator" in
    lt)
      if awk "BEGIN {exit !($value < $threshold)}"; then
        echo "ALERT"
      else
        echo "OK"
      fi
      ;;
    gt)
      if awk "BEGIN {exit !($value > $threshold)}"; then
        echo "ALERT"
      else
        echo "OK"
      fi
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac
}

CRASH_FREE_STATUS="N/A"
ERROR_RATE_STATUS="N/A"
MTTR_STATUS="N/A"

if [[ "${FLAVOR}" == "prod" && "${TIME_WINDOW}" == "24h" ]]; then
  CRASH_FREE_STATUS="$(status_compare "${CRASH_FREE_SESSIONS_PCT}" lt 99.5)"
  ERROR_RATE_STATUS="$(status_compare "${ERROR_RATE_PER_1K_SESSIONS}" gt 5)"
fi

MTTR_STATUS="$(status_compare "${MTTR_SEV2_PLUS_HOURS_30D}" gt 24)"

mkdir -p "$(dirname "$OUTPUT_FILE")"

cat >"$OUTPUT_FILE" <<EOF
# Reliability Operational Report (B-006)

## Snapshot

- Snapshot UTC: ${SNAPSHOT_UTC}
- Generated UTC: ${generated_utc}
- Operational Owner: ${OPERATIONAL_OWNER}
- App Version: ${APP_VERSION}
- Flavor: ${FLAVOR}
- Platform: ${PLATFORM}
- Time Window: ${TIME_WINDOW}

## Executive Summary KPIs

| KPI | Value | Target/Threshold | Status |
| :--- | :--- | :--- | :--- |
| Crash-free sessions (%) | $(fmt_metric "${CRASH_FREE_SESSIONS_PCT}") | >= 99.5 (prod, 24h) | ${CRASH_FREE_STATUS} |
| Error rate (per 1k sessions) | $(fmt_metric "${ERROR_RATE_PER_1K_SESSIONS}") | <= 5 (prod, 24h) | ${ERROR_RATE_STATUS} |
| MTTR (SEV-2+, 30d hours) | $(fmt_metric "${MTTR_SEV2_PLUS_HOURS_30D}") | <= 24 (rolling 30d) | ${MTTR_STATUS} |
| MTTD (minutes) | $(fmt_metric "${MTTD_MINUTES}") | Observational | N/A |

## Incident Operations

| Metric | Value |
| :--- | :--- |
| Open SEV-1 incidents | $(fmt_metric "${SEV1_OPEN_COUNT}") |
| Open SEV-2 incidents | $(fmt_metric "${SEV2_OPEN_COUNT}") |
| Open SEV-3 incidents | $(fmt_metric "${SEV3_OPEN_COUNT}") |
| Open SEV-4 incidents | $(fmt_metric "${SEV4_OPEN_COUNT}") |
| Incident reopen rate (%) | $(fmt_metric "${INCIDENT_REOPEN_RATE_PCT}") |
| Total incidents (30d) | $(fmt_metric "${INCIDENT_TOTAL_30D}") |

## Quality Signal Health

| Metric | Value |
| :--- | :--- |
| Flaky-test backlog count | $(fmt_metric "${FLAKY_BACKLOG_COUNT}") |
| CI failure rate (%) 7d | $(fmt_metric "${CI_FAILURE_RATE_PCT_7D}") |

## Data Sources

- Crashlytics: ${CRASHLYTICS_SOURCE:-n/a}
- Incident tracker / runbook: ${INCIDENT_SOURCE:-n/a}
- CI pipelines: ${CI_SOURCE:-n/a}
- LogService diagnostics: ${LOG_SOURCE:-n/a}

## Notes

${NOTES:-n/a}
EOF

echo "[reliability-report] Generated report: $OUTPUT_FILE"
