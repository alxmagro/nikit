#!/bin/bash
#
# Helpers shared by every install script.
#
# Sourced once by install.sh, which exports SH_ROOT and SH_INSTALL before
# running anything. Scripts never source this themselves.

### Paths

# Everything the install writes into the user's home lives here.
PROJECT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/nikit"
export PROJECT_ROOT

SH_LOG_DIR="${TMPDIR:-/tmp}/sh-install"

### Output

# Progress line from inside a module, indented under its heading. Goes to
# stderr so it survives run() capturing the module's stdout.
log() {
  echo -e "\e[0;90m    $*\e[0m" >&2
}

success() {
  echo -e "\e[0;32m$*\e[0m" >&2
}

abort() {
  echo -e "\e[0;31m$*\e[0m" >&2
  exit 1
}

### Running

# Run one module. Its stdout goes to a log file so apt and friends stay
# quiet; stderr stays on the terminal so errors and prompts still show.
# The log is printed when the module fails.
run() {
  local path="$SH_ROOT/$1"
  local name log

  [ -f "$path" ] || abort "No such script: $1"

  name=$(basename "$1" .sh)
  log="$SH_LOG_DIR/$name.log"

  mkdir -p "$SH_LOG_DIR"
  echo -e "\e[0;34m- $name\e[0m"

  if ! bash "$path" > "$log"; then
    echo >&2
    echo -e "\e[0;31m$name failed, output follows:\e[0m" >&2
    echo >&2
    cat "$log" >&2
    exit 1
  fi
}

### Packages

# Read a package list, skipping comments and blank lines. Takes a path
# relative to the repo root, without the extension:
#
#   packages install/debian_13/base
packages() {
  local file="$SH_ROOT/$1.packages"

  [ -f "$file" ] || abort "No such package list: $1.packages"

  grep -vE '^[[:space:]]*(#|$)' "$file"
}

### Files

# Create a directory if it is missing.
ensure_folder() {
  mkdir -p "$@"
}

# Append a line to a file, but only once.
append_once() {
  local file="$1" line="$2"

  [ -f "$file" ] || touch "$file"

  if ! grep -qxF "$line" "$file"; then
    echo "$line" >> "$file"
  fi
}

apt_update() {
  sudo apt-get update
}

apt_install() {
  sudo apt-get install -y "$@"
}

### Exports
#
# Scripts run in a child bash, which does not inherit shell functions
# unless they are exported.

export -f log success abort packages ensure_folder append_once apt_update apt_install
