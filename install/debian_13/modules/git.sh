#!/bin/bash

set -e

# Read from the terminal, not stdin: under `wget | bash` stdin is the
# exhausted pipe, and an EOF here would abort the whole install.
read -p "    Enter your git name: " GIT_NAME < /dev/tty
read -p "    Enter your git email: " GIT_EMAIL < /dev/tty

log 'Setting git globals...'

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main

log 'Run `gh auth login` to authenticate with GitHub.'
