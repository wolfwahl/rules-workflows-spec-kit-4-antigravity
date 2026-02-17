#!/usr/bin/env bash
set -euo pipefail

ITERATIONS=3
CONCURRENCY_LIST="auto"
RANDOMIZE_ORDER="true"
FAIL_ON_WARNING="true"
LOG_FILE=""

declare -a TARGETS=()

usage() {
  cat <<'USAGE'
Usage: ./scripts/run_test_stability_matrix.sh [options]

Runs flutter tests multiple times across concurrency modes to catch flakes.

Options:
  --iterations <n>              Number of runs per concurrency (default: 3)
  --concurrency-list <csv>      Comma-separated values, e.g. "auto,8"
  --no-randomize-order          Disable randomized test ordering seeds
  --fail-on-warning <true|false>  Enforce clean output via verify_test_output_clean
  --log-file <path>             Write detailed output to this log file
  --target <path>               Test target (repeatable)
  -h, --help                    Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iterations)
      ITERATIONS="${2:-}"
      shift 2
      ;;
    --concurrency-list)
      CONCURRENCY_LIST="${2:-}"
      shift 2
      ;;
    --no-randomize-order)
      RANDOMIZE_ORDER="false"
      shift
      ;;
    --fail-on-warning)
      FAIL_ON_WARNING="${2:-true}"
      shift 2
      ;;
    --log-file)
      LOG_FILE="${2:-}"
      shift 2
      ;;
    --target)
      TARGETS+=("${2:-}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[test-stability] ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$ITERATIONS" -lt 1 ]]; then
  echo "[test-stability] ERROR: --iterations must be a positive integer." >&2
  exit 2
fi

if [[ "$FAIL_ON_WARNING" != "true" && "$FAIL_ON_WARNING" != "false" ]]; then
  echo "[test-stability] ERROR: --fail-on-warning must be true or false." >&2
  exit 2
fi

if [[ -z "$LOG_FILE" ]]; then
  ts="$(date -u +'%Y%m%d-%H%M%S')"
  mkdir -p .ciReport
  LOG_FILE=".ciReport/test_stability_matrix_${ts}.log"
fi

: > "$LOG_FILE"

echo "[test-stability] Iterations: $ITERATIONS" | tee -a "$LOG_FILE"
echo "[test-stability] Concurrency list: $CONCURRENCY_LIST" | tee -a "$LOG_FILE"
echo "[test-stability] Randomize order: $RANDOMIZE_ORDER" | tee -a "$LOG_FILE"
if [[ ${#TARGETS[@]} -gt 0 ]]; then
  echo "[test-stability] Targets: ${TARGETS[*]}" | tee -a "$LOG_FILE"
else
  echo "[test-stability] Targets: <full suite>" | tee -a "$LOG_FILE"
fi

declare -a CONCURRENCY_VALUES=()
IFS=',' read -r -a CONCURRENCY_VALUES <<< "$CONCURRENCY_LIST"

run_index=0
for raw_concurrency in "${CONCURRENCY_VALUES[@]}"; do
  concurrency="$(echo "$raw_concurrency" | xargs)"
  if [[ -z "$concurrency" ]]; then
    continue
  fi

  for ((i = 1; i <= ITERATIONS; i++)); do
    run_index=$((run_index + 1))
    if [[ "$RANDOMIZE_ORDER" == "true" ]]; then
      seed="$(od -An -N4 -tu4 /dev/urandom | tr -d '[:space:]')"
    else
      seed=""
    fi

    echo "[test-stability] Run #$run_index :: concurrency=$concurrency iteration=$i seed=${seed:-n/a}" | tee -a "$LOG_FILE"

    cmd=(./scripts/flutterw.sh test)
    if [[ "$concurrency" != "auto" ]]; then
      cmd+=(--concurrency="$concurrency")
    fi
    if [[ "$RANDOMIZE_ORDER" == "true" ]]; then
      cmd+=(--test-randomize-ordering-seed="$seed")
    fi
    if [[ ${#TARGETS[@]} -gt 0 ]]; then
      cmd+=("${TARGETS[@]}")
    fi

    run_log="$(mktemp)"
    if ! "${cmd[@]}" >"$run_log" 2>&1; then
      echo "[test-stability] ERROR: run failed." | tee -a "$LOG_FILE"
      cat "$run_log" >> "$LOG_FILE"
      rm -f "$run_log"
      echo "[test-stability] Log: $LOG_FILE" >&2
      exit 1
    fi

    cat "$run_log" >> "$LOG_FILE"

    if [[ "$FAIL_ON_WARNING" == "true" ]]; then
      if ! bash ./scripts/verify_test_output_clean.sh --log "$run_log" >> "$LOG_FILE" 2>&1; then
        echo "[test-stability] ERROR: warning noise detected in run #$run_index" | tee -a "$LOG_FILE"
        rm -f "$run_log"
        echo "[test-stability] Log: $LOG_FILE" >&2
        exit 1
      fi
    fi

    rm -f "$run_log"
  done
done

echo "[test-stability] OK" | tee -a "$LOG_FILE"
echo "[test-stability] Log: $LOG_FILE"
