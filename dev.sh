#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

target="${1:-menu}"

stop_existing_menu_bar() {
  local pids
  if pids="$(pgrep -x RelayDogMenuBar 2>/dev/null)"; then
    echo "Stopping existing RelayDogMenuBar instance..."
    kill $pids 2>/dev/null || true
  fi
}

case "$target" in
  menu | menubar | app)
    stop_existing_menu_bar
    exec swift run RelayDogMenuBar
    ;;
  daemon | relaydogd)
    exec swift run relaydogd
    ;;
  -h | --help | help)
    echo "Usage: ./dev.sh [menu|daemon]"
    echo
    echo "  menu     Run the macOS menu bar app (default)"
    echo "  daemon   Run the local proxy daemon"
    ;;
  *)
    echo "Unknown target: $target" >&2
    echo "Usage: ./dev.sh [menu|daemon]" >&2
    exit 64
    ;;
esac
