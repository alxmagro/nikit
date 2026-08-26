#!/bin/bash

set -e

log 'Copying commands...'

# Emptied rather than copied over: a file that was renamed or dropped would
# otherwise keep being loaded from an earlier install. config/ is left alone.
rm -rf "$PROJECT_ROOT/python" "$PROJECT_ROOT/shell" "$PROJECT_ROOT/init.sh"

ensure_folder "$PROJECT_ROOT"

cp -r "$SH_ROOT"/src/* "$PROJECT_ROOT/"

append_once "$HOME/.bashrc" 'source ~/.local/share/nikit/init.sh'
