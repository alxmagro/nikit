#!/bin/bash

set -e

# psql exists as a wrapper even with no server installed, so check the
# package instead.
if dpkg -s postgresql > /dev/null 2>&1; then
  log 'already installed, skipping'
  exit 0
fi

log 'Installing postgresql...'

apt_install postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

apt_update
apt_install postgresql
