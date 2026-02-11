#!/usr/bin/env bash
set -euo pipefail

run_unix_flutter() {
  flutter "$@"
}

run_windows_flutter_from_wsl() {
  if ! command -v cmd.exe >/dev/null 2>&1; then
    return 1
  fi

  local win_pwd
  win_pwd="$(wslpath -m "$PWD")"

  local cmdline
  cmdline="cd /d $win_pwd && flutter"

  local arg
  for arg in "$@"; do
    cmdline="$cmdline $arg"
  done

  cmd.exe /d /c "$cmdline"
}

if command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"

  if [[ -n "${WSL_DISTRO_NAME:-}" ]] && file "$flutter_bin" | grep -qi "CRLF"; then
    run_windows_flutter_from_wsl "$@"
    exit $?
  fi

  run_unix_flutter "$@"
  exit 0
fi

if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  run_windows_flutter_from_wsl "$@"
  exit $?
fi

echo "flutter command not found in PATH." >&2
exit 1
