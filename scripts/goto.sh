#!/bin/bash
#
# goto - Jump to named target folders
#
# Usage:
#   goto <name>                  Jump to a folder inside the target directory
#   goto --add <name> <target>   Create a symlink inside the target directory
#   goto --config <key>          Read a config value
#   goto --config <key> <value>  Set a config value
#   goto --help                  Show this help message
#
# Configuration lives in config/goto.conf, next to the other nikit files:
#
#   path   Base target directory, ~/Documents by default
#   mode   '-P' or '-L', physical by default
#
# The file is plain shell assignments. An environment variable still wins,
# so GOTO_PATH=/tmp goto x works without touching the file.

_goto_conf() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/nikit/config/goto.conf"
}

_goto_var() {
  case "$1" in
    path) echo "GOTO_PATH" ;;
    mode) echo "GOTO_MODE" ;;
    *) return 1 ;;
  esac
}

# Sets goto_path and goto_mode, which the caller declares local.
#
# The file is read in a subshell so it never leaks into the environment:
# otherwise the first call would pin the values for the whole session, and
# a later `goto --config` would have no effect until the next login.
_goto_load() {
  local conf values

  conf=$(_goto_conf)

  if [ -f "$conf" ]; then
    values=$(. "$conf" > /dev/null 2>&1; printf '%s\n%s\n' "${GOTO_PATH:-}" "${GOTO_MODE:-}")
  fi

  goto_path="${GOTO_PATH:-$(printf '%s' "$values" | sed -n 1p)}"
  goto_mode="${GOTO_MODE:-$(printf '%s' "$values" | sed -n 2p)}"

  goto_path="${goto_path:-$HOME/Documents}"
  goto_mode="${goto_mode:--P}"
}

_goto_set() {
  local key="$1" value="$2" var conf line

  var=$(_goto_var "$key") || {
    echo "Unknown key: $key (path, mode)" >&2
    return 1
  }

  conf=$(_goto_conf)
  mkdir -p "$(dirname "$conf")"

  line="$var=\"$value\""

  {
    grep -v "^$var=" "$conf" 2> /dev/null
    printf '%s\n' "$line"
  } > "$conf.tmp" && mv "$conf.tmp" "$conf"

  echo "Set $key = $value"
}

goto() {
  local target goto_path goto_mode

  if [ "$1" = "--help" ]; then
    echo "goto - Jump to named target folders"
    echo
    echo "Usage:"
    echo "  goto <name>                  Jump to a folder inside the target directory"
    echo "  goto --add <name> <target>   Create a symlink inside the target directory"
    echo "  goto --config <key>          Read a config value"
    echo "  goto --config <key> <value>  Set a config value"
    echo "  goto --help                  Show this help message"
    echo
    echo "Config keys:"
    echo "  path   Base target directory, ~/Documents by default"
    echo "  mode   '-P' or '-L', physical by default"
    echo
    echo "Stored in $(_goto_conf)"
    return 0
  fi

  if [ "$1" = "--config" ]; then
    if [ -z "${2:-}" ]; then
      echo "Usage: goto --config <key> [value]"
      return 1
    fi

    if [ -n "${3:-}" ]; then
      _goto_set "$2" "$3"
      return
    fi

    local var
    var=$(_goto_var "$2") || {
      echo "Unknown key: $2 (path, mode)" >&2
      return 1
    }

    local goto_path goto_mode
    _goto_load

    case "$2" in
      path) echo "$goto_path" ;;
      mode) echo "$goto_mode" ;;
    esac

    return 0
  fi

  _goto_load

  if [ "$1" = "--add" ]; then
    if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
      echo "Usage: goto --add [name] [target]"
      return 1
    fi

    mkdir -p "$goto_path"
    ln -sfn "$3" "$goto_path/$2"

    echo "Created symlink:"
    echo "  $2 -> $3"
    return 0
  fi

  if [ -z "$1" ]; then
    echo "Usage: goto <NAME>"
    echo "Target directory: $goto_path"
    return 1
  fi

  target="$goto_path/$1"

  if [ ! -d "$target" ]; then
    echo "Target not found: $target"
    return 1
  fi

  cd "$goto_mode" "$target" || return 1
}

_goto_complete() {
  local arg cur

  arg="${COMP_WORDS[1]}"
  cur="${COMP_WORDS[COMP_CWORD]}"

  # Directory completion for the target of --add
  if [ "$arg" = "--add" ] && [ "$COMP_CWORD" -eq 3 ]; then
    local -a matches=()
    local entry

    while IFS= read -r entry; do
      matches+=("$entry/")
    done < <(compgen -d -- "$cur")

    COMPREPLY=("${matches[@]}")
    compopt -o nospace 2> /dev/null || true
    return 0
  fi

  if [ "$arg" = "--config" ] && [ "$COMP_CWORD" -eq 2 ]; then
    COMPREPLY=($(compgen -W "path mode" -- "$cur"))
    return 0
  fi

  if [[ "$arg" != --* ]] && [ "$COMP_CWORD" -eq 1 ]; then
    local goto_path goto_mode
    _goto_load
    [ -d "$goto_path" ] || return 0

    # Split candidates on newline only, so names with spaces survive
    local IFS=$'\n'
    COMPREPLY=($(compgen -W "$(ls -1A "$goto_path" 2> /dev/null)" -- "$cur"))
    return 0
  fi
}

complete -F _goto_complete goto
