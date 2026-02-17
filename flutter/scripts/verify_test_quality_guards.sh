#!/usr/bin/env bash
set -euo pipefail

BASE_REF=""
QUALITY_SNAPSHOT_FILE=""
EXCEPTIONS_FILE="ops/testing/test_exceptions.txt"
COVERAGE_INCLUDE_FILE="ops/testing/coverage_include_patterns.txt"
COVERAGE_EXCLUDE_FILE="ops/testing/coverage_exclude_patterns.txt"
MUTATION_TARGETS_FILE="ops/testing/mutation_targets.txt"
MUTATION_EXCLUDES_FILE="ops/testing/mutation_exclude_mutants.txt"
EXCEPTIONS_APPROVED_BY=""

usage() {
  cat <<'EOF'
Usage: ./scripts/verify_test_quality_guards.sh [options]

Guards against test-suite degradation by enforcing:
- test delta for production code changes
- widget-test delta for UI presentation/widget changes
- no silent scope shrink for coverage/mutation config
- high-risk module parity with mutation targets
- structured, non-expired TEST_EXCEPTION entries

Options:
  --base-ref <git-ref>            Optional base ref for diff range
  --quality-snapshot <file>       Optional quality snapshot env (HIGH_RISK_MODULES=...)
  --exceptions <file>             TEST_EXCEPTION file (default: ops/testing/test_exceptions.txt)
  --coverage-include <file>       Coverage include patterns file
  --coverage-exclude <file>       Coverage exclude patterns file
  --mutation-targets <file>       Mutation targets file
  --mutation-excludes <file>      Mutation excludes file
  --exceptions-approved-by <name> Enable TEST_EXCEPTION waivers only for the given approver
  -h, --help                      Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-ref)
      BASE_REF="${2:-}"
      shift 2
      ;;
    --quality-snapshot)
      QUALITY_SNAPSHOT_FILE="${2:-}"
      shift 2
      ;;
    --exceptions)
      EXCEPTIONS_FILE="${2:-}"
      shift 2
      ;;
    --coverage-include)
      COVERAGE_INCLUDE_FILE="${2:-}"
      shift 2
      ;;
    --coverage-exclude)
      COVERAGE_EXCLUDE_FILE="${2:-}"
      shift 2
      ;;
    --mutation-targets)
      MUTATION_TARGETS_FILE="${2:-}"
      shift 2
      ;;
    --mutation-excludes)
      MUTATION_EXCLUDES_FILE="${2:-}"
      shift 2
      ;;
    --exceptions-approved-by)
      EXCEPTIONS_APPROVED_BY="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[test-quality-guards] ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

HAS_RG=0
if command -v rg >/dev/null 2>&1; then
  HAS_RG=1
fi

filter_with_regex() {
  local pattern="$1"
  if [[ "$HAS_RG" == "1" ]]; then
    rg "$pattern" || true
  else
    grep -E "$pattern" || true
  fi
}

filter_without_regex() {
  local pattern="$1"
  if [[ "$HAS_RG" == "1" ]]; then
    rg -v "$pattern" || true
  else
    grep -Ev "$pattern" || true
  fi
}

file_contains_regex() {
  local pattern="$1"
  local file="$2"
  if [[ "$HAS_RG" == "1" ]]; then
    rg -q "$pattern" "$file"
  else
    grep -qE "$pattern" "$file"
  fi
}

has_direct_widget_test_for_ui_file() {
  local ui_file="$1"
  local expected_test_file=""

  if [[ "$ui_file" == lib/* ]]; then
    expected_test_file="test/${ui_file#lib/}"
    expected_test_file="${expected_test_file%.dart}_test.dart"
  else
    return 1
  fi

  if [[ ! -f "$expected_test_file" ]]; then
    return 1
  fi

  file_contains_regex 'testWidgets\(' "$expected_test_file"
}

read_active_regex_patterns() {
  local pattern_file="$1"
  local raw_pattern
  local pattern

  [[ -f "$pattern_file" ]] || return 0

  while IFS= read -r raw_pattern || [[ -n "$raw_pattern" ]]; do
    pattern="${raw_pattern#"${raw_pattern%%[![:space:]]*}"}"
    pattern="${pattern%"${pattern##*[![:space:]]}"}"
    [[ -z "$pattern" || "${pattern:0:1}" == "#" ]] && continue
    printf '%s\n' "$pattern"
  done <"$pattern_file"
}

is_allowed_coverage_exclude_pattern() {
  local pattern="$1"
  case "$pattern" in
    '\.g\.dart$'|'\.freezed\.dart$'|'\.mocks\.dart$'|'\.gen\.dart$'|'^lib/l10n/.*\.dart$')
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

list_dart_files_under_lib() {
  if [[ "$HAS_RG" == "1" ]]; then
    rg --files lib | rg '\.dart$' || true
  else
    find lib -type f -name '*.dart' | sed 's#^\./##' || true
  fi
}

resolve_base_ref() {
  if [[ -n "$BASE_REF" ]]; then
    echo "$BASE_REF"
    return
  fi

  if [[ -n "${GITHUB_BASE_REF:-}" ]] &&
    git show-ref --verify --quiet "refs/remotes/origin/${GITHUB_BASE_REF}"; then
    echo "origin/${GITHUB_BASE_REF}"
    return
  fi

  local upstream
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || true)"
  if [[ -n "$upstream" ]]; then
    echo "$upstream"
    return
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/main"; then
    echo "origin/main"
    return
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/master"; then
    echo "origin/master"
    return
  fi

  if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    echo "HEAD~1"
    return
  fi

  echo "HEAD"
}

BASE_REF_RESOLVED="$(resolve_base_ref)"
if [[ "$BASE_REF_RESOLVED" == "HEAD" ]]; then
  MERGE_BASE="HEAD"
else
  MERGE_BASE="$(git merge-base HEAD "$BASE_REF_RESOLVED" 2>/dev/null || true)"
  if [[ -z "$MERGE_BASE" ]]; then
    echo "[test-quality-guards] ERROR: could not resolve merge-base with $BASE_REF_RESOLVED" >&2
    exit 1
  fi
fi

mapfile -t RAW_CHANGED_FILES < <(git diff --name-only "$MERGE_BASE...HEAD")
declare -a CHANGED_FILES=()

for changed_file in "${RAW_CHANGED_FILES[@]}"; do
  # Ignore pure line-ending-only diffs to keep gates semantic.
  if ! git diff --ignore-cr-at-eol --quiet "$MERGE_BASE...HEAD" -- "$changed_file"; then
    CHANGED_FILES+=("$changed_file")
  fi
done

declare -a EX_TYPES=()
declare -a EX_SUBJECTS=()
declare -a EX_REASONS=()
declare -a EX_RISKS=()
declare -a EX_OWNERS=()
declare -a EX_DUE_DATES=()
declare -a EX_APPROVERS=()
declare -a VALIDATION_ERRORS=()
EXCEPTIONS_FILE_CHANGED="false"
for changed_file in "${CHANGED_FILES[@]}"; do
  if [[ "$changed_file" == "$EXCEPTIONS_FILE" ]]; then
    EXCEPTIONS_FILE_CHANGED="true"
    break
  fi
done

if [[ ! -f "$EXCEPTIONS_FILE" ]]; then
  echo "[test-quality-guards] ERROR: TEST_EXCEPTION file not found: $EXCEPTIONS_FILE" >&2
  exit 1
fi

if [[ ! -f "$COVERAGE_INCLUDE_FILE" ]]; then
  echo "[test-quality-guards] ERROR: coverage include file not found: $COVERAGE_INCLUDE_FILE" >&2
  exit 1
fi

if [[ ! -f "$COVERAGE_EXCLUDE_FILE" ]]; then
  echo "[test-quality-guards] ERROR: coverage exclude file not found: $COVERAGE_EXCLUDE_FILE" >&2
  exit 1
fi

today_utc="$(date -u +%F)"
line_no=0
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line_no=$((line_no + 1))
  line="${raw_line#"${raw_line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

  IFS='|' read -r ex_type ex_subject ex_reason ex_risk ex_owner ex_due ex_approved extra <<<"$line"
  if [[ -n "${extra:-}" ]]; then
    VALIDATION_ERRORS+=("line $line_no: too many fields (expected 7)")
    continue
  fi

  if [[ -z "${ex_type:-}" || -z "${ex_subject:-}" || -z "${ex_reason:-}" || -z "${ex_risk:-}" || -z "${ex_owner:-}" || -z "${ex_due:-}" || -z "${ex_approved:-}" ]]; then
    VALIDATION_ERRORS+=("line $line_no: all 7 fields are required (type|subject|reason|risk|owner|due_date|approved_by)")
    continue
  fi

  case "$ex_type" in
    test_delta|ui_widget_test|ui_scope_admission|scope_shrink|mutation_parity)
      ;;
    *)
      VALIDATION_ERRORS+=("line $line_no: unsupported exception type '$ex_type'")
      continue
      ;;
  esac

  if ! [[ "$ex_due" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    VALIDATION_ERRORS+=("line $line_no: due_date must match YYYY-MM-DD")
    continue
  fi

  if [[ "$ex_due" < "$today_utc" ]]; then
    VALIDATION_ERRORS+=("line $line_no: exception expired on $ex_due")
    continue
  fi

  EX_TYPES+=("$ex_type")
  EX_SUBJECTS+=("$ex_subject")
  EX_REASONS+=("$ex_reason")
  EX_RISKS+=("$ex_risk")
  EX_OWNERS+=("$ex_owner")
  EX_DUE_DATES+=("$ex_due")
  EX_APPROVERS+=("$ex_approved")
done <"$EXCEPTIONS_FILE"

if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  echo "[test-quality-guards] ERROR: TEST_EXCEPTION validation failed:" >&2
  for err in "${VALIDATION_ERRORS[@]}"; do
    echo "  - $err" >&2
  done
  exit 1
fi

has_exception() {
  local issue_type="$1"
  local subject="$2"
  local required_approver="$EXCEPTIONS_APPROVED_BY"

  if [[ -z "$required_approver" ]]; then
    return 1
  fi

  local i
  for i in "${!EX_TYPES[@]}"; do
    [[ "${EX_TYPES[$i]}" != "$issue_type" ]] && continue
    [[ "${EX_APPROVERS[$i]}" != "$required_approver" ]] && continue
    local pattern="${EX_SUBJECTS[$i]}"
    if [[ "$subject" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

matches_regex_list_file() {
  local path="$1"
  local pattern_file="$2"
  local raw_pattern
  local pattern

  [[ -f "$pattern_file" ]] || return 1

  while IFS= read -r raw_pattern || [[ -n "$raw_pattern" ]]; do
    pattern="${raw_pattern#"${raw_pattern%%[![:space:]]*}"}"
    pattern="${pattern%"${pattern##*[![:space:]]}"}"
    [[ -z "$pattern" || "${pattern:0:1}" == "#" ]] && continue
    if [[ "$path" =~ $pattern ]]; then
      return 0
    fi
  done <"$pattern_file"

  return 1
}

declare -a ISSUES=()
declare -a WAIVED=()

register_issue() {
  local issue_type="$1"
  local subject="$2"
  local detail="$3"

  if has_exception "$issue_type" "$subject"; then
    WAIVED+=("$issue_type|$subject|$detail")
  else
    ISSUES+=("$issue_type|$subject|$detail")
  fi
}

if [[ -f "$COVERAGE_INCLUDE_FILE" ]]; then
  has_global_lib_include="false"
  while IFS= read -r include_pattern; do
    if [[ "$include_pattern" == '^lib/.*\.dart$' ]]; then
      has_global_lib_include="true"
      break
    fi
  done < <(read_active_regex_patterns "$COVERAGE_INCLUDE_FILE")

  if [[ "$has_global_lib_include" != "true" ]]; then
    register_issue \
      "scope_shrink" \
      "coverage_include_missing:^lib/.*\\.dart$" \
      "coverage include must contain the global lib scope pattern '^lib/.*\\.dart$'"
  fi
fi

if [[ -f "$COVERAGE_EXCLUDE_FILE" ]]; then
  while IFS= read -r active_pattern; do
    if ! is_allowed_coverage_exclude_pattern "$active_pattern"; then
      register_issue \
        "scope_shrink" \
        "coverage_exclude_non_technical:${active_pattern}" \
        "coverage excludes must be technical only (generated files + lib/l10n)"
    fi
  done < <(read_active_regex_patterns "$COVERAGE_EXCLUDE_FILE")
fi

extract_diff_payload_lines() {
  local mode="$1"
  local file="$2"
  local prefix
  local header_prefix

  if [[ "$mode" == "add" ]]; then
    prefix="+"
    header_prefix="+++"
  else
    prefix="-"
    header_prefix="---"
  fi

  git diff --unified=0 "$MERGE_BASE...HEAD" -- "$file" \
    | awk -v prefix="$prefix" -v header_prefix="$header_prefix" '
      index($0, header_prefix) == 1 {next}
      index($0, prefix) == 1 {
        line = substr($0, 2);
        sub(/^[[:space:]]+/, "", line);
        sub(/[[:space:]]+$/, "", line);
        if (line == "" || line ~ /^#/) next;
        print line;
      }
    '
}

if [[ "$EXCEPTIONS_FILE_CHANGED" == "true" ]]; then
  has_added_exception_entries="false"
  while IFS= read -r added_line; do
    line="${added_line#"${added_line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    has_added_exception_entries="true"
    break
  done < <(extract_diff_payload_lines "add" "$EXCEPTIONS_FILE")

  if [[ "$has_added_exception_entries" == "true" && -z "$EXCEPTIONS_APPROVED_BY" ]]; then
    register_issue \
      "scope_shrink" \
      "test_exceptions_added:${EXCEPTIONS_FILE}" \
      "TEST_EXCEPTION additions require explicit approval via --exceptions-approved-by <approver>"
  fi
fi

mapfile -t CHANGED_PROD_DART < <(
  printf '%s\n' "${CHANGED_FILES[@]}" \
    | filter_with_regex '^lib/.*\.dart$' \
    | filter_without_regex '\.(g|freezed|mocks|gen)\.dart$|^lib/l10n/.*\.dart$'
)

mapfile -t CHANGED_TEST_FILES < <(
  printf '%s\n' "${CHANGED_FILES[@]}" \
    | filter_with_regex '^test/.*_test\.dart$'
)

if [[ ${#CHANGED_PROD_DART[@]} -gt 0 && ${#CHANGED_TEST_FILES[@]} -eq 0 ]]; then
  register_issue "test_delta" "lib/**" "production Dart changed without *_test.dart delta"
fi

mapfile -t CHANGED_UI_PROD_DART < <(
  printf '%s\n' "${CHANGED_PROD_DART[@]}" \
    | filter_with_regex '/(presentation|widgets)/|^lib/shared/ui_kit/'
)

if [[ ${#CHANGED_UI_PROD_DART[@]} -gt 0 ]]; then
  has_widget_test_delta="false"
  for test_file in "${CHANGED_TEST_FILES[@]}"; do
    if [[ -f "$test_file" ]] && file_contains_regex 'testWidgets\(' "$test_file"; then
      has_widget_test_delta="true"
      break
    fi
  done

  if [[ "$has_widget_test_delta" != "true" ]]; then
    register_issue "ui_widget_test" "lib/**/(presentation|widgets)/**|lib/shared/ui_kit/**" "UI code changed without testWidgets delta"
  fi

  for ui_file in "${CHANGED_UI_PROD_DART[@]}"; do
    in_ui_scope="false"

    if matches_regex_list_file "$ui_file" "$COVERAGE_INCLUDE_FILE"; then
      if ! matches_regex_list_file "$ui_file" "$COVERAGE_EXCLUDE_FILE"; then
        in_ui_scope="true"
      fi
    fi

    if [[ "$in_ui_scope" != "true" ]]; then
      if has_direct_widget_test_for_ui_file "$ui_file"; then
        continue
      fi
      register_issue "ui_scope_admission" "$ui_file" "UI file changed outside unified coverage scope; add include pattern + tests or add direct file-level widget tests"
    fi
  done
fi

if [[ -f "$COVERAGE_INCLUDE_FILE" ]]; then
  mapfile -t LIB_DART_FILES < <(list_dart_files_under_lib)

  while IFS= read -r pattern; do
    [[ -z "${pattern// }" ]] && continue

    effective_shrink="false"
    for src_file in "${LIB_DART_FILES[@]}"; do
      [[ -z "$src_file" ]] && continue

      if [[ ! "$src_file" =~ $pattern ]]; then
        continue
      fi

      # If file is excluded, include-pattern removal has no scoped effect.
      if matches_regex_list_file "$src_file" "$COVERAGE_EXCLUDE_FILE"; then
        continue
      fi

      # Removed include pattern is only a real shrink when an affected file is no
      # longer covered by the current include allow-list.
      if ! matches_regex_list_file "$src_file" "$COVERAGE_INCLUDE_FILE"; then
        effective_shrink="true"
        break
      fi
    done

    if [[ "$effective_shrink" == "true" ]]; then
      register_issue "scope_shrink" "coverage_include_removed:${pattern}" "coverage include pattern removed"
    fi
  done < <(extract_diff_payload_lines "remove" "$COVERAGE_INCLUDE_FILE")
fi

if [[ -f "$COVERAGE_EXCLUDE_FILE" ]]; then
  while IFS= read -r pattern; do
    register_issue "scope_shrink" "coverage_exclude_added:${pattern}" "coverage exclude pattern added"
  done < <(extract_diff_payload_lines "add" "$COVERAGE_EXCLUDE_FILE")
fi

if [[ -f "$MUTATION_TARGETS_FILE" ]]; then
  while IFS= read -r removed_line; do
    src="${removed_line%%|*}"
    register_issue "scope_shrink" "mutation_target_removed:${src}" "mutation target removed"
  done < <(extract_diff_payload_lines "remove" "$MUTATION_TARGETS_FILE")
fi

if [[ -f "$MUTATION_EXCLUDES_FILE" ]]; then
  while IFS= read -r added_line; do
    src_line="${added_line%%|*}"
    register_issue "scope_shrink" "mutation_exclude_added:${src_line}" "mutation exclude added"
  done < <(extract_diff_payload_lines "add" "$MUTATION_EXCLUDES_FILE")
fi

if [[ -n "$QUALITY_SNAPSHOT_FILE" && -f "$QUALITY_SNAPSHOT_FILE" && -f "$MUTATION_TARGETS_FILE" ]]; then
  high_risk_modules="$(grep -E '^[[:space:]]*HIGH_RISK_MODULES=' "$QUALITY_SNAPSHOT_FILE" | tail -n 1 | cut -d'=' -f2- | tr -d '[:space:]')"

  if [[ -n "${high_risk_modules:-}" ]]; then
    declare -A TARGET_SET=()
    while IFS='|' read -r src _cmd; do
      [[ -z "${src// }" || "${src:0:1}" == "#" ]] && continue
      TARGET_SET["$src"]=1
    done <"$MUTATION_TARGETS_FILE"

    IFS=',' read -r -a HIGH_RISK_ARRAY <<<"$high_risk_modules"
    for module in "${HIGH_RISK_ARRAY[@]}"; do
      module_trimmed="$(echo "$module" | tr -d '[:space:]')"
      [[ -z "$module_trimmed" ]] && continue
      if [[ -z "${TARGET_SET[$module_trimmed]+set}" ]]; then
        register_issue "mutation_parity" "$module_trimmed" "high-risk module missing in mutation targets"
      fi
    done
  fi
fi

echo "[test-quality-guards] Base ref: $BASE_REF_RESOLVED"
echo "[test-quality-guards] Merge base: $MERGE_BASE"
echo "[test-quality-guards] Changed files: ${#CHANGED_FILES[@]}"
echo "[test-quality-guards] Changed prod Dart files: ${#CHANGED_PROD_DART[@]}"
echo "[test-quality-guards] Changed test files: ${#CHANGED_TEST_FILES[@]}"
if [[ -z "$EXCEPTIONS_APPROVED_BY" ]]; then
  echo "[test-quality-guards] TEST_EXCEPTION waivers: disabled (no --exceptions-approved-by provided)"
else
  echo "[test-quality-guards] TEST_EXCEPTION waivers: enabled for approver '${EXCEPTIONS_APPROVED_BY}'"
fi
echo "[test-quality-guards] Waived by TEST_EXCEPTION: ${#WAIVED[@]}"

if [[ ${#WAIVED[@]} -gt 0 ]]; then
  echo "[test-quality-guards] Waived issues:"
  for item in "${WAIVED[@]}"; do
    IFS='|' read -r issue_type subject detail <<<"$item"
    echo "  - [$issue_type] $subject :: $detail"
  done
fi

if [[ ${#ISSUES[@]} -gt 0 ]]; then
  echo "[test-quality-guards] ERROR: ${#ISSUES[@]} issue(s) found." >&2
  for item in "${ISSUES[@]}"; do
    IFS='|' read -r issue_type subject detail <<<"$item"
    echo "  - [$issue_type] $subject :: $detail" >&2
  done
  exit 1
fi

echo "[test-quality-guards] OK"
