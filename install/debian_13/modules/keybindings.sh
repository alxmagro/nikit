#!/bin/bash

set -e

# dconf talks over D-Bus, which an SSH session does not have.
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  log 'no desktop session, skipping'
  exit 0
fi

log 'Applying GNOME keybindings...'

# Super+arrows drive workspaces and window state, so the side tiling and
# the app grid give up those keys. Alt+Tab walks windows, not applications.
dconf load /org/gnome/desktop/wm/keybindings/ << 'EOF'
[/]
maximize=['<Super>Up']
unmaximize=['<Super>Down', '<Alt>F5']
switch-to-workspace-left=['<Super>Left']
switch-to-workspace-right=['<Super>Right']
move-to-workspace-left=['<Alt><Super>Left']
move-to-workspace-right=['<Alt><Super>Right']
show-desktop=['<Alt><Super>Down']
switch-windows=['<Alt>Tab']
switch-windows-backward=['<Shift><Alt>Tab']
switch-applications=@as []
switch-applications-backward=@as []
switch-input-source=@as []
switch-input-source-backward=@as []
EOF

dconf load /org/gnome/shell/keybindings/ << 'EOF'
[/]
toggle-application-view=@as []
EOF

dconf load /org/gnome/mutter/keybindings/ << 'EOF'
[/]
toggle-tiled-left=@as []
toggle-tiled-right=@as []
EOF

# A custom shortcut is a two-step affair: the plugin holds a list of paths,
# and each path holds one name/command/binding triple.
dconf load /org/gnome/settings-daemon/plugins/media-keys/ << 'EOF'
[/]
custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/console/']

[custom-keybindings/console]
name='Console'
command='kgx'
binding='<Super>r'
EOF
