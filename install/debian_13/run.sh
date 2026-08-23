# Install order for Debian 13.
#
# Sourced by install.sh, which provides run() and the helpers.

DEPENDENCIES=$(packages install/debian_13/dependencies) || exit 1

echo -e "\e[0;34m- dependencies\e[0m"
log "$(echo $DEPENDENCIES)"

apt_update > /dev/null
apt_install $DEPENDENCIES > /dev/null

run install/debian_13/modules/base.sh
run install/debian_13/modules/scripts.sh
run install/debian_13/modules/docker.sh
run install/debian_13/modules/postgresql.sh
run install/debian_13/modules/mise.sh
run install/debian_13/modules/mise_ai_agents.sh
run install/debian_13/modules/git.sh
run install/debian_13/modules/bash_aliases.sh
run install/debian_13/modules/nano.sh
run install/debian_13/modules/gnome_keybindings.sh
run install/debian_13/modules/gnome_tweaks.sh
