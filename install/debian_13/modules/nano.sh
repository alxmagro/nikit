#!/bin/bash

set -e

log 'Writing nanorc...'

# The same set as nano's --modernbindings flag, spelled out: that flag has no
# `set` equivalent, and an alias would not reach the nano that git, sudoedit
# or gistpad open.
cat > "$HOME/.nanorc" << 'EOF'
bind ^X cut main
bind ^C copy main
bind ^V paste main
bind ^Z undo main
bind ^Y redo main
bind ^A mark main

bind ^S savefile main
bind ^W writeout main
bind ^O insert main
bind ^Q exit all

bind ^F whereis all
bind ^G findnext all
bind ^D findprevious all
bind ^R replace main

bind ^P location main
bind ^T gotoline main
bind ^E execute main
bind ^H help all

# Backspace and Delete erase the marked region when there is one.
set zap
EOF
