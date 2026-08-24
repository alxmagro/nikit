#!/bin/bash
#
# nikit - Entry point for the grouped commands.

_nikit_usage() {
  echo "Usage: nikit <command> [args]"
  echo
  echo "Commands:"
  echo "  gnome-extensions   Sync, edit and restore your GNOME Shell extensions"
}

nikit() {
  local group="${1:-}"

  case "$group" in
    gnome-extensions)
      shift
      _nikit_gnome_extensions "$@"
      ;;
    -h | --help | help | '')
      _nikit_usage
      ;;
    *)
      echo "nikit: no such command '$group'" >&2
      echo >&2
      _nikit_usage >&2
      return 1
      ;;
  esac
}
