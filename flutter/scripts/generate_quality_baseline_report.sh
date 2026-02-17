#!/usr/bin/env bash
set -euo pipefail

LCOV_FILE="coverage/lcov.info"
INCLUDE_PATTERNS_FILE="ops/testing/coverage_include_patterns.txt"
EXCLUDE_PATTERNS_FILE="ops/testing/coverage_exclude_patterns.txt"
OUT_MD=""
OUT_ENV=""
OUT_CSV=""
OUT_DEP_EDGES=""
TOP_N=15
RUN_ANALYZE="true"

usage() {
  cat <<'EOF'
Usage: ./scripts/generate_quality_baseline_report.sh [options]

Options:
  --lcov <file>               LCOV input (default: coverage/lcov.info)
  --include-patterns <file>   Include regex file
  --exclude-patterns <file>   Exclude regex file
  --out-md <file>             Markdown report output path
  --out-env <file>            Key=value snapshot output path
  --out-csv <file>            CSV output path (risk ranking)
  --out-deps <file>           Dependency edge list output path (source,target)
  --top <n>                   Top rows per section (default: 15)
  --skip-analyze              Skip dead-code/unused scan via flutter analyze
  -h, --help                  Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lcov)
      LCOV_FILE="${2:-}"
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
    --out-md)
      OUT_MD="${2:-}"
      shift 2
      ;;
    --out-env)
      OUT_ENV="${2:-}"
      shift 2
      ;;
    --out-csv)
      OUT_CSV="${2:-}"
      shift 2
      ;;
    --out-deps)
      OUT_DEP_EDGES="${2:-}"
      shift 2
      ;;
    --top)
      TOP_N="${2:-15}"
      shift 2
      ;;
    --skip-analyze)
      RUN_ANALYZE="false"
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

if [[ ! -f "$LCOV_FILE" ]]; then
  echo "[quality-baseline] ERROR: lcov file not found: $LCOV_FILE" >&2
  exit 1
fi
if [[ ! -f "$INCLUDE_PATTERNS_FILE" ]]; then
  echo "[quality-baseline] ERROR: include patterns file not found: $INCLUDE_PATTERNS_FILE" >&2
  exit 1
fi
if [[ ! -f "$EXCLUDE_PATTERNS_FILE" ]]; then
  echo "[quality-baseline] ERROR: exclude patterns file not found: $EXCLUDE_PATTERNS_FILE" >&2
  exit 1
fi
if ! [[ "$TOP_N" =~ ^[0-9]+$ ]]; then
  echo "[quality-baseline] ERROR: --top must be numeric." >&2
  exit 1
fi

HAS_RG=0
if command -v rg >/dev/null 2>&1; then
  HAS_RG=1
fi

count_matches() {
  local text="$1"
  local rg_pattern="$2"
  local grep_pattern="$3"
  local count

  if [[ "$HAS_RG" == "1" ]]; then
    count="$( (printf '%s\n' "$text" | rg -o -N "$rg_pattern" || true) | wc -l | tr -d ' ' )"
  else
    count="$( (printf '%s\n' "$text" | grep -oE "$grep_pattern" || true) | wc -l | tr -d ' ' )"
  fi

  printf '%s' "${count:-0}"
}

extract_imports() {
  local path="$1"
  if [[ "$HAS_RG" == "1" ]]; then
    rg -o -N "import 'package:hsf/[^']+'" "$path" \
      | sed -E "s/^import 'package:hsf\/(.*)'$/lib\/\1/" \
      | sort -u || true
  else
    grep -oE "import 'package:hsf/[^']+'" "$path" \
      | sed -E "s/^import 'package:hsf\/(.*)'$/lib\/\1/" \
      | sort -u || true
  fi
}

timestamp_utc="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
timestamp_compact="$(date -u +'%Y%m%d-%H%M%S')"

if [[ -z "$OUT_MD" ]]; then
  OUT_MD=".ciReport/quality_baseline_${timestamp_compact}.md"
fi
if [[ -z "$OUT_ENV" ]]; then
  OUT_ENV=".ciReport/quality_baseline_snapshot_${timestamp_compact}.env"
fi
if [[ -z "$OUT_CSV" ]]; then
  OUT_CSV=".ciReport/quality_risk_ranking_${timestamp_compact}.csv"
fi
if [[ -z "$OUT_DEP_EDGES" ]]; then
  OUT_DEP_EDGES=".ciReport/quality_dependency_edges_${timestamp_compact}.csv"
fi

mkdir -p "$(dirname "$OUT_MD")"
mkdir -p "$(dirname "$OUT_ENV")"
mkdir -p "$(dirname "$OUT_CSV")"
mkdir -p "$(dirname "$OUT_DEP_EDGES")"

coverage_tsv="$(mktemp)"
metrics_tsv="$(mktemp)"
risk_tsv="$(mktemp)"
fanin_tsv="$(mktemp)"
edges_tsv="$(mktemp)"
deadcode_machine="$(mktemp)"
trap 'rm -f "$coverage_tsv" "$metrics_tsv" "$risk_tsv" "$fanin_tsv" "$edges_tsv" "$deadcode_machine"' EXIT

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
    if (!in_scope) next;
    line = substr($0, 4);
    split(line, a, ",");
    total[sf]++;
    if ((a[2] + 0) > 0) hit[sf]++;
  }

  END {
    for (f in scoped_files) {
      t = total[f] + 0;
      h = hit[f] + 0;
      miss = t - h;
      cov = (t > 0) ? ((h / t) * 100) : 0;
      printf "%s|%d|%d|%d|%.2f\n", f, h, t, miss, cov;
    }
  }
' include_file="$INCLUDE_PATTERNS_FILE" exclude_file="$EXCLUDE_PATTERNS_FILE" \
  "$INCLUDE_PATTERNS_FILE" "$EXCLUDE_PATTERNS_FILE" "$LCOV_FILE" \
  | sort >"$coverage_tsv"

if [[ ! -s "$coverage_tsv" ]]; then
  echo "[quality-baseline] ERROR: no scoped files found from LCOV + include/exclude patterns." >&2
  exit 1
fi

while IFS='|' read -r path hit total miss cov; do
  code_no_comments="$(sed -E 's,//.*$,,' "$path")"

  if_count="$(count_matches "$code_no_comments" '\bif\s*\(' '(^|[^[:alnum:]_])if[[:space:]]*\(')"
  for_count="$(count_matches "$code_no_comments" '\bfor\s*\(' '(^|[^[:alnum:]_])for[[:space:]]*\(')"
  while_count="$(count_matches "$code_no_comments" '\bwhile\s*\(' '(^|[^[:alnum:]_])while[[:space:]]*\(')"
  case_count="$(count_matches "$code_no_comments" '\bcase\b' '(^|[^[:alnum:]_])case([^[:alnum:]_]|$)')"
  catch_count="$(count_matches "$code_no_comments" '\bcatch\s*\(' '(^|[^[:alnum:]_])catch[[:space:]]*\(')"
  and_count="$(count_matches "$code_no_comments" '&&' '&&')"
  or_count="$(count_matches "$code_no_comments" '\|\|' '\|\|')"

  complexity=$((1 + if_count + for_count + while_count + case_count + catch_count + and_count + or_count))

  imports="$(extract_imports "$path")"

  fan_out=0
  if [[ -n "$imports" ]]; then
    fan_out="$(printf '%s\n' "$imports" | sed '/^$/d' | wc -l | tr -d ' ')"
    while IFS= read -r target; do
      [[ -z "$target" ]] && continue
      printf '%s|%s\n' "$path" "$target" >>"$edges_tsv"
    done <<<"$imports"
  fi

  printf '%s|%s|%s|%s|%s|%d|%d\n' \
    "$path" "$hit" "$total" "$miss" "$cov" "$complexity" "$fan_out" \
    >>"$metrics_tsv"
done <"$coverage_tsv"

if [[ -s "$edges_tsv" ]]; then
  sort -u "$edges_tsv" -o "$edges_tsv"
fi

if [[ -s "$edges_tsv" ]]; then
  awk -F'|' '{fanin[$2]++} END {for (k in fanin) printf "%s|%d\n", k, fanin[k]}' \
    "$edges_tsv" | sort >"$fanin_tsv"
else
  : >"$fanin_tsv"
fi

while IFS='|' read -r path hit total miss cov complexity fan_out; do
  fan_in="$(awk -F'|' -v target="$path" '$1 == target {print $2}' "$fanin_tsv" | head -n 1)"
  fan_in="${fan_in:-0}"

  risk_score="$(awk -v miss="$miss" -v complexity="$complexity" -v fan_out="$fan_out" -v fan_in="$fan_in" \
    'BEGIN { printf "%.2f", (miss * 1.20) + (complexity * 0.80) + (fan_out * 0.50) + (fan_in * 0.30) }')"

  bucket="low"
  if awk "BEGIN {exit !($risk_score >= 140)}"; then
    bucket="critical"
  elif awk "BEGIN {exit !($risk_score >= 100)}"; then
    bucket="high"
  elif awk "BEGIN {exit !($risk_score >= 60)}"; then
    bucket="medium"
  fi

  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$path" "$risk_score" "$bucket" "$miss" "$cov" "$complexity" "$fan_out" "$fan_in" "$total" \
    >>"$risk_tsv"
done <"$metrics_tsv"

sort -t'|' -k2,2nr "$risk_tsv" -o "$risk_tsv"

total_hit="$(awk -F'|' '{sum += $2} END {print sum + 0}' "$coverage_tsv")"
total_lines="$(awk -F'|' '{sum += $3} END {print sum + 0}' "$coverage_tsv")"
scoped_files="$(wc -l <"$coverage_tsv" | tr -d ' ')"
scoped_cov="$(awk -v h="$total_hit" -v t="$total_lines" 'BEGIN { if (t == 0) print "0.00"; else printf "%.2f", (h / t) * 100 }')"

high_risk_modules="$(awk -F'|' 'NR <= 3 {print $1}' "$risk_tsv" | paste -sd, -)"
high_risk_modules="${high_risk_modules:-}"

dead_code_count=0
unused_count=0
dead_code_top="none"
if [[ "$RUN_ANALYZE" == "true" ]]; then
  ./scripts/flutterw.sh analyze --machine >"$deadcode_machine" 2>&1 || true
  dead_code_count="$(awk -F'|' '$3 == "dead_code" {count++} END {print count + 0}' "$deadcode_machine")"
  unused_count="$(awk -F'|' '$3 ~ /^unused_/ {count++} END {print count + 0}' "$deadcode_machine")"
  dead_code_top="$(awk -F'|' '$3 == "dead_code" || $3 ~ /^unused_/ {hits[$4]++} END {for (f in hits) printf "%s:%d\n", f, hits[f]}' "$deadcode_machine" \
    | sort -t: -k2,2nr | head -n 5 | paste -sd', ' -)"
  dead_code_top="${dead_code_top:-none}"
fi

{
  echo "path,risk_score,risk_bucket,missed_lines,coverage_pct,complexity,fan_out,fan_in,total_lines"
  awk -F'|' '{printf "%s,%s,%s,%s,%s,%s,%s,%s,%s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9}' "$risk_tsv"
} >"$OUT_CSV"

if [[ -s "$edges_tsv" ]]; then
  {
    echo "source,target"
    awk -F'|' '{printf "%s,%s\n",$1,$2}' "$edges_tsv"
  } >"$OUT_DEP_EDGES"
else
  printf 'source,target\n' >"$OUT_DEP_EDGES"
fi

{
  echo "# Quality Baseline Report"
  echo
  echo "- Generated (UTC): $timestamp_utc"
  echo "- Scoped files: $scoped_files"
  echo "- Scoped lines: $total_hit/$total_lines"
  echo "- Scoped branch/line coverage (from LCOV): $scoped_cov%"
  echo "- Dead code findings (\`dead_code\`): $dead_code_count"
  echo "- Unused findings (\`unused_*\`): $unused_count"
  echo
  echo "## Risk Heatmap (Top $TOP_N)"
  echo
  echo "| File | Risk Score | Bucket | Missed Lines | Coverage | Complexity | Fan-Out | Fan-In |"
  echo "|---|---:|---|---:|---:|---:|---:|---:|"
  awk -F'|' -v top="$TOP_N" 'NR <= top {printf "| `%s` | %.2f | %s | %d | %.2f%% | %d | %d | %d |\n", $1, $2, $3, $4, $5, $6, $7, $8}' "$risk_tsv"
  echo
  echo "## Complexity Ranking (Top $TOP_N)"
  echo
  echo "| File | Complexity | Missed Lines | Coverage |"
  echo "|---|---:|---:|---:|"
  sort -t'|' -k6,6nr "$risk_tsv" | awk -F'|' -v top="$TOP_N" 'NR <= top {printf "| `%s` | %d | %d | %.2f%% |\n", $1, $6, $4, $5}'
  echo
  echo "## Dependency Signal"
  echo
  echo "- Dependency edges: $(wc -l <"$edges_tsv" | tr -d ' ')"
  echo "- Highest Fan-Out module: $(sort -t'|' -k7,7nr "$risk_tsv" | awk -F'|' 'NR==1 {printf "%s (%s)", $1, $7}')"
  echo "- Highest Fan-In module: $(sort -t'|' -k8,8nr "$risk_tsv" | awk -F'|' 'NR==1 {printf "%s (%s)", $1, $8}')"
  echo
  echo "## Dead Code / Unused Signal"
  echo
  echo "- dead_code: $dead_code_count"
  echo "- unused_*: $unused_count"
  echo "- Top files: $dead_code_top"
} >"$OUT_MD"

{
  echo "# Auto-generated by scripts/generate_quality_baseline_report.sh at $timestamp_utc"
  echo "QUALITY_BASELINE_GENERATED_AT=$timestamp_utc"
  echo "QUALITY_SCOPED_FILES=$scoped_files"
  echo "QUALITY_SCOPED_HIT_LINES=$total_hit"
  echo "QUALITY_SCOPED_TOTAL_LINES=$total_lines"
  echo "QUALITY_SCOPED_COVERAGE_PCT=$scoped_cov"
  echo "QUALITY_DEAD_CODE_ISSUES=$dead_code_count"
  echo "QUALITY_UNUSED_ISSUES=$unused_count"
  echo "HIGH_RISK_MODULES=$high_risk_modules"
} >"$OUT_ENV"

echo "[quality-baseline] Report: $OUT_MD"
echo "[quality-baseline] Snapshot: $OUT_ENV"
echo "[quality-baseline] Risk CSV: $OUT_CSV"
echo "[quality-baseline] Dependency edges: $OUT_DEP_EDGES"
