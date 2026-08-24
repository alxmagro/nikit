#!/bin/bash

set -e

# Here rather than in run.sh, so that installing a single module still gets
# the packages it needs: run.sh only runs when no module is named.
DEPENDENCIES=$(packages install/debian_13/dependencies) || exit 1

log "Installing dependencies: $(echo $DEPENDENCIES)"

apt_update > /dev/null
apt_install $DEPENDENCIES > /dev/null

log 'Setting up nikit...'

ensure_folder "$PROJECT_ROOT/bin" "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/config"

cat > "$PROJECT_ROOT/init.sh" << 'EOF'
# Everything nikit adds to the shell. Sourced from ~/.bashrc.

# Local, not exported: the commands resolve this path on their own, and
# leaking it would override it for every child process.
_root="${XDG_DATA_HOME:-$HOME/.local/share}/nikit"

for _script in "$_root"/scripts/*.sh; do
  [ -f "$_script" ] && source "$_script"
done
unset _script

case ":$PATH:" in
  *":$_root/bin:"*) ;;
  *) export PATH="$PATH:$_root/bin" ;;
esac

unset _root
EOF

append_once "$HOME/.bashrc" 'source "${XDG_DATA_HOME:-$HOME/.local/share}/nikit/init.sh"'
