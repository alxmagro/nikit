#!/bin/bash
#
# goto - Jump to named target folders
#
# Usage:
#   goto <key>[/<subpath>] [-r]  Jump there; -r also reveals it in the file manager
#   goto                         List the configured roots
#   goto --set <key> <path>      Create or update a root
#   goto --rm <key>              Remove a root
#   goto --config mode [-P|-L]   Get or set the cd mode (physical / logical)
#   goto --help                  Show this help message
#
# Configuration lives in config/goto.conf, next to the other nikit files.
# One "namespace.key = value" per line; '#' starts a comment:
#
#   config.mode = -P
#   paths.code  = /home/me/Documents/code
#   paths.dots  = /home/me/.dotfiles
#
# GOTO_MODE in the environment still wins over config.mode.

_goto_conf() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/nikit/config/goto.conf"
}

# _goto_get <namespace.key> - print the raw value, or return 1 if absent.
_goto_get() {
  local want="$1" conf k v
  conf=$(_goto_conf)
  [ -f "$conf" ] || return 1

  while IFS='=' read -r k v || [ -n "$k" ]; do
    k="${k#"${k%%[![:space:]]*}"}"
    k="${k%"${k##*[![:space:]]}"}"
    [ "$k" = "$want" ] || continue

    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    printf '%s\n' "$v"
    return 0
  done < "$conf"

  return 1
}

# _goto_lookup <key> - path for a navigation key (paths.<key>), or return 1.
_goto_lookup() {
  _goto_get "paths.$1"
}

# _goto_pairs - print "key<TAB>value" for every paths.* entry.
_goto_pairs() {
  local conf k v
  conf=$(_goto_conf)
  [ -f "$conf" ] || return 0

  while IFS='=' read -r k v || [ -n "$k" ]; do
    k="${k#"${k%%[![:space:]]*}"}"
    k="${k%"${k##*[![:space:]]}"}"

    case "$k" in
      paths.?*) ;;
      *) continue ;;
    esac

    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    printf '%s\t%s\n' "${k#paths.}" "$v"
  done < "$conf"
}

# _goto_put <namespace.key> <value> - atomically upsert one line, keeping the
# rest of the file (comments and spacing included) untouched.
_goto_put() {
  local key="$1" value="$2" conf tmp k rest kk
  conf=$(_goto_conf)
  mkdir -p "$(dirname "$conf")"
  tmp="$conf.tmp.$$"

  {
    if [ -f "$conf" ]; then
      while IFS='=' read -r k rest || [ -n "$k" ]; do
        kk="${k#"${k%%[![:space:]]*}"}"
        kk="${kk%"${kk##*[![:space:]]}"}"
        [ "$kk" = "$key" ] && continue

        if [ -n "$rest" ]; then
          printf '%s=%s\n' "$k" "$rest"
        else
          printf '%s\n' "$k"
        fi
      done < "$conf"
    fi
    printf '%s = %s\n' "$key" "$value"
  } > "$tmp" && mv "$tmp" "$conf"
}

_goto_set() {
  local key="$1" path="$2"

  case "$key" in
    "") echo "goto: empty key" >&2; return 1 ;;
    -*) echo "goto: key cannot start with '-'" >&2; return 1 ;;
    *[/=]* | *[[:space:]]*)
      echo "goto: key cannot contain '/', '=' or spaces" >&2
      return 1
      ;;
  esac

  case "$path" in
    "~") path="$HOME" ;;
    "~/"*) path="$HOME/${path#\~/}" ;;
    /*) ;;
    *) path="$PWD/$path" ;;
  esac
  path="${path%/}"

  _goto_put "paths.$key" "$path" && echo "Set $key -> $path"
}

_goto_rm() {
  local key="$1" conf tmp k rest kk

  _goto_lookup "$key" > /dev/null || {
    echo "goto: no such root: $key" >&2
    return 1
  }

  conf=$(_goto_conf)
  tmp="$conf.tmp.$$"

  while IFS='=' read -r k rest || [ -n "$k" ]; do
    kk="${k#"${k%%[![:space:]]*}"}"
    kk="${kk%"${kk##*[![:space:]]}"}"
    [ "$kk" = "paths.$key" ] && continue

    if [ -n "$rest" ]; then
      printf '%s=%s\n' "$k" "$rest"
    else
      printf '%s\n' "$k"
    fi
  done < "$conf" > "$tmp" && mv "$tmp" "$conf"

  echo "Removed $key"
}

_goto_mode() {
  local m
  m="${GOTO_MODE:-$(_goto_get config.mode)}"
  printf '%s' "${m:--P}"
}

goto() {
  local key rest root target listed reveal

  case "${1:-}" in
    --help)
      echo "goto - Jump to named target folders"
      echo
      echo "Usage:"
      echo "  goto <key>[/<subpath>] [-r]  Jump there; -r also reveals it in the file manager"
      echo "  goto                         List the configured roots"
      echo "  goto --set <key> <path>      Create or update a root"
      echo "  goto --rm <key>              Remove a root"
      echo "  goto --config mode [-P|-L]   Get or set the cd mode (physical / logical)"
      echo "  goto --help                  Show this help message"
      echo
      echo "Config: $(_goto_conf)"
      return 0
      ;;
    --set)
      if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
        echo "Usage: goto --set <key> <path>" >&2
        return 1
      fi
      _goto_set "$2" "$3"
      return
      ;;
    --rm)
      if [ -z "${2:-}" ]; then
        echo "Usage: goto --rm <key>" >&2
        return 1
      fi
      _goto_rm "$2"
      return
      ;;
    --config)
      case "${2:-}" in
        mode)
          if [ -n "${3:-}" ]; then
            case "$3" in
              -P | -L) ;;
              *) echo "goto: mode must be -P or -L" >&2; return 1 ;;
            esac
            _goto_put config.mode "$3" && echo "Set mode = $3"
          else
            _goto_mode
            echo
          fi
          ;;
        *)
          echo "goto: unknown config key '${2:-}' (mode)" >&2
          return 1
          ;;
      esac
      return
      ;;
  esac

  if [ -z "${1:-}" ]; then
    listed=""
    while IFS=$'\t' read -r key rest; do
      listed=1
      printf '%s -> %s\n' "$key" "$rest"
    done < <(_goto_pairs)
    [ -n "$listed" ] || echo "No roots configured. Use: goto --set <key> <path>"
    return 0
  fi

  reveal=""
  case "${2:-}" in
    "") ;;
    -r | --reveal) reveal=1 ;;
    *) echo "goto: unknown option '$2'" >&2; return 1 ;;
  esac

  key="${1%%/*}"
  case "$1" in
    */*) rest="${1#*/}" ;;
    *) rest="" ;;
  esac

  root=$(_goto_lookup "$key") || {
    echo "goto: unknown key '$key'" >&2
    return 1
  }

  target="$root${rest:+/$rest}"

  if [ ! -d "$target" ]; then
    echo "goto: not a directory: $target" >&2
    return 1
  fi

  cd "$(_goto_mode)" "$target" || return 1
  [ -z "$reveal" ] || xdg-open .
}

_goto_complete() {
  local first cur
  COMPREPLY=()
  first="${COMP_WORDS[1]}"
  cur="${COMP_WORDS[COMP_CWORD]}"

  # goto --set <TAB> / goto --rm <TAB>  ->  existing keys
  if { [ "$first" = "--set" ] || [ "$first" = "--rm" ]; } && [ "$COMP_CWORD" -eq 2 ]; then
    local IFS=$'\n'
    COMPREPLY=($(compgen -W "$(_goto_pairs | cut -f1)" -- "$cur"))
    return 0
  fi

  # goto --set <key> <TAB>  ->  directories for the target path.
  # -o filenames lets readline add the trailing slash and skip the space.
  if [ "$first" = "--set" ] && [ "$COMP_CWORD" -eq 3 ]; then
    local entry
    while IFS= read -r entry; do
      COMPREPLY+=("$entry")
    done < <(compgen -d -- "$cur")
    compopt -o filenames 2> /dev/null || true
    return 0
  fi

  # any other flag: no completion
  [[ "$first" == --* ]] && return 0
  [ "$COMP_CWORD" -eq 1 ] || return 0

  if [[ "$cur" == */* ]]; then
    # Drill down inside the key's root. Mark the candidates as filenames so
    # readline lists only the trailing segment, not the "<key>/..." we typed.
    local key="${cur%%/*}" sub="${cur#*/}" root entry
    root=$(_goto_lookup "$key") || return 0
    root="${root%/}"

    while IFS= read -r entry; do
      COMPREPLY+=("$key/${entry:${#root}+1}/")
    done < <(compgen -d -- "$root/$sub")

    compopt -o nospace -o filenames 2> /dev/null || true
    return 0
  fi

  # First word: the configured keys, as "key/" candidates
  local IFS=$'\n'
  COMPREPLY=($(compgen -W "$(_goto_pairs | cut -f1 | sed 's:$:/:')" -- "$cur"))
  compopt -o nospace 2> /dev/null || true
}

complete -F _goto_complete goto
