#!/usr/bin/env bash
set -euo pipefail

SKIP_MUTATION="false"
TEN_OF_TEN_MODE="false"
CURRENT_STEP=0
TOTAL_STEPS=14

usage() {
  cat <<'EOF'
Usage: ./scripts/run_local_ci.sh [options]

Options:
  --skip-mutation   Run full local CI checks except mutation gates.
  --ten-of-ten      Run additional flake/stability checks for 10/10 test quality.
  -h, --help        Show help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-mutation)
      SKIP_MUTATION="true"
      shift
      ;;
    --ten-of-ten)
      TEN_OF_TEN_MODE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[local-ci] ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$SKIP_MUTATION" != "true" ]]; then
  TOTAL_STEPS=16
fi
if [[ "$TEN_OF_TEN_MODE" == "true" ]]; then
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi

progress() {
  local message="$1"
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo "[local-ci][${CURRENT_STEP}/${TOTAL_STEPS}] ${message}"
}

timestamp_utc="$(date -u +'%Y%m%d-%H%M%S')"
ci_report_dir=".ciReport"
snapshot_file="${ci_report_dir}/reliability_snapshot_${timestamp_utc}.env"
report_file="${ci_report_dir}/reliability_operational_report_${timestamp_utc}.md"
quality_report_file="${ci_report_dir}/quality_baseline_${timestamp_utc}.md"
quality_snapshot_file="${ci_report_dir}/quality_baseline_snapshot_${timestamp_utc}.env"
quality_risk_csv_file="${ci_report_dir}/quality_risk_ranking_${timestamp_utc}.csv"
quality_deps_csv_file="${ci_report_dir}/quality_dependency_edges_${timestamp_utc}.csv"
mutation_report_file="${ci_report_dir}/mutation_gate_${timestamp_utc}.md"
mutation_strict_report_file="${ci_report_dir}/mutation_gate_strict_${timestamp_utc}.md"
stability_log_file="${ci_report_dir}/test_stability_matrix_${timestamp_utc}.log"

mkdir -p "$ci_report_dir"

progress "Verifying Flutter environment..."
./scripts/verify_flutter_env.sh

progress "Installing dependencies..."
./scripts/flutterw.sh pub get

progress "Enforcing architecture boundaries..."
bash ./scripts/architecture_boundary_audit.sh --fail-on-violations

progress "Checking schema drift..."
bash ./scripts/check_schema_drift.sh

progress "Verifying migrations..."
bash ./scripts/verify_migrations.sh

progress "Running static analysis..."
./scripts/flutterw.sh analyze

progress "Verifying feature test parity..."
bash ./scripts/verify_feature_test_parity.sh

progress "Running tests with coverage..."
./scripts/flutterw.sh test --coverage --branch-coverage

progress "Verifying coverage baseline..."
bash ./scripts/verify_coverage_baseline.sh \
  --lcov coverage/lcov.info \
  --quality-gates ops/testing/quality_gates.env \
  --ratchet-update true

progress "Generating quality baseline report..."
bash ./scripts/generate_quality_baseline_report.sh \
  --lcov coverage/lcov.info \
  --out-md "$quality_report_file" \
  --out-env "$quality_snapshot_file" \
  --out-csv "$quality_risk_csv_file" \
  --out-deps "$quality_deps_csv_file"

progress "Verifying test quality guards..."
bash ./scripts/verify_test_quality_guards.sh \
  --quality-snapshot "$quality_snapshot_file"

if [[ "$TEN_OF_TEN_MODE" == "true" ]]; then
  stability_iterations="$(grep -E '^[[:space:]]*MIN_STABILITY_ITERATIONS=' ops/testing/quality_gates.env | tail -n 1 | cut -d'=' -f2 | tr -d '[:space:]')"
  if [[ -z "${stability_iterations:-}" ]]; then
    stability_iterations="2"
  fi
  stability_concurrency_list="$(grep -E '^[[:space:]]*TEN_OF_TEN_CONCURRENCY_LIST=' ops/testing/quality_gates.env | tail -n 1 | cut -d'=' -f2 | tr -d '[:space:]')"
  if [[ -z "${stability_concurrency_list:-}" ]]; then
    stability_concurrency_list="auto"
  fi

  progress "Running test stability matrix (10/10 mode)..."
  bash ./scripts/run_test_stability_matrix.sh \
    --iterations "$stability_iterations" \
    --concurrency-list "$stability_concurrency_list" \
    --fail-on-warning true \
    --log-file "$stability_log_file"
fi

if [[ "$SKIP_MUTATION" == "true" ]]; then
  echo "[local-ci] Skipping mutation gates (--skip-mutation)."
else
  progress "Running mutation gate..."
  bash ./scripts/run_mutation_gate.sh \
    --quality-snapshot "$quality_snapshot_file" \
    --report "$mutation_report_file"

  progress "Running strict mutation gate (non-blocking thresholds)..."
  bash ./scripts/run_mutation_gate.sh \
    --quality-snapshot "$quality_snapshot_file" \
    --report "$mutation_strict_report_file" \
    --operator-profile strict \
    --no-threshold-fail
fi

progress "Collecting reliability metrics..."
bash ./scripts/collect_reliability_metrics.sh --output-env-file "$snapshot_file"

# Export collected metrics for downstream report generation.
if [[ -f "$snapshot_file" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    export "$key=$value"
  done <"$snapshot_file"
fi

progress "Generating reliability report..."
bash ./scripts/generate_reliability_report.sh --output "$report_file"

progress "Verifying reliability report..."
bash ./scripts/verify_reliability_report.sh --report "$report_file" --fail-on-unknown false

coverage_baseline_file="ops/testing/coverage_baseline.env"
if [[ -f "$coverage_baseline_file" ]]; then
  next_baseline="$(grep -E '^[[:space:]]*MIN_LIB_COVERAGE_PCT=' "$coverage_baseline_file" | tail -n 1 | cut -d'=' -f2 | tr -d '[:space:]')"
  if [[ -n "${next_baseline:-}" ]]; then
    echo "[local-ci] Indicator: next minimum coverage baseline = ${next_baseline}%"
  fi
fi

echo "[local-ci] Reliability snapshot: $snapshot_file"
echo "[local-ci] Reliability report: $report_file"
echo "[local-ci] Quality report: $quality_report_file"
echo "[local-ci] Quality snapshot: $quality_snapshot_file"
echo "[local-ci] Quality risk CSV: $quality_risk_csv_file"
echo "[local-ci] Quality deps CSV: $quality_deps_csv_file"
if [[ "$TEN_OF_TEN_MODE" == "true" ]]; then
  echo "[local-ci] Stability matrix log: $stability_log_file"
fi
if [[ "$SKIP_MUTATION" == "true" ]]; then
  echo "[local-ci] Mutation reports: skipped"
else
  echo "[local-ci] Mutation report: $mutation_report_file"
  echo "[local-ci] Strict mutation report: $mutation_strict_report_file"
fi
echo "[local-ci] OK"
