#!/bin/bash
#
# nikit - A shortcut for the commands named _nikit-*.
#
#   nikit app-folders sync   ==   _nikit-app-folders sync
#
# The real command is the prefixed one, and the prefix is not decoration: a
# bare `gnome-extensions` is already a program on any GNOME system, and ours
# would lose to it in PATH. Prefixing is what keeps the name ours; this only
# saves the typing.

_nikit_usage() {
  echo "Usage: nikit <command> [args]"
  echo
  echo "Commands:"
  echo "  app-folders        Sync, edit and restore your App Grid folders"
  echo "  gnome-extensions   Sync, edit and restore your GNOME Shell extensions"
}

nikit() {
  local command="${1:-}"

  case "$command" in
    app-folders | gnome-extensions)
      shift
      "_nikit-$command" "$@"
      ;;
    -h | --help | help | '')
      _nikit_usage
      ;;
    *)
      echo "nikit: no such command '$command'" >&2
      echo >&2
      _nikit_usage >&2
      return 1
      ;;
  esac
}

# Completing the command name only. What each one takes after that is its own
# business, and none of them would gain much from being spelled out here.
#
# The names are read back out of the usage text rather than listed again, so a
# command added there is completed without touching anything else.
_nikit_complete() {
  [ "$COMP_CWORD" -eq 1 ] || return 0

  mapfile -t COMPREPLY < <(
    compgen -W "$(_nikit_usage | awk '/^  [a-z]/ { print $1 }')" \
      -- "${COMP_WORDS[COMP_CWORD]}"
  )
}

complete -F _nikit_complete nikit
