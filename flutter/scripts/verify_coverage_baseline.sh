#!/usr/bin/env bash
set -euo pipefail

LCOV_FILE="coverage/lcov.info"
BASELINE_FILE="ops/testing/coverage_baseline.env"
QUALITY_GATES_FILE="ops/testing/quality_gates.env"
INCLUDE_PATTERNS_FILE="ops/testing/coverage_include_patterns.txt"
EXCLUDE_PATTERNS_FILE="ops/testing/coverage_exclude_patterns.txt"
RATCHET_UPDATE="false"

usage() {
  cat <<'EOF'
Usage: ./scripts/verify_coverage_baseline.sh [--lcov <file>] [--baseline <file>] [--quality-gates <file>] [--include-patterns <file>] [--exclude-patterns <file>] [--ratchet-update <true|false>]

Verifies line coverage against a minimum baseline.
Coverage scope:
- files under lib/
- includes files matching regex entries from:
  - ops/testing/coverage_include_patterns.txt (default, allow-list)
- excludes files matching regex entries from:
  - ops/testing/coverage_exclude_patterns.txt (default)

Baseline file format:
  MIN_LIB_COVERAGE_PCT=8.74

Quality gates file format:
  MIN_BRANCH_COVERAGE_PCT=80
Note: this threshold is applied to scoped LCOV branch coverage (BRDA).
If BRDA is unavailable, the script falls back to scoped line coverage.

Ratchet mode:
- when --ratchet-update true and current coverage > baseline,
  update MIN_LIB_COVERAGE_PCT in-place for future runs.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lcov)
      LCOV_FILE="${2:-}"
      shift 2
      ;;
    --baseline)
      BASELINE_FILE="${2:-}"
      shift 2
      ;;
    --quality-gates)
      QUALITY_GATES_FILE="${2:-}"
      shift 2
      ;;
    --include-patterns)
      INCLUDE_PATTERNS_FILE="${2:-}"
      shift 2
      ;;
    --exclude-patterns)
      EXCLUDE_PATTERNS_FILE="${2:-}"
      shift 2
      ;;
    --ratchet-update)
      RATCHET_UPDATE="${2:-false}"
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

if [[ ! -f "$LCOV_FILE" ]]; then
  echo "[coverage-baseline] ERROR: lcov file not found: $LCOV_FILE" >&2
  exit 1
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "[coverage-baseline] ERROR: baseline file not found: $BASELINE_FILE" >&2
  exit 1
fi

if [[ ! -f "$QUALITY_GATES_FILE" ]]; then
  echo "[coverage-baseline] ERROR: quality gates file not found: $QUALITY_GATES_FILE" >&2
  exit 1
fi

if [[ ! -f "$INCLUDE_PATTERNS_FILE" ]]; then
  echo "[coverage-baseline] ERROR: include patterns file not found: $INCLUDE_PATTERNS_FILE" >&2
  exit 1
fi

if [[ ! -f "$EXCLUDE_PATTERNS_FILE" ]]; then
  echo "[coverage-baseline] ERROR: exclude patterns file not found: $EXCLUDE_PATTERNS_FILE" >&2
  exit 1
fi

min_coverage="$(grep -E '^[[:space:]]*MIN_LIB_COVERAGE_PCT=' "$BASELINE_FILE" | tail -n 1 | cut -d'=' -f2 | tr -d '[:space:]')"
if [[ -z "${min_coverage:-}" ]]; then
  echo "[coverage-baseline] ERROR: MIN_LIB_COVERAGE_PCT missing in baseline file: $BASELINE_FILE" >&2
  exit 1
fi

min_quality_gate_coverage="$(grep -E '^[[:space:]]*MIN_BRANCH_COVERAGE_PCT=' "$QUALITY_GATES_FILE" | tail -n 1 | cut -d'=' -f2 | tr -d '[:space:]')"
if [[ -z "${min_quality_gate_coverage:-}" ]]; then
  echo "[coverage-baseline] ERROR: MIN_BRANCH_COVERAGE_PCT missing in quality gates file: $QUALITY_GATES_FILE" >&2
  exit 1
fi

if ! [[ "$min_coverage" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "[coverage-baseline] ERROR: MIN_LIB_COVERAGE_PCT is not numeric: $min_coverage" >&2
  exit 1
fi

if ! [[ "$min_quality_gate_coverage" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "[coverage-baseline] ERROR: MIN_BRANCH_COVERAGE_PCT is not numeric: $min_quality_gate_coverage" >&2
  exit 1
fi

if [[ "$RATCHET_UPDATE" != "true" && "$RATCHET_UPDATE" != "false" ]]; then
  echo "[coverage-baseline] ERROR: --ratchet-update must be true or false." >&2
  exit 1
fi

coverage_stats="$(
  awk '
    FILENAME == include_file {
      line = $0;
      sub(/^[[:space:]]+/, "", line);
      sub(/[[:space:]]+$/, "", line);
      if (line == "" || line ~ /^#/) next;
      include_patterns[++include_pattern_count] = line;
      next;
    }

    FILENAME == exclude_file {
      line = $0;
      sub(/^[[:space:]]+/, "", line);
      sub(/[[:space:]]+$/, "", line);
      if (line == "" || line ~ /^#/) next;
      exclude_patterns[++exclude_pattern_count] = line;
      next;
    }

    function matches_any(path, patterns, pattern_count, i) {
      for (i = 1; i <= pattern_count; i++) {
        if (path ~ patterns[i]) return 1;
      }
      return 0;
    }

    /^SF:/ {
      sf = substr($0, 4);
      gsub(/\\/, "/", sf);
      in_scope = 0;

      if (sf ~ /^lib\//) {
        include_match = (include_pattern_count == 0) || matches_any(sf, include_patterns, include_pattern_count);
        exclude_match = matches_any(sf, exclude_patterns, exclude_pattern_count);
        if (include_match && !exclude_match) {
          in_scope = 1;
          scoped_files[sf] = 1;
        }
      }
      next;
    }
    /^DA:/ {
      line = substr($0, 4);
      split(line, a, ",");
      if (in_scope) {
        total++;
        if ((a[2] + 0) > 0) hit++;
      }
    }
    /^BRDA:/ {
      line = substr($0, 6);
      split(line, a, ",");
      if (in_scope) {
        branch_total++;
        if (a[4] != "-" && (a[4] + 0) > 0) branch_hit++;
      }
    }
    END {
      scoped_file_count = 0;
      for (sf_path in scoped_files) {
        scoped_file_count++;
      }

      line_cov = 0;
      if (total > 0) {
        line_cov = (hit / total) * 100;
      }

      branch_cov = -1;
      if (branch_total > 0) {
        branch_cov = (branch_hit / branch_total) * 100;
      }

      printf("%.2f|%d|%d|%d|%d|%d|%.2f", line_cov, hit, total, scoped_file_count, branch_hit, branch_total, branch_cov);
    }
  ' include_file="$INCLUDE_PATTERNS_FILE" exclude_file="$EXCLUDE_PATTERNS_FILE" "$INCLUDE_PATTERNS_FILE" "$EXCLUDE_PATTERNS_FILE" "$LCOV_FILE"
)"

IFS='|' read -r current_coverage hit_lines total_lines scoped_files branch_hit branch_total branch_coverage <<<"$coverage_stats"

echo "[coverage-baseline] Current coverage: $current_coverage%"
echo "[coverage-baseline] Baseline minimum: $min_coverage%"
echo "[coverage-baseline] Quality-gate minimum: $min_quality_gate_coverage%"
echo "[coverage-baseline] Scoped files: $scoped_files"
echo "[coverage-baseline] Scoped lines: $hit_lines/$total_lines"
if (( branch_total > 0 )); then
  echo "[coverage-baseline] Scoped branches: $branch_hit/$branch_total ($branch_coverage%)"
else
  echo "[coverage-baseline] Scoped branches: n/a (LCOV has no BRDA entries; using scoped line coverage fallback for quality gate)."
fi
echo "[coverage-baseline] Include patterns: $INCLUDE_PATTERNS_FILE"
echo "[coverage-baseline] Exclude patterns: $EXCLUDE_PATTERNS_FILE"
echo "[coverage-baseline] Quality gates file: $QUALITY_GATES_FILE"

if awk "BEGIN {exit !($current_coverage + 0 < $min_coverage + 0)}"; then
  echo "[coverage-baseline] ERROR: coverage dropped below baseline." >&2
  exit 1
fi

if (( branch_total > 0 )); then
  if awk "BEGIN {exit !($branch_coverage + 0 < $min_quality_gate_coverage + 0)}"; then
    echo "[coverage-baseline] ERROR: branch coverage below quality gate threshold." >&2
    exit 1
  fi
else
  if awk "BEGIN {exit !($current_coverage + 0 < $min_quality_gate_coverage + 0)}"; then
    echo "[coverage-baseline] ERROR: scoped line coverage below quality gate threshold fallback (branch data unavailable)." >&2
    exit 1
  fi
fi

if [[ "$RATCHET_UPDATE" == "true" ]] && awk "BEGIN {exit !($current_coverage + 0 > $min_coverage + 0)}"; then
  tmp_file="$(mktemp)"
  awk -v value="$current_coverage" '
    BEGIN {updated=0}
    {
      if ($0 ~ /^[[:space:]]*MIN_LIB_COVERAGE_PCT=/) {
        print "MIN_LIB_COVERAGE_PCT=" value
        updated=1
      } else {
        print
      }
    }
    END {
      if (updated == 0) {
        print "MIN_LIB_COVERAGE_PCT=" value
      }
    }
  ' "$BASELINE_FILE" >"$tmp_file"
  mv "$tmp_file" "$BASELINE_FILE"

  echo "[coverage-baseline] Ratchet: baseline increased to $current_coverage% in $BASELINE_FILE"
  echo "[coverage-baseline] Note: this applies to the next push; current push is not blocked."
fi

echo "[coverage-baseline] OK"
