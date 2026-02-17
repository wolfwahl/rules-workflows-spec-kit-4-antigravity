#!/usr/bin/env bash
set -euo pipefail

FEATURES_ROOT="lib/features"
TESTS_ROOT="test/features"
BASELINE_FILE="ops/testing/feature_test_parity_baseline.txt"

usage() {
  cat <<'EOF'
Usage: ./scripts/verify_feature_test_parity.sh [--features-root <path>] [--tests-root <path>] [--baseline <file>]

Verifies feature test parity using a ratchet baseline:
- every feature in lib/features/* must have at least one *_test.dart in test/features/<feature>/*
- features listed in the baseline file are temporarily allowed to have no tests
- if a baseline entry is now covered, the baseline must be updated (entry removed)
- if baseline contains unknown features, verification fails
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --features-root)
      FEATURES_ROOT="${2:-}"
      shift 2
      ;;
    --tests-root)
      TESTS_ROOT="${2:-}"
      shift 2
      ;;
    --baseline)
      BASELINE_FILE="${2:-}"
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

if [[ ! -d "$FEATURES_ROOT" ]]; then
  echo "[feature-parity] ERROR: features root not found: $FEATURES_ROOT" >&2
  exit 1
fi

if [[ ! -d "$TESTS_ROOT" ]]; then
  echo "[feature-parity] ERROR: tests root not found: $TESTS_ROOT" >&2
  exit 1
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "[feature-parity] ERROR: baseline file not found: $BASELINE_FILE" >&2
  exit 1
fi

mapfile -t FEATURES < <(find "$FEATURES_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
mapfile -t BASELINE_RAW < <(grep -v '^[[:space:]]*#' "$BASELINE_FILE" | sed '/^[[:space:]]*$/d' | sort -u)

declare -A FEATURE_EXISTS=()
declare -A MISSING=()
declare -A BASELINE_ALLOWED=()

for feature in "${FEATURES[@]}"; do
  FEATURE_EXISTS["$feature"]=1
done

for feature in "${BASELINE_RAW[@]}"; do
  BASELINE_ALLOWED["$feature"]=1
done

for feature in "${FEATURES[@]}"; do
  count=0
  if [[ -d "$TESTS_ROOT/$feature" ]]; then
    count="$(find "$TESTS_ROOT/$feature" -type f -name '*_test.dart' | wc -l | tr -d ' ')"
  fi

  printf '[feature-parity] %-16s tests=%s\n' "$feature" "$count"
  if [[ "${count:-0}" -eq 0 ]]; then
    MISSING["$feature"]=1
  fi
done

errors=0

for feature in "${!MISSING[@]}"; do
  if [[ -z "${BASELINE_ALLOWED[$feature]:-}" ]]; then
    echo "[feature-parity] ERROR: missing tests for feature not covered by baseline: $feature" >&2
    errors=$((errors + 1))
  fi
done

for feature in "${!BASELINE_ALLOWED[@]}"; do
  if [[ -z "${FEATURE_EXISTS[$feature]:-}" ]]; then
    echo "[feature-parity] ERROR: baseline contains unknown feature: $feature" >&2
    errors=$((errors + 1))
  fi
done

for feature in "${!BASELINE_ALLOWED[@]}"; do
  if [[ -z "${MISSING[$feature]:-}" && -n "${FEATURE_EXISTS[$feature]:-}" ]]; then
    echo "[feature-parity] ERROR: baseline entry is no longer needed (feature has tests now): $feature" >&2
    echo "[feature-parity] Update baseline file and remove this entry: $BASELINE_FILE" >&2
    errors=$((errors + 1))
  fi
done

total_features="${#FEATURES[@]}"
missing_count="${#MISSING[@]}"
baseline_count="${#BASELINE_ALLOWED[@]}"

echo "[feature-parity] Total features: $total_features"
echo "[feature-parity] Missing tests (current): $missing_count"
echo "[feature-parity] Baseline allow-list entries: $baseline_count"

if [[ "$errors" -gt 0 ]]; then
  echo "[feature-parity] FAILED with $errors error(s)." >&2
  exit 1
fi

echo "[feature-parity] OK"
