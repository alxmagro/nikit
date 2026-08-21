#!/bin/bash

set -e # flag exit if error

DOCKER_ROOT="$HOME/.local/share/docker"

echo -e '\e[0;33mInstalling docker...\e[0m'

curl https://get.docker.com/ | bash -

echo -e '\e[0;33mSetting docker daemon...\e[0m'

sudo systemctl stop docker.socket
sudo service docker stop

sudo mv /var/lib/docker $DOCKER_ROOT

sudo tee /etc/docker/daemon.json > /dev/null << EOF
{
  "data-root": "$DOCKER_ROOT"
}
EOF

echo -e '\e[0;33mSetting docker permissions...\e[0m'

sudo chown -R $USER:$USER $DOCKER_ROOT
sudo usermod -aG docker $USER

echo -e '\e[0;33mAdding docker aliases...\e[0m'

tee -a $HOME/.bash_aliases > /dev/null << EOF
alias dcu="sudo docker compose up"
alias dcd="sudo docker compose down"
alias dce="sudo docker compose exec"
alias dcr="sudo docker compose run"
EOF

echo "Done!"

set +e
