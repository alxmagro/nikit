#!/bin/bash

set -e

FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

log 'Installing fonts...'

# They travel with the repo: Debian carries Inter and Open Sans, but not
# Roboto Mono, and the ones it does carry are older static builds.
ensure_folder "$FONT_DIR"

cp "$SH_ROOT"/assets/fonts/*.ttf "$FONT_DIR/"
fc-cache -f "$FONT_DIR" > /dev/null
