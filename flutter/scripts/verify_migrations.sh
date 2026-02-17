#!/usr/bin/env bash
set -euo pipefail

BASE_REF=""
COMPARE_RANGE=""

usage() {
  cat <<'EOF'
Usage: ./scripts/verify_migrations.sh [--base-ref <ref>] [--compare-range <range>]

Verifies changed Supabase migration files for:
- naming and ordering constraints
- migration immutability (no delete/rename)
- safety patterns (destructive SQL allowed only in *_contract.sql, broad grants/default privileges)
- basic idempotency assumptions (CREATE INDEX should use IF NOT EXISTS)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-ref)
      BASE_REF="${2:-}"
      shift 2
      ;;
    --compare-range)
      COMPARE_RANGE="${2:-}"
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

resolve_compare_range() {
  if [[ -n "$COMPARE_RANGE" ]]; then
    echo "$COMPARE_RANGE"
    return
  fi

  if [[ -n "$BASE_REF" ]]; then
    echo "$BASE_REF...HEAD"
    return
  fi

  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    echo "origin/${GITHUB_BASE_REF}...HEAD"
    return
  fi

  if [[ -n "${GITHUB_EVENT_BEFORE:-}" && "${GITHUB_EVENT_BEFORE}" != "0000000000000000000000000000000000000000" ]]; then
    echo "${GITHUB_EVENT_BEFORE}...${GITHUB_SHA:-HEAD}"
    return
  fi

  # Local default: compare all not-yet-pushed commits, not only HEAD~1.
  local upstream_ref=""
  local base_commit=""
  if upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
    if base_commit="$(git merge-base HEAD "$upstream_ref" 2>/dev/null)" && [[ -n "$base_commit" ]]; then
      echo "${base_commit}...HEAD"
      return
    fi
  fi

  if git rev-parse --verify --quiet HEAD~1 >/dev/null; then
    echo "HEAD~1...HEAD"
    return
  fi

  echo ""
}

COMPARE_RANGE="$(resolve_compare_range)"

if [[ -z "$COMPARE_RANGE" ]]; then
  echo "[migration-verify] No comparison range available (likely initial commit). Skipping."
  exit 0
fi

BASE_COMMIT="${COMPARE_RANGE%%...*}"
if ! git rev-parse --verify --quiet "$BASE_COMMIT" >/dev/null; then
  echo "[migration-verify] Base ref for range '$COMPARE_RANGE' is not available. Skipping."
  echo "[migration-verify] Hint: run with --base-ref <ref> or fetch more git history."
  exit 0
fi

if ! DIFF_STATUS="$(git diff --name-status "$COMPARE_RANGE" -- supabase/migrations)"; then
  echo "[migration-verify] Failed to compute migration diff for range '$COMPARE_RANGE'." >&2
  exit 1
fi

if [[ -z "$DIFF_STATUS" ]]; then
  echo "[migration-verify] No migration file changes detected."
  exit 0
fi

ERRORS=0
WARNINGS=0

echo "[migration-verify] Compare range: $COMPARE_RANGE"

while IFS= read -r row; do
  [[ -z "$row" ]] && continue
  status="$(awk '{print $1}' <<<"$row")"
  path="$(awk '{print $2}' <<<"$row")"

  if [[ "$status" =~ ^(D|R) ]]; then
    echo "[migration-verify] ERROR: Migration immutability violated ($status): $path" >&2
    ERRORS=$((ERRORS + 1))
  fi
done <<<"$DIFF_STATUS"

if ! ls supabase/migrations/*.sql >/dev/null 2>&1; then
  echo "[migration-verify] ERROR: No migration files found in supabase/migrations." >&2
  exit 1
fi

mapfile -t ALL_MIGRATIONS < <(ls -1 supabase/migrations/*.sql | sed 's#^supabase/migrations/##')

CURRENT_ORDER="$(printf '%s\n' "${ALL_MIGRATIONS[@]}")"
SORTED_ORDER="$(printf '%s\n' "${ALL_MIGRATIONS[@]}" | sort)"
if [[ "$CURRENT_ORDER" != "$SORTED_ORDER" ]]; then
  echo "[migration-verify] ERROR: Migration files are not lexicographically ordered." >&2
  ERRORS=$((ERRORS + 1))
fi

DUPLICATE_PREFIXES="$(printf '%s\n' "${ALL_MIGRATIONS[@]}" | awk -F'_' '{print $1}' | sort | uniq -d || true)"
if [[ -n "$DUPLICATE_PREFIXES" ]]; then
  echo "[migration-verify] ERROR: Duplicate migration timestamp prefixes found:" >&2
  printf '%s\n' "$DUPLICATE_PREFIXES" >&2
  ERRORS=$((ERRORS + 1))
fi

mapfile -t CHANGED_MIGRATIONS < <(printf '%s\n' "$DIFF_STATUS" | awk '$1 ~ /^(A|M|C)$/ {print $2}' | grep -E '^supabase/migrations/.*\.sql$' || true)

matches_regex() {
  local regex="$1"
  local file="$2"
  grep -E -i "$regex" "$file" >/dev/null
}

for migration in "${CHANGED_MIGRATIONS[@]}"; do
  [[ -f "$migration" ]] || continue
  base_name="$(basename "$migration")"
  is_contract_migration=0
  if [[ "$base_name" == *_contract.sql ]]; then
    is_contract_migration=1
  fi

  if [[ ! "$base_name" =~ ^[0-9]{14}_.+\.sql$ && ! "$base_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}_.+\.sql$ ]]; then
    echo "[migration-verify] ERROR: Invalid migration filename format: $migration" >&2
    ERRORS=$((ERRORS + 1))
  fi

  if matches_regex '(^|[^[:alnum:]_])DROP[[:space:]]+TABLE([^[:alnum:]_]|$)' "$migration"; then
    if [[ "$is_contract_migration" -eq 0 ]]; then
      echo "[migration-verify] ERROR: DROP TABLE is only allowed in *_contract.sql migrations: $migration" >&2
      ERRORS=$((ERRORS + 1))
    fi
  fi

  if matches_regex 'ALTER[[:space:]]+TABLE[[:space:][:print:]]*DROP[[:space:]]+COLUMN' "$migration"; then
    if [[ "$is_contract_migration" -eq 0 ]]; then
      echo "[migration-verify] ERROR: DROP COLUMN is only allowed in *_contract.sql migrations: $migration" >&2
      ERRORS=$((ERRORS + 1))
    fi
  fi

  if matches_regex '(^|[^[:alnum:]_])TRUNCATE([^[:alnum:]_]|$)' "$migration"; then
    if [[ "$is_contract_migration" -eq 0 ]]; then
      echo "[migration-verify] ERROR: TRUNCATE is only allowed in *_contract.sql migrations: $migration" >&2
      ERRORS=$((ERRORS + 1))
    fi
  fi

  if matches_regex 'ALTER[[:space:]]+DEFAULT[[:space:]]+PRIVILEGES[[:space:][:print:]]+GRANT[[:space:]]+ALL[[:space:]]+ON[[:space:]]+FUNCTIONS?[[:space:][:print:]]+TO[[:space:]]+"?(anon|authenticated)"?' "$migration"; then
    echo "[migration-verify] ERROR: Broad default function grants to anon/authenticated are forbidden: $migration" >&2
    ERRORS=$((ERRORS + 1))
  fi

  if matches_regex 'GRANT[[:space:]]+ALL[[:space:]]+ON[[:space:]]+FUNCTION[[:space:][:print:]]+TO[[:space:]]+"?(anon|authenticated)"?' "$migration"; then
    echo "[migration-verify] ERROR: GRANT ALL ON FUNCTION to anon/authenticated is forbidden: $migration" >&2
    ERRORS=$((ERRORS + 1))
  fi

  if matches_regex 'CREATE[[:space:]]+INDEX' "$migration" && ! matches_regex 'CREATE[[:space:]]+INDEX[[:space:]]+IF[[:space:]]+NOT[[:space:]]+EXISTS' "$migration"; then
    echo "[migration-verify] WARNING: CREATE INDEX without IF NOT EXISTS detected: $migration" >&2
    WARNINGS=$((WARNINGS + 1))
  fi

  if matches_regex '(^|[^[:alnum:]_])UPDATE([^[:alnum:]_]|$)' "$migration" && matches_regex 'ALTER[[:space:]]+TABLE' "$migration"; then
    if ! matches_regex '^[[:space:]]*(BEGIN|COMMIT)($|[[:space:];])' "$migration"; then
      echo "[migration-verify] WARNING: Mixed DDL+DML migration without explicit transaction markers: $migration" >&2
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
done

echo "[migration-verify] Changed migrations inspected: ${#CHANGED_MIGRATIONS[@]}"
echo "[migration-verify] Warnings: $WARNINGS"
echo "[migration-verify] Errors: $ERRORS"

if [[ "$ERRORS" -gt 0 ]]; then
  exit 1
fi

echo "[migration-verify] OK: migration verification passed."
