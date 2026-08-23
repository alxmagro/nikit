#!/bin/bash
#
# gistpad - Keep named notes as secret gists.
#
# Usage:
#   gistpad [-e <editor>]   Pick a note from the list and open it
#   gistpad sync            Rebuild the list from the gists on GitHub
#
# In the picker: enter opens, f2 renames, ctrl-d deletes, and the first entry
# starts a new note. The note name doubles as the file name, so ending it in
# an extension is what decides how GitHub and the editor highlight it.

_gistpad_prefix="gistpad: "

_gistpad_index() {
  echo "${XDG_CACHE_HOME:-$HOME/.cache}/nikit/gistpad.tsv"
}

_gistpad_id() {
  local index
  index=$(_gistpad_index)

  [ -f "$index" ] || return 1

  awk -F'\t' -v key="$1" '$1 == key { print $2; found = 1 } END { exit !found }' "$index"
}

_gistpad_keys() {
  local index
  index=$(_gistpad_index)

  [ -f "$index" ] && cut -f1 "$index"
}

_gistpad_set() {
  local key="$1" id="$2" index
  index=$(_gistpad_index)

  mkdir -p "$(dirname "$index")"

  {
    [ -f "$index" ] && awk -F'\t' -v key="$key" '$1 != key' "$index"
    printf '%s\t%s\n' "$key" "$id"
  } > "$index.tmp" && mv "$index.tmp" "$index"
}

_gistpad_unset() {
  local key="$1" index
  index=$(_gistpad_index)

  [ -f "$index" ] || return 0

  awk -F'\t' -v key="$key" '$1 != key' "$index" > "$index.tmp" && mv "$index.tmp" "$index"
}

_gistpad_sync() {
  local index
  index=$(_gistpad_index)

  mkdir -p "$(dirname "$index")"

  gh gist list --limit 100 |
    awk -F'\t' -v p="$_gistpad_prefix" \
      'index($2, p) == 1 { print substr($2, length(p) + 1) "\t" $1 }' \
      > "$index.tmp" || return 1

  mv "$index.tmp" "$index"
  echo "Synced $(wc -l < "$index") notes." >&2
}

_gistpad_default_editor="nano"

_gistpad_new_label="New gist..."

_gistpad_scratch() {
  echo "${XDG_CACHE_HOME:-$HOME/.cache}/nikit"
}

_gistpad_pick() {
  local keys

  keys=$(_gistpad_keys)

  if ! command -v fzf > /dev/null; then
    echo "Pick a note by name:" >&2
    echo "$keys" >&2
    return 1
  fi

  printf '%s\n' "$_gistpad_new_label${keys:+$'\n'$keys}" | fzf \
    --height 40% \
    --layout reverse \
    --info hidden \
    --no-separator \
    --prompt '$ ' \
    --header 'enter open · f2 rename · ctrl-d delete · ctrl-c exit' \
    --header-first \
    --pointer '›' \
    --color 'fg+:-1:regular,bg+:-1,prompt:15:regular,query:-1:regular,pointer:4,hl:4,hl+:4,header:8' \
    --expect ctrl-d,f2
}

# The note name doubles as the file name, so the extension is whatever you
# typed. Without one, markdown, which is what a note usually is.
_gistpad_filename() {
  case "$1" in
    *.*) echo "gistpad-$1" ;;
    *) echo "gistpad-$1.md" ;;
  esac
}

_gistpad_ask() {
  local prompt="$1" answer

  read -rp "$prompt" answer < /dev/tty
  printf '%s' "$answer" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

_gistpad_unique_key() {
  local key="$1" candidate="$1" n=1

  while [ -n "$(_gistpad_id "$candidate")" ]; do
    n=$((n + 1))
    candidate="$key - $n"
  done

  echo "$candidate"
}

_gistpad_remove() {
  local key="$1" id="$2" prompt="${3:-}" reply

  if [ -n "$prompt" ]; then
    read -rp "$prompt (y/N) " reply < /dev/tty

    case "$reply" in
      [yY] | [yY][eE][sS]) ;;
      *) return 1 ;;
    esac
  fi

  _gist_delete "$id" || return 1

  _gistpad_unset "$key"
  echo "Removed note '$key'"
}

# Renaming touches three things: the file, the description GitHub shows, and
# the local index.
_gistpad_rename() {
  local key="$1" id="$2" filename="$3" newkey

  newkey=$(_gistpad_ask "Rename '$key' to: ")

  [ -n "$newkey" ] || return 1
  [ "$newkey" != "$key" ] || return 0

  newkey=$(_gistpad_unique_key "$newkey")

  _gist_rename "$id" "$filename" "$(_gistpad_filename "$newkey")" || return 1
  _gist_describe "$id" "$_gistpad_prefix$newkey" || return 1

  _gistpad_unset "$key"
  _gistpad_set "$newkey" "$id"

  echo "Renamed note '$key' to '$newkey'"
}

gistpad() {
  local action key id tmp dir url newkey body filename picked pressed before after
  local editor="$_gistpad_default_editor" args=()

  _gist_ready || return 1

  while [ $# -gt 0 ]; do
    case "$1" in
      -e | --editor)
        if [ -z "${2:-}" ]; then
          echo "-e needs an editor, like 'gistpad -e nvim'" >&2
          return 1
        fi

        editor="$2"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  if [ "${args[0]:-}" = "sync" ] && [ ${#args[@]} -eq 1 ]; then
    _gistpad_sync
    return
  fi

  if [ ${#args[@]} -gt 0 ]; then
    echo "Usage: gistpad [-e <editor>] | gistpad sync" >&2
    return 1
  fi

  picked=$(_gistpad_pick) || return 1

  pressed=$(printf '%s' "$picked" | sed -n 1p)
  key=$(printf '%s' "$picked" | sed -n 2p)

  case "$pressed" in
    ctrl-d) action="rm" ;;
    f2) action="mv" ;;
  esac

  # The first entry is a label, not a note: rename and delete have nothing to
  # act on there, so they do nothing at all.
  [ "$key" = "$_gistpad_new_label" ] && key=""

  [ -n "$key" ] || [ -z "$action" ] || return 0

  id=""
  [ -n "$key" ] && id=$(_gistpad_id "$key")

  if [ -n "$action" ]; then
    if [ -z "$id" ]; then
      echo "No note named '$key'" >&2
      return 1
    fi

    if [ "$action" = "rm" ]; then
      _gistpad_remove "$key" "$id" "Delete note '$key'?"
      return
    fi

    _gistpad_rename "$key" "$id" "$(_gist_read -n "$id" | head -1)"
    return
  fi

  mkdir -p "$(_gistpad_scratch)"

  # The scratch file carries the gist's own name, so the editor highlights
  # it the same way GitHub does.
  if [ -n "$id" ]; then
    dir=$(mktemp -d -p "$(_gistpad_scratch)")

    if ! _gist_read -n "$id" > "$dir/raw"; then
      echo "Could not read note '$key'" >&2
      rm -rf "$dir"
      return 1
    fi

    filename=$(head -1 "$dir/raw")
    tmp="$dir/$filename"
    tail -n +2 "$dir/raw" > "$tmp"

    before=$(cat "$tmp")
    $editor "$tmp"
    after=$(cat "$tmp")

    if [ "$before" = "$after" ]; then
      :
    elif [ -z "${after//[[:space:]]/}" ]; then
      _gistpad_remove "$key" "$id"
    elif _gist_write "$id" "$filename" "$after"; then
      echo "Saved note '$key'"
    fi

    rm -rf "$dir"
    return
  fi

  # A new note has no name yet, so it is named after the editor closes.
  dir=$(mktemp -d -p "$(_gistpad_scratch)")
  tmp="$dir/note"
  : > "$tmp"

  $editor "$tmp"

  body=$(cat "$tmp")
  rm -rf "$dir"

  if [ -z "${body//[[:space:]]/}" ]; then
    echo "Nothing written, note not created." >&2
    return 1
  fi

  newkey=$(_gistpad_ask "Name: ")

  if [ -z "$newkey" ]; then
    echo "Nothing named, note not created." >&2
    return 1
  fi

  key=$(_gistpad_unique_key "$newkey")

  if [ "$key" != "$newkey" ]; then
    echo "A note named '$newkey' already exists, using '$key'." >&2
  fi

  url=$(_gist_create "$_gistpad_prefix$key" "$(_gistpad_filename "$key")" "$body") || return 1

  _gistpad_set "$key" "${url##*/}"

  echo "Created at $url"
}
