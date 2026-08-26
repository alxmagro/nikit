#!/bin/bash
#
# open - Open files and URLs in the desktop's default application.
#
# Usage:
#   open <file|url>       Detached and quiet, the terminal stays free
#   open -i <file|url>    Inline: the native open, output and all
#
# Shadows /usr/bin/open, which is a symlink to xdg-open. The default here
# backgrounds it and drops its output, since most of what it prints is
# noise from the application being launched.

open() {
  if [ "${1:-}" = "-i" ]; then
    shift
    command open "$@"
    return
  fi

  (command open "$@" > /dev/null 2>&1 &)
}
