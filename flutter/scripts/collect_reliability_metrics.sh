#!/usr/bin/env bash
set -euo pipefail

OUTPUT_ENV_FILE="ops/reliability/reliability_snapshot.auto.env"
WORKFLOW_FILE="flutter-ci.yml"
CI_WINDOW_DAYS=7
INCIDENT_WINDOW_DAYS=30

usage() {
  cat <<'EOF'
Usage: ./scripts/collect_reliability_metrics.sh [options]

Collects reliability metrics from GitHub APIs and writes shell-compatible
RELIABILITY_* variables to an env file.

Options:
  --output-env-file <file>   Output env file (default: ops/reliability/reliability_snapshot.auto.env)
  --workflow-file <file>     Workflow file name for CI failure rate lookup (default: flutter-ci.yml)
  --ci-window-days <days>    Rolling window for CI rate (default: 7)
  --incident-window-days <days> Rolling window for incident stats (default: 30)

Notes:
- Requires curl. jq enables live GitHub metric parsing.
- Uses GITHUB_TOKEN when available. Without token, falls back to UNKNOWN values.
- When running in GitHub Actions, writes collected vars to GITHUB_ENV as well.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-env-file)
      OUTPUT_ENV_FILE="${2:-}"
      shift 2
      ;;
    --workflow-file)
      WORKFLOW_FILE="${2:-}"
      shift 2
      ;;
    --ci-window-days)
      CI_WINDOW_DAYS="${2:-}"
      shift 2
      ;;
    --incident-window-days)
      INCIDENT_WINDOW_DAYS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[reliability-collect] Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$CI_WINDOW_DAYS" =~ ^[0-9]+$ ]] || ! [[ "$INCIDENT_WINDOW_DAYS" =~ ^[0-9]+$ ]]; then
  echo "[reliability-collect] ERROR: window values must be integers." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[reliability-collect] ERROR: curl is required." >&2
  exit 1
fi

HAS_JQ="false"
if command -v jq >/dev/null 2>&1; then
  HAS_JQ="true"
else
  echo "[reliability-collect] WARNING: jq is not available; GitHub metric collection is disabled and placeholders will be used."
fi

date_epoch_days_ago() {
  local days="$1"
  if date -u -d "${days} days ago" +%s >/dev/null 2>&1; then
    date -u -d "${days} days ago" +%s
    return
  fi
  if command -v gdate >/dev/null 2>&1; then
    gdate -u -d "${days} days ago" +%s
    return
  fi
  python3 - "$days" <<'PY'
import datetime
import sys
days = int(sys.argv[1])
ts = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
print(int(ts.timestamp()))
PY
}

date_ymd_days_ago() {
  local days="$1"
  if date -u -d "${days} days ago" +"%Y-%m-%d" >/dev/null 2>&1; then
    date -u -d "${days} days ago" +"%Y-%m-%d"
    return
  fi
  if command -v gdate >/dev/null 2>&1; then
    gdate -u -d "${days} days ago" +"%Y-%m-%d"
    return
  fi
  python3 - "$days" <<'PY'
import datetime
import sys
days = int(sys.argv[1])
ts = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
print(ts.strftime("%Y-%m-%d"))
PY
}

urlencode() {
  local raw="${1:-}"
  jq -rn --arg value "$raw" '$value|@uri'
}

git_remote_to_repo() {
  local remote_url="${1:-}"
  local stripped
  stripped="$(printf '%s' "$remote_url" | sed -E 's#^https?://github.com/##; s#^git@github.com:##; s#\\.git$##')"
  printf '%s' "$stripped"
}

resolve_repo() {
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    printf '%s' "$GITHUB_REPOSITORY"
    return
  fi

  local remote_url
  remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [[ -n "$remote_url" ]]; then
    git_remote_to_repo "$remote_url"
    return
  fi

  printf ''
}

REPO_SLUG="$(resolve_repo)"
if [[ -z "$REPO_SLUG" ]]; then
  echo "[reliability-collect] WARNING: Could not resolve GitHub repository; writing source placeholders only."
fi

GH_TOKEN="${GITHUB_TOKEN:-}"

gh_api_get() {
  local endpoint="$1"
  local url="https://api.github.com${endpoint}"

  if [[ -n "$GH_TOKEN" ]]; then
    curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      "$url"
  else
    return 1
  fi
}

search_issues_count() {
  local query="$1"
  local query_encoded
  query_encoded="$(urlencode "$query")"
  gh_api_get "/search/issues?q=${query_encoded}&per_page=1" 2>/dev/null | jq -r '.total_count // 0' || echo ""
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

CI_FAILURE_RATE_PCT_7D=""
FLAKY_BACKLOG_COUNT=""
SEV1_OPEN_COUNT=""
SEV2_OPEN_COUNT=""
SEV3_OPEN_COUNT=""
SEV4_OPEN_COUNT=""
INCIDENT_TOTAL_30D=""
INCIDENT_REOPEN_RATE_PCT=""
MTTR_SEV2_PLUS_HOURS_30D=""

CRASHLYTICS_SOURCE="automated_source_not_configured"
INCIDENT_SOURCE="automated_source_not_configured"
CI_SOURCE="automated_source_not_configured"
LOG_SOURCE="automated_source_not_configured"
NOTES="automation-only report generation; external sources pending integration"

if [[ -n "$REPO_SLUG" && -n "$GH_TOKEN" && "$HAS_JQ" == "true" ]]; then
  ci_cutoff_epoch="$(date_epoch_days_ago "$CI_WINDOW_DAYS")"
  workflow_identifier="$(urlencode "$WORKFLOW_FILE")"
  ci_runs_json="$(gh_api_get "/repos/${REPO_SLUG}/actions/workflows/${workflow_identifier}/runs?per_page=100" 2>/dev/null || true)"
  if [[ -n "$ci_runs_json" ]]; then
    CI_FAILURE_RATE_PCT_7D="$(
      jq -r --argjson cutoff "$ci_cutoff_epoch" '
        .workflow_runs
        | map(select(.status == "completed"))
        | map(select((.created_at | fromdateiso8601) >= $cutoff))
        | . as $runs
        | ($runs | length) as $total
        | ($runs | map(select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out" or .conclusion == "action_required" or .conclusion == "startup_failure")) | length) as $failed
        | if $total > 0 then (($failed * 100 / $total) | tostring) else "" end
      ' <<<"$ci_runs_json"
    )"
    CI_SOURCE="github_actions_api:${WORKFLOW_FILE}:${CI_WINDOW_DAYS}d"
  fi

  incident_cutoff_date="$(date_ymd_days_ago "$INCIDENT_WINDOW_DAYS")"

  SEV1_OPEN_COUNT="$(search_issues_count "repo:${REPO_SLUG} is:issue is:open label:incident label:sev1")"
  SEV2_OPEN_COUNT="$(search_issues_count "repo:${REPO_SLUG} is:issue is:open label:incident label:sev2")"
  SEV3_OPEN_COUNT="$(search_issues_count "repo:${REPO_SLUG} is:issue is:open label:incident label:sev3")"
  SEV4_OPEN_COUNT="$(search_issues_count "repo:${REPO_SLUG} is:issue is:open label:incident label:sev4")"
  INCIDENT_TOTAL_30D="$(search_issues_count "repo:${REPO_SLUG} is:issue label:incident created:>=${incident_cutoff_date}")"
  FLAKY_BACKLOG_COUNT="$(search_issues_count "repo:${REPO_SLUG} is:issue is:open label:flaky-test")"

  reopened_30d="$(search_issues_count "repo:${REPO_SLUG} is:issue label:incident label:reopened created:>=${incident_cutoff_date}")"
  if [[ -n "${INCIDENT_TOTAL_30D:-}" && -n "${reopened_30d:-}" ]] && awk "BEGIN {exit !(${INCIDENT_TOTAL_30D:-0} > 0)}"; then
    INCIDENT_REOPEN_RATE_PCT="$(awk "BEGIN {printf \"%.2f\", (${reopened_30d:-0} * 100) / ${INCIDENT_TOTAL_30D:-1}}")"
  fi

  closed_sev2_plus_query_encoded="$(
    urlencode "repo:${REPO_SLUG} is:issue is:closed label:incident (label:sev1 OR label:sev2) closed:>=${incident_cutoff_date}"
  )"
  closed_incidents_json="$(gh_api_get "/search/issues?q=${closed_sev2_plus_query_encoded}&per_page=100" 2>/dev/null || true)"
  if [[ -n "$closed_incidents_json" ]]; then
    MTTR_SEV2_PLUS_HOURS_30D="$(
      jq -r '
        .items
        | map(select(.closed_at != null))
        | map(((.closed_at | fromdateiso8601) - (.created_at | fromdateiso8601)) / 3600.0)
        | if length > 0 then (add / length | tostring) else "" end
      ' <<<"$closed_incidents_json"
    )"
  fi

  INCIDENT_SOURCE="github_issues_labels:incident,sev1..sev4,flaky-test:${INCIDENT_WINDOW_DAYS}d"
  LOG_SOURCE="github_issues_and_actions_derived"
  NOTES="automated from GitHub APIs where available; Crashlytics metrics pending telemetry export wiring"
else
  if [[ -z "$GH_TOKEN" ]]; then
    echo "[reliability-collect] WARNING: GITHUB_TOKEN not available; writing source placeholders."
    NOTES="GitHub token missing; report generated with partial automation placeholders"
  elif [[ "$HAS_JQ" != "true" ]]; then
    NOTES="jq missing; report generated with partial automation placeholders"
  fi
fi

mkdir -p "$(dirname "$OUTPUT_ENV_FILE")"

{
  echo "# Auto-generated by scripts/collect_reliability_metrics.sh at $(now_iso)"
  [[ -n "${CI_FAILURE_RATE_PCT_7D:-}" ]] && echo "RELIABILITY_CI_FAILURE_RATE_PCT_7D=${CI_FAILURE_RATE_PCT_7D}"
  [[ -n "${FLAKY_BACKLOG_COUNT:-}" ]] && echo "RELIABILITY_FLAKY_BACKLOG_COUNT=${FLAKY_BACKLOG_COUNT}"
  [[ -n "${SEV1_OPEN_COUNT:-}" ]] && echo "RELIABILITY_SEV1_OPEN_COUNT=${SEV1_OPEN_COUNT}"
  [[ -n "${SEV2_OPEN_COUNT:-}" ]] && echo "RELIABILITY_SEV2_OPEN_COUNT=${SEV2_OPEN_COUNT}"
  [[ -n "${SEV3_OPEN_COUNT:-}" ]] && echo "RELIABILITY_SEV3_OPEN_COUNT=${SEV3_OPEN_COUNT}"
  [[ -n "${SEV4_OPEN_COUNT:-}" ]] && echo "RELIABILITY_SEV4_OPEN_COUNT=${SEV4_OPEN_COUNT}"
  [[ -n "${INCIDENT_REOPEN_RATE_PCT:-}" ]] && echo "RELIABILITY_INCIDENT_REOPEN_RATE_PCT=${INCIDENT_REOPEN_RATE_PCT}"
  [[ -n "${INCIDENT_TOTAL_30D:-}" ]] && echo "RELIABILITY_INCIDENT_TOTAL_30D=${INCIDENT_TOTAL_30D}"
  [[ -n "${MTTR_SEV2_PLUS_HOURS_30D:-}" ]] && echo "RELIABILITY_MTTR_SEV2_PLUS_HOURS_30D=${MTTR_SEV2_PLUS_HOURS_30D}"
  echo "RELIABILITY_CI_SOURCE=${CI_SOURCE}"
  echo "RELIABILITY_INCIDENT_SOURCE=${INCIDENT_SOURCE}"
  echo "RELIABILITY_CRASHLYTICS_SOURCE=${CRASHLYTICS_SOURCE}"
  echo "RELIABILITY_LOG_SOURCE=${LOG_SOURCE}"
  echo "RELIABILITY_NOTES=${NOTES}"
} >"$OUTPUT_ENV_FILE"

if [[ -n "${GITHUB_ENV:-}" && -f "$GITHUB_ENV" ]]; then
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$OUTPUT_ENV_FILE" >>"$GITHUB_ENV"
  echo "[reliability-collect] Exported collected metrics to GITHUB_ENV."
fi

echo "[reliability-collect] Wrote: $OUTPUT_ENV_FILE"
echo "[reliability-collect] CI failure rate 7d: ${CI_FAILURE_RATE_PCT_7D:-n/a}"
echo "[reliability-collect] Flaky backlog: ${FLAKY_BACKLOG_COUNT:-n/a}"
echo "[reliability-collect] Incidents 30d: ${INCIDENT_TOTAL_30D:-n/a}"
