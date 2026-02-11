#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE=""
FAIL_ON_VIOLATIONS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --fail-on-violations)
      FAIL_ON_VIOLATIONS=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--output <file>] [--fail-on-violations]" >&2
      exit 2
      ;;
  esac
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

RAW_IMPORTS="$TMP_DIR/raw_imports.txt"
VIOLATIONS="$TMP_DIR/violations.tsv"
REPORT="$TMP_DIR/report.md"

rg -n "import 'package:hsf/features/" lib >"$RAW_IMPORTS" || true

cat >"$TMP_DIR/audit.awk" <<'AWK'
function source_feature(path,   a,n,i){
  n = split(path, a, "/");
  for (i = 1; i <= n; i++) {
    if (a[i] == "features" && i < n) return a[i+1];
  }
  return "";
}
function source_area(path,   a){
  split(path, a, "/");
  if (a[2] == "features") return "feature:" a[3];
  if (a[2] == "shared") return "shared";
  if (a[2] == "core") return "core";
  if (a[2] == "config") return "config";
  return a[2];
}
function import_feature(path,   p,a){
  p = path;
  sub(/^package:hsf\/features\//, "", p);
  split(p, a, "/");
  return a[1];
}
function is_public_api(path, feature){
  return path == ("package:hsf/features/" feature "/" feature ".dart");
}
{
  file = $1;
  line = $2;
  split($0, q, "'");
  import_path = q[2];

  src_feature = source_feature(file);
  src_area = source_area(file);
  imp_feature = import_feature(import_path);

  violation = 0;
  category = "";

  if (src_feature != "") {
    if (src_feature != imp_feature && !is_public_api(import_path, imp_feature)) {
      violation = 1;
      category = "cross_feature_internal_import";
    }
  } else {
    if (!is_public_api(import_path, imp_feature)) {
      violation = 1;
      category = "non_feature_internal_import";
    }
  }

  if (violation) {
    print file "\t" line "\t" src_area "\t" src_feature "\t" imp_feature "\t" category "\t" import_path;
  }
}
AWK

awk -F: -f "$TMP_DIR/audit.awk" "$RAW_IMPORTS" >"$VIOLATIONS"

TOTAL_IMPORTS="$(wc -l <"$RAW_IMPORTS" | tr -d ' ')"
TOTAL_VIOLATIONS="$(wc -l <"$VIOLATIONS" | tr -d ' ')"
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "unknown")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

{
  echo "# Architecture Boundary Audit"
  echo
  echo "- Timestamp: $NOW_UTC"
  echo "- Branch: \`$CURRENT_BRANCH\`"
  echo "- Imports scanned: $TOTAL_IMPORTS"
  echo "- Violations: $TOTAL_VIOLATIONS"
  echo
  echo "## Violations by Source Area"
  echo
  echo "| Source Area | Count |"
  echo "| :--- | ---: |"
  if [[ "$TOTAL_VIOLATIONS" -gt 0 ]]; then
    awk -F'\t' '{count[$3]++} END {for (k in count) printf("| %s | %d |\n", k, count[k]);}' "$VIOLATIONS" | sort
  else
    echo "| _none_ | 0 |"
  fi
  echo
  echo "## Violations by Category"
  echo
  echo "| Category | Count |"
  echo "| :--- | ---: |"
  if [[ "$TOTAL_VIOLATIONS" -gt 0 ]]; then
    awk -F'\t' '{count[$6]++} END {for (k in count) printf("| %s | %d |\n", k, count[k]);}' "$VIOLATIONS" | sort
  else
    echo "| _none_ | 0 |"
  fi
  echo
  echo "## Violation List"
  echo
  echo "| File | Line | Source Area | Imported Feature | Category | Import |"
  echo "| :--- | ---: | :--- | :--- | :--- | :--- |"
  if [[ "$TOTAL_VIOLATIONS" -gt 0 ]]; then
    awk -F'\t' '{printf("| `%s` | %s | %s | %s | %s | `%s` |\n", $1, $2, $3, $5, $6, $7);}' "$VIOLATIONS"
  else
    echo "| _none_ |  |  |  |  |  |"
  fi
} >"$REPORT"

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  cp "$REPORT" "$OUTPUT_FILE"
fi

cat "$REPORT"

if [[ "$FAIL_ON_VIOLATIONS" == true && "$TOTAL_VIOLATIONS" -gt 0 ]]; then
  exit 1
fi

