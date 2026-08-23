#!/bin/bash
#
# Runs the install modules for one OS, in the order its run.sh declares.
#
# Usage:
#   ./install.sh                          List the supported systems
#   ./install.sh debian_13                Run everything for one OS
#   ./install.sh debian_13 docker.sh      Run only the scripts named

set -e

SH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH_INSTALL="$SH_ROOT/install"
export SH_ROOT SH_INSTALL

source "$SH_INSTALL/helpers/common.sh"

systems() {
  local dir

  for dir in "$SH_INSTALL"/*/; do
    [ -f "$dir/run.sh" ] && basename "$dir"
  done
}

if [ $# -eq 0 ]; then
  echo "Usage: ./install.sh <os> [script...]"
  echo
  echo "Supported systems:"
  systems | sed 's/^/  /'
  exit 1
fi

OS="$1"
shift

[ -d "$SH_INSTALL/$OS" ] || abort "No install scripts for $OS (looked in install/$OS)"

echo -e "\e[1mSetting up your system ($OS)\e[0m"
echo

# Ask once, up front. Later modules then run without interrupting the list.
if ! sudo -n true 2>/dev/null; then
  sudo -v || exit 1
  echo
fi

if [ $# -gt 0 ]; then
  for script in "$@"; do
    run "install/$OS/modules/$script"
  done
else
  source "$SH_INSTALL/$OS/run.sh"
fi

success 'Done!'
