#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

required_hooks=(
  ".githooks/pre-commit"
  ".githooks/pre-push"
)

for hook in "${required_hooks[@]}"; do
  if [[ ! -f "$hook" ]]; then
    echo "[hooks] ERROR: ${hook} not found." >&2
    exit 1
  fi
done

chmod +x .githooks/pre-commit .githooks/pre-push
git config core.hooksPath .githooks

echo "[hooks] Installed hooks path: .githooks"
echo "[hooks] pre-commit hook is active."
echo "[hooks] pre-push hook is active."
