#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/verify_dod.sh [--source-control|--staged] [--coverage-scope <changed-files|feature-wide>] [--no-coverage-gate]

Commit-only Definition-of-Done verifier:
- default: uses source-control changes (staged + unstaged + untracked),
- optional: --staged limits scope to index-only commit view,
- default coverage scope is changed production files only,
- optional: --coverage-scope feature-wide expands coverage scope to broader module patterns,
- default does not fail on branch/line coverage threshold (local DoD only),
- optional: --coverage-gate enables failing coverage threshold checks,
- skips mutation by design (for fast local commits).
USAGE
}

mode="source-control"
coverage_scope="changed-files"
coverage_gate="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-control)
      mode="source-control"
      shift
      ;;
    --staged)
      mode="staged"
      shift
      ;;
    --worktree)
      # Backward-compatible alias
      mode="source-control"
      shift
      ;;
    --coverage-scope)
      coverage_scope="${2:-}"
      if [[ "$coverage_scope" != "changed-files" && "$coverage_scope" != "feature-wide" ]]; then
        echo "[dod] ERROR: --coverage-scope must be 'changed-files' or 'feature-wide'." >&2
        usage >&2
        exit 2
      fi
      shift 2
      ;;
    --no-coverage-gate)
      coverage_gate="false"
      shift
      ;;
    --coverage-gate)
      coverage_gate="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[dod] ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

declare -A RAW_CHANGED_SET=()
declare -A STAGED_SET=()
declare -A UNSTAGED_SET=()
declare -A UNTRACKED_SET=()

if [[ "$mode" == "staged" ]]; then
  mapfile -t RAW_STAGED_FILES < <(git diff --cached --name-only --diff-filter=ACMR)
  for file in "${RAW_STAGED_FILES[@]}"; do
    STAGED_SET["$file"]=1
    RAW_CHANGED_SET["$file"]=1
  done
else
  mapfile -t RAW_STAGED_FILES < <(git diff --cached --name-only --diff-filter=ACMR)
  mapfile -t RAW_UNSTAGED_FILES < <(git diff --name-only --diff-filter=ACMR)
  mapfile -t RAW_UNTRACKED_FILES < <(git ls-files --others --exclude-standard)

  for file in "${RAW_STAGED_FILES[@]}"; do
    STAGED_SET["$file"]=1
    RAW_CHANGED_SET["$file"]=1
  done
  for file in "${RAW_UNSTAGED_FILES[@]}"; do
    UNSTAGED_SET["$file"]=1
    RAW_CHANGED_SET["$file"]=1
  done
  for file in "${RAW_UNTRACKED_FILES[@]}"; do
    UNTRACKED_SET["$file"]=1
    RAW_CHANGED_SET["$file"]=1
  done
fi

CHANGED_FILES=()

for file in "${!RAW_CHANGED_SET[@]}"; do
  if [[ -n "${UNTRACKED_SET[$file]:-}" ]]; then
    CHANGED_FILES+=("$file")
    continue
  fi

  staged_semantic="false"
  unstaged_semantic="false"

  if [[ -n "${STAGED_SET[$file]:-}" ]]; then
    # Ignore pure line-ending flips in staged changes.
    if ! git diff --cached --ignore-cr-at-eol --quiet -- "$file"; then
      staged_semantic="true"
    fi
  fi

  if [[ -n "${UNSTAGED_SET[$file]:-}" ]]; then
    # Ignore pure line-ending flips in unstaged changes.
    if ! git diff --ignore-cr-at-eol --quiet -- "$file"; then
      unstaged_semantic="true"
    fi
  fi

  if [[ "$staged_semantic" == "true" || "$unstaged_semantic" == "true" ]]; then
    CHANGED_FILES+=("$file")
  fi
done

if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
  mapfile -t CHANGED_FILES < <(printf '%s\n' "${CHANGED_FILES[@]}" | sort -u)
fi

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  if [[ "$mode" == "staged" ]]; then
    mapfile -t RAW_UNSTAGED_HINT < <(git diff --name-only --diff-filter=ACMR)
    mapfile -t RAW_UNTRACKED_HINT < <(git ls-files --others --exclude-standard)
    if [[ ${#RAW_UNSTAGED_HINT[@]} -gt 0 || ${#RAW_UNTRACKED_HINT[@]} -gt 0 ]]; then
      echo "[dod] No semantic staged changes detected. Nothing to validate."
      echo "[dod] Hint: unstaged/untracked changes exist. Use '--source-control' or stage files first."
      exit 0
    fi
  fi

  if [[ "$mode" == "source-control" ]]; then
    echo "[dod] No semantic source-control changes detected. Nothing to validate."
  else
    echo "[dod] No semantic staged changes detected. Nothing to validate."
  fi
  exit 0
fi

is_dod_relevant_file() {
  local file="$1"
  [[ "$file" =~ ^lib/.*\.dart$ ]] && return 0
  [[ "$file" =~ ^test/.*\.dart$ ]] && return 0
  [[ "$file" =~ ^ops/testing/ ]] && return 0
  [[ "$file" =~ ^scripts/(verify_coverage_baseline|generate_quality_baseline_report|verify_test_quality_guards|verify_dod|run_local_ci)\.sh$ ]] && return 0
  [[ "$file" == ".github/workflows/flutter-ci.yml" ]] && return 0
  [[ "$file" =~ ^\.agent/rules/ ]] && return 0
  return 1
}

dod_relevant="false"
for file in "${CHANGED_FILES[@]}"; do
  if is_dod_relevant_file "$file"; then
    dod_relevant="true"
    break
  fi
done

if [[ "$dod_relevant" != "true" ]]; then
  echo "[dod] No DoD-relevant changes detected for mode '$mode'. Skipping heavy DoD checks."
  exit 0
fi

mapfile -t CHANGED_PROD_DART < <(
  printf '%s\n' "${CHANGED_FILES[@]}" \
    | rg '^lib/.*\.dart$' \
    | rg -v '\.(g|freezed|mocks|gen)\.dart$|^lib/l10n/.*\.dart$' || true
)

mapfile -t CHANGED_UI_DART < <(
  printf '%s\n' "${CHANGED_FILES[@]}" \
    | rg '^lib/.*/(presentation|widgets)/.*\.dart$|^lib/shared/ui_kit/.*\.dart$' || true
)

mapfile -t CHANGED_TEST_FILES < <(
  printf '%s\n' "${CHANGED_FILES[@]}" \
    | rg '^test/.*_test\.dart$' || true
)

if [[ ${#CHANGED_PROD_DART[@]} -gt 0 && ${#CHANGED_TEST_FILES[@]} -eq 0 ]]; then
  echo "[dod] ERROR: production Dart changed without *_test.dart delta." >&2
  exit 1
fi

if [[ ${#CHANGED_UI_DART[@]} -gt 0 ]]; then
  widget_delta="false"
  for test_file in "${CHANGED_TEST_FILES[@]}"; do
    if [[ "$mode" == "staged" ]]; then
      content="$(git show ":$test_file" 2>/dev/null || true)"
    else
      content="$(cat "$test_file" 2>/dev/null || true)"
    fi
    if printf '%s' "$content" | rg -q 'testWidgets\('; then
      widget_delta="true"
      break
    fi
  done

  if [[ "$widget_delta" != "true" ]]; then
    echo "[dod] ERROR: UI files changed without testWidgets delta." >&2
    exit 1
  fi
fi

declare -A TARGET_TEST_SET=()

add_test_file_if_exists() {
  local test_file="$1"
  [[ -f "$test_file" ]] && TARGET_TEST_SET["$test_file"]=1
}

collect_tests_for_dir() {
  local test_dir="$1"
  [[ -d "$test_dir" ]] || return
  while IFS= read -r test_file; do
    TARGET_TEST_SET["$test_file"]=1
  done < <(rg --files "$test_dir" | rg '_test\.dart$' || true)
}

for file in "${CHANGED_FILES[@]}"; do
  if [[ "$file" =~ ^test/.*_test\.dart$ ]]; then
    TARGET_TEST_SET["$file"]=1
    continue
  fi

  if [[ "$file" =~ ^lib/features/([^/]+)/ ]]; then
    collect_tests_for_dir "test/features/${BASH_REMATCH[1]}"
    continue
  fi

  if [[ "$file" =~ ^lib/shared/([^/]+)/ ]]; then
    collect_tests_for_dir "test/shared/${BASH_REMATCH[1]}"
    continue
  fi

  if [[ "$file" =~ ^lib/core/ ]]; then
    collect_tests_for_dir "test/core"
    continue
  fi

  if [[ "$file" =~ ^lib/config/ ]]; then
    collect_tests_for_dir "test/config"
    continue
  fi

  if [[ "$file" == "lib/main.dart" ]]; then
    add_test_file_if_exists "test/widget_test.dart"
  fi
done

TARGET_TEST_FILES=()
if [[ ${#TARGET_TEST_SET[@]} -gt 0 ]]; then
  mapfile -t TARGET_TEST_FILES < <(printf '%s\n' "${!TARGET_TEST_SET[@]}" | sed '/^$/d' | sort)
fi

if [[ ${#CHANGED_PROD_DART[@]} -gt 0 && ${#TARGET_TEST_FILES[@]} -eq 0 ]]; then
  echo "[dod] ERROR: production Dart changed but no target tests found for changed scope." >&2
  exit 1
fi

scoped_include_file="$(mktemp)"
scoped_baseline_file="$(mktemp)"
trap 'rm -f "$scoped_include_file" "$scoped_baseline_file"' EXIT

declare -A COVERAGE_SCOPE_SET=()

for file in "${CHANGED_PROD_DART[@]}"; do
  escaped_file="$(printf '%s' "$file" | sed -E 's/[][(){}.+*?^$|\\]/\\&/g')"
  COVERAGE_SCOPE_SET["^${escaped_file}$"]=1

  if [[ "$coverage_scope" == "feature-wide" ]]; then
    if [[ "$file" =~ ^lib/features/([^/]+)/ ]]; then
      feature="${BASH_REMATCH[1]}"
      COVERAGE_SCOPE_SET["^lib/features/${feature}/(application|data|domain|services|presentation)/.*\\.dart$"]=1
    fi

    if [[ "$file" =~ ^lib/core/services/ ]]; then
      COVERAGE_SCOPE_SET["^lib/core/services/.*\\.dart$"]=1
    fi

    if [[ "$file" =~ ^lib/shared/ui_kit/ ]]; then
      COVERAGE_SCOPE_SET["^lib/shared/ui_kit/.*\\.dart$"]=1
    fi

    if [[ "$file" =~ ^lib/shared/help_system/(data|domain|presentation/widgets)/ ]]; then
      COVERAGE_SCOPE_SET["^lib/shared/help_system/(data|domain|presentation/widgets)/.*\\.dart$"]=1
    fi

    if [[ "$file" == "lib/config/router.dart" ]]; then
      COVERAGE_SCOPE_SET["^lib/config/router\\.dart$"]=1
    fi
  fi
done

printf 'MIN_LIB_COVERAGE_PCT=0\n' >"$scoped_baseline_file"
printf '# Scoped DoD include patterns (generated)\n' >"$scoped_include_file"

for pattern in "${!COVERAGE_SCOPE_SET[@]}"; do
  printf '%s\n' "$pattern" >>"$scoped_include_file"
done

echo "[dod] Coverage scope mode: $coverage_scope"
echo "[dod] Coverage gate enabled: $coverage_gate"

echo "[dod] Running analyze (commit mode)..."
./scripts/flutterw.sh analyze

if [[ ${#TARGET_TEST_FILES[@]} -gt 0 ]]; then
  echo "[dod] Running scoped tests with coverage (${#TARGET_TEST_FILES[@]} files)..."
  ./scripts/flutterw.sh test --coverage --branch-coverage "${TARGET_TEST_FILES[@]}"
else
  echo "[dod] No target tests detected for changed scope."
fi

if [[ ${#COVERAGE_SCOPE_SET[@]} -gt 0 && -f coverage/lcov.info ]]; then
  if [[ "$coverage_gate" == "true" ]]; then
    echo "[dod] Verifying scoped coverage baseline..."
    bash ./scripts/verify_coverage_baseline.sh \
      --lcov coverage/lcov.info \
      --baseline "$scoped_baseline_file" \
      --quality-gates ops/testing/quality_gates.env \
      --include-patterns "$scoped_include_file" \
      --exclude-patterns ops/testing/coverage_exclude_patterns.txt
  else
    echo "[dod] Coverage gate check skipped by --no-coverage-gate."
  fi

  ts="$(date -u +'%Y%m%d-%H%M%S')"
  mkdir -p .ciReport
  scoped_quality_report_file=".ciReport/quality_baseline_dod_scoped_${ts}.md"
  scoped_quality_snapshot_file=".ciReport/quality_baseline_dod_scoped_${ts}.env"
  scoped_quality_risk_csv_file=".ciReport/quality_risk_dod_scoped_${ts}.csv"
  scoped_quality_deps_csv_file=".ciReport/quality_dependency_edges_dod_scoped_${ts}.csv"

  echo "[dod] Generating scoped quality baseline report..."
  bash ./scripts/generate_quality_baseline_report.sh \
    --lcov coverage/lcov.info \
    --include-patterns "$scoped_include_file" \
    --exclude-patterns ops/testing/coverage_exclude_patterns.txt \
    --out-md "$scoped_quality_report_file" \
    --out-env "$scoped_quality_snapshot_file" \
    --out-csv "$scoped_quality_risk_csv_file" \
    --out-deps "$scoped_quality_deps_csv_file"
fi

echo "[dod] Mutation gate intentionally skipped in commit mode."
echo "[dod] DoD verification OK"
