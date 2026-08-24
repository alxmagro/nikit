#!/bin/bash

set -e

if command -v mise > /dev/null; then
  log 'already installed, skipping'
else
  log 'Installing mise...'

  apt_install extrepo
  sudo extrepo enable mise
  apt_update
  apt_install mise
fi

# Outside the guard: installing the binary is not what puts ruby and node on
# the PATH, this line is, and a machine that already had mise still needs it.
log 'Activating mise in the shell...'

append_once "$HOME/.bashrc" 'eval "$(mise activate bash)"'
