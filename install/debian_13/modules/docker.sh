#!/bin/bash

set -e

DOCKER_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/docker"

if command -v docker > /dev/null; then
  log 'already installed, skipping'
  exit 0
fi

log 'Installing docker...'

curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh
rm /tmp/get-docker.sh

log 'Setting docker daemon...'

sudo systemctl stop docker.socket
sudo service docker stop

# Only on the first run: moving again would nest the data-root inside itself.
if [ -d /var/lib/docker ] && [ ! -d "$DOCKER_ROOT" ]; then
  sudo mv /var/lib/docker "$DOCKER_ROOT"
fi

sudo tee /etc/docker/daemon.json > /dev/null << EOF
{
  "data-root": "$DOCKER_ROOT"
}
EOF

log 'Setting docker permissions...'

# The data-root stays root-owned; access to docker comes from the socket,
# which is root:docker. Group membership is what removes the need for sudo.
sudo usermod -aG docker $USER
