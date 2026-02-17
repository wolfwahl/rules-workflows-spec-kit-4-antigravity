#!/usr/bin/env bash
set -euo pipefail

TARGETS_FILE="ops/testing/mutation_targets.txt"
EXCLUDES_FILE="ops/testing/mutation_exclude_mutants.txt"
QUALITY_GATES_FILE="ops/testing/quality_gates.env"
QUALITY_SNAPSHOT_FILE=""
REPORT_FILE=""
MAX_MUTANTS_PER_FILE=4
PER_MUTANT_TIMEOUT_SECONDS=45
MAX_RUNTIME_SECONDS=300
FAIL_ON_THRESHOLD="true"
OPERATOR_PROFILE="stable"

MIN_MUTATION_SCORE_PCT=75
MIN_HIGH_RISK_MUTATION_SCORE_PCT=85

usage() {
  cat <<'EOF'
Usage: ./scripts/run_mutation_gate.sh [options]

Options:
  --targets <file>             Mutation target mapping file (source|test_command)
  --excludes <file>            Optional exclude list (source|line|reason)
  --quality-gates <file>       Quality gate env file (defaults to ops/testing/quality_gates.env)
  --quality-snapshot <file>    Optional quality snapshot env (contains HIGH_RISK_MODULES=...)
  --report <file>              Markdown report output
  --max-mutants-per-file <n>   Max sampled mutants per file (default: 4)
  --timeout-seconds <n>        Per-mutant test timeout (default: 45)
  --max-runtime-seconds <n>    Total mutation runtime budget (default: 300)
  --operator-profile <mode>    Mutation operator profile: stable|strict (default: stable)
  --no-threshold-fail          Do not fail on threshold violations
  -h, --help                   Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets)
      TARGETS_FILE="${2:-}"
      shift 2
      ;;
    --excludes)
      EXCLUDES_FILE="${2:-}"
      shift 2
      ;;
    --quality-gates)
      QUALITY_GATES_FILE="${2:-}"
      shift 2
      ;;
    --quality-snapshot)
      QUALITY_SNAPSHOT_FILE="${2:-}"
      shift 2
      ;;
    --report)
      REPORT_FILE="${2:-}"
      shift 2
      ;;
    --max-mutants-per-file)
      MAX_MUTANTS_PER_FILE="${2:-4}"
      shift 2
      ;;
    --timeout-seconds)
      PER_MUTANT_TIMEOUT_SECONDS="${2:-45}"
      shift 2
      ;;
    --max-runtime-seconds)
      MAX_RUNTIME_SECONDS="${2:-300}"
      shift 2
      ;;
    --operator-profile)
      OPERATOR_PROFILE="${2:-stable}"
      shift 2
      ;;
    --no-threshold-fail)
      FAIL_ON_THRESHOLD="false"
      shift
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

if [[ ! -f "$TARGETS_FILE" ]]; then
  echo "[mutation-gate] ERROR: targets file not found: $TARGETS_FILE" >&2
  exit 1
fi

if [[ -f "$QUALITY_GATES_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$QUALITY_GATES_FILE"
fi

if [[ -n "$QUALITY_SNAPSHOT_FILE" && -f "$QUALITY_SNAPSHOT_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$QUALITY_SNAPSHOT_FILE"
fi

if [[ -z "${REPORT_FILE:-}" ]]; then
  ts="$(date -u +'%Y%m%d-%H%M%S')"
  REPORT_FILE=".ciReport/mutation_gate_${ts}.md"
fi
mkdir -p "$(dirname "$REPORT_FILE")"

if [[ -n "${MAX_MUTATION_RUNTIME_SECONDS:-}" ]]; then
  MAX_RUNTIME_SECONDS="$MAX_MUTATION_RUNTIME_SECONDS"
fi

if ! [[ "$MAX_MUTANTS_PER_FILE" =~ ^[0-9]+$ ]]; then
  echo "[mutation-gate] ERROR: --max-mutants-per-file must be numeric." >&2
  exit 1
fi
if ! [[ "$PER_MUTANT_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "[mutation-gate] ERROR: --timeout-seconds must be numeric." >&2
  exit 1
fi
if ! [[ "$MAX_RUNTIME_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "[mutation-gate] ERROR: --max-runtime-seconds must be numeric." >&2
  exit 1
fi
if [[ "$OPERATOR_PROFILE" != "stable" && "$OPERATOR_PROFILE" != "strict" ]]; then
  echo "[mutation-gate] ERROR: --operator-profile must be stable or strict." >&2
  exit 1
fi

if [[ -z "${HIGH_RISK_MODULES:-}" ]]; then
  HIGH_RISK_MODULES="$(awk -F'|' '!/^[[:space:]]*#/ && NF >= 1 {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); if ($1 != "") print $1}' "$TARGETS_FILE" | head -n 3 | paste -sd, -)"
fi

runner=("dart" "run")
if ! "${runner[@]}" --version >/dev/null 2>&1; then
  runner=("./scripts/flutterw.sh" "pub" "run")
fi

cmd=(
  "${runner[@]}"
  tool/mutation/ast_mutation_gate.dart
  --targets
  "$TARGETS_FILE"
  --report
  "$REPORT_FILE"
  --max-mutants-per-file
  "$MAX_MUTANTS_PER_FILE"
  --timeout-seconds
  "$PER_MUTANT_TIMEOUT_SECONDS"
  --max-runtime-seconds
  "$MAX_RUNTIME_SECONDS"
  --high-risk-modules
  "${HIGH_RISK_MODULES:-}"
  --operator-profile
  "$OPERATOR_PROFILE"
  --min-mutation-score
  "${MIN_MUTATION_SCORE_PCT:-75}"
  --min-high-risk-score
  "${MIN_HIGH_RISK_MUTATION_SCORE_PCT:-85}"
  --fail-on-threshold
  "$FAIL_ON_THRESHOLD"
)

if [[ -f "$EXCLUDES_FILE" ]]; then
  cmd+=(--excludes "$EXCLUDES_FILE")
fi

"${cmd[@]}"
