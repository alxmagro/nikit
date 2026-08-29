#!/bin/bash
#
# Runs the install modules for one OS, in the order its run.sh declares.
#
# Usage:
#   ./install.sh                          List the supported systems and their modules
#   ./install.sh debian_13                Run everything for one OS
#   ./install.sh debian_13 scripts docker Run only the modules named

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

# Module names for one OS, in the order its run.sh declares them. Falls back
# to the modules/ directory if run.sh names none.
modules() {
  local os="$1" names

  names=$(grep -oE 'modules/[A-Za-z0-9_.-]+\.sh' "$SH_INSTALL/$os/run.sh" 2>/dev/null \
    | sed 's#.*/##; s#\.sh$##')

  if [ -z "$names" ] && [ -d "$SH_INSTALL/$os/modules" ]; then
    names=$(cd "$SH_INSTALL/$os/modules" && for f in *.sh; do
      [ -e "$f" ] && basename "$f" .sh
    done)
  fi

  echo "$names"
}

if [ $# -eq 0 ]; then
  echo "Usage: ./install.sh <os> [script...]"
  echo
  echo "Supported systems:"
  systems | while read -r os; do
    echo
    echo "$os:"
    modules "$os" | sed 's/^/  - /'
  done
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
    run "install/$OS/modules/$script.sh"
  done
else
  source "$SH_INSTALL/$OS/run.sh"
fi

success 'Done!'
