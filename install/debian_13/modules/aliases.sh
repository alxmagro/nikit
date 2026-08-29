#!/bin/bash

set -e

log 'Adding shell aliases...'

## Debian's default .bashrc already sources ~/.bash_aliases, so there is
## nothing to wire up here.
cat > "$HOME/.bash_aliases" << 'EOF'
# --- Docker

alias dcu="sudo docker compose up"
alias dcd="sudo docker compose down"
alias dce="sudo docker compose exec"
alias dcr="sudo docker compose run"

dprune-all() {
  docker rm -f $(docker ps -qa) # Remove every container
  docker system prune -af # Remove every unused container, image and network
  docker volume rm -f $(docker volume ls -q) # Remove every volume
}

# --- Files

alias ..='cd ..'

# --- Terminal

alias tt='kgx --tab --working-directory=$PWD'

# --- Notes

alias gpad='gistpad'
EOF
