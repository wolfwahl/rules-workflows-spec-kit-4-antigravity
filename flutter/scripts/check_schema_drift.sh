#!/usr/bin/env bash
set -euo pipefail

BASE_REF=""
COMPARE_RANGE=""

usage() {
  cat <<'EOF'
Usage: ./scripts/check_schema_drift.sh [--base-ref <ref>] [--compare-range <range>]

Checks for repository-level Supabase schema drift by enforcing:
1) migration changes in supabase/migrations/*.sql must include supabase/dump/schema.sql
2) supabase/dump/schema.sql must not change without migration changes
3) supabase/dump/schema.sql must not be empty when changed
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
  echo "[schema-drift] No comparison range available (likely initial commit). Skipping."
  exit 0
fi

if ! git rev-parse --verify --quiet "${COMPARE_RANGE%%...*}" >/dev/null; then
  echo "[schema-drift] Base ref for range '$COMPARE_RANGE' is not available. Skipping."
  echo "[schema-drift] Hint: run with --base-ref <ref> or fetch more git history."
  exit 0
fi

if ! CHANGED_FILES="$(git diff --name-only "$COMPARE_RANGE")"; then
  echo "[schema-drift] Failed to compute changed files for range '$COMPARE_RANGE'." >&2
  exit 1
fi

MIGRATION_MATCHES="$(printf '%s\n' "$CHANGED_FILES" | grep -E '^supabase/migrations/.*\.sql$' || true)"
SCHEMA_DUMP_MATCHES="$(printf '%s\n' "$CHANGED_FILES" | grep -E '^supabase/dump/schema\.sql$' || true)"

MIGRATION_CHANGED=0
SCHEMA_DUMP_CHANGED=0

if [[ -n "$MIGRATION_MATCHES" ]]; then
  MIGRATION_CHANGED=1
fi
if [[ -n "$SCHEMA_DUMP_MATCHES" ]]; then
  SCHEMA_DUMP_CHANGED=1
fi

echo "[schema-drift] Compare range: $COMPARE_RANGE"
echo "[schema-drift] Migration changes detected: $MIGRATION_CHANGED"
echo "[schema-drift] Dump changes detected: $SCHEMA_DUMP_CHANGED"

if [[ "$MIGRATION_CHANGED" -eq 1 && "$SCHEMA_DUMP_CHANGED" -eq 0 ]]; then
  echo "[schema-drift] ERROR: supabase migrations changed, but supabase/dump/schema.sql was not updated." >&2
  echo "[schema-drift] Changed migrations:" >&2
  printf '%s\n' "$MIGRATION_MATCHES" >&2
  exit 1
fi

if [[ "$MIGRATION_CHANGED" -eq 0 && "$SCHEMA_DUMP_CHANGED" -eq 1 ]]; then
  echo "[schema-drift] ERROR: supabase/dump/schema.sql changed without migration changes." >&2
  exit 1
fi

if [[ "$SCHEMA_DUMP_CHANGED" -eq 1 && ! -s supabase/dump/schema.sql ]]; then
  echo "[schema-drift] ERROR: supabase/dump/schema.sql is empty." >&2
  exit 1
fi

echo "[schema-drift] OK: no repository-level schema drift detected."
