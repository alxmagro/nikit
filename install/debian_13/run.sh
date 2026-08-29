# Install order for Debian 13.
#
# Sourced by install.sh, which provides run() and the helpers.

DEPENDENCIES=$(packages install/debian_13/dependencies) || exit 1

log "Installing dependencies: $(echo $DEPENDENCIES)"

apt_update > /dev/null
apt_install $DEPENDENCIES > /dev/null

run install/debian_13/modules/scripts.sh
run install/debian_13/modules/docker.sh
run install/debian_13/modules/postgresql.sh
run install/debian_13/modules/mise.sh
run install/debian_13/modules/git.sh
run install/debian_13/modules/bash_aliases.sh
run install/debian_13/modules/nano.sh
run install/debian_13/modules/gnome_keybindings.sh
run install/debian_13/modules/fonts.sh
