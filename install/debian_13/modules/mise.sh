#!/bin/bash

set -e

if command -v mise > /dev/null; then
  log 'already installed, skipping'
  exit 0
fi

log 'Installing mise...'

apt_install extrepo
sudo extrepo enable mise
apt_update
apt_install mise
