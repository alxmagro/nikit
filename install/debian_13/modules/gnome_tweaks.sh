#!/bin/bash

set -e

# gsettings talks over D-Bus, which an SSH session does not have.
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  log 'no desktop session, skipping'
  exit 0
fi

FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

log 'Installing fonts...'

# They travel with the repo: Debian carries Inter and Open Sans, but not
# Roboto Mono, and the ones it does carry are older static builds.
ensure_folder "$FONT_DIR"

cp "$SH_ROOT"/assets/fonts/*.ttf "$FONT_DIR/"
fc-cache -f "$FONT_DIR" > /dev/null

log 'Setting fonts and titlebar buttons...'

gsettings set org.gnome.desktop.interface font-name 'Inter 9'
gsettings set org.gnome.desktop.interface document-font-name 'Open Sans 10'
gsettings set org.gnome.desktop.interface monospace-font-name 'Roboto Mono 10'

# Close on the left. The layout is 'left:right', and the buttons left out of
# it simply do not appear.
gsettings set org.gnome.desktop.wm.preferences button-layout 'close:appmenu'
