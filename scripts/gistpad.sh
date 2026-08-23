#!/bin/bash
#
# gistpad - Keep named notes as secret gists.
#
# Usage:
#   gistpad [-e <editor>]   Pick a note from the list and open it
#   gistpad sync            Rebuild the list from the gists on GitHub
#
# Opening a note edits it: gh only uploads when the content actually
# changed, so reading and editing are the same command.
#
# In the picker: enter opens, ctrl-d deletes, and the first entry starts a
# new note.

# The index maps a note name to a gist id, one "name<TAB>id" per line. It is
# a cache, not the truth: ctrl-r in the picker rebuilds it from GitHub, where
# the name lives in the gist description.
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

# Rebuilds the index from the gist descriptions, which all start with
# "gistpad: ". Anything else in the account is left alone.
_gistpad_sync() {
  local index
  index=$(_gistpad_index)

  mkdir -p "$(dirname "$index")"

  gh gist list --limit 100 |
    awk -F'\t' '$2 ~ /^gistpad: / { print substr($2, 10) "\t" $1 }' \
      > "$index.tmp" || return 1

  mv "$index.tmp" "$index"
  echo "Synced $(wc -l < "$index") notes." >&2
}

# A terminal editor by default: a windowed one takes the focus away, and
# some of them hand the file over and exit before you have typed anything.
_gistpad_default_editor="nano"

_gistpad_new_label="New gist..."

# /tmp is tmpfs here, where the editor cannot store its cursor metadata and
# warns about it. Keep scratch files on the home filesystem instead.
_gistpad_scratch() {
  echo "${XDG_CACHE_HOME:-$HOME/.cache}/nikit"
}

# Ask which note to act on, and how.
#
# Prints two lines: the key that was pressed, empty for Enter, and what was
# picked. That is what --expect buys over a plain picker: the list carries
# the verbs, so there is no second menu.
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
    --header 'enter open · ctrl-d delete · ctrl-c exit' \
    --header-first \
    --pointer '›' \
    --color 'fg+:-1:regular,bg+:-1,prompt:15:regular,query:-1:regular,pointer:4,hl:4,hl+:4,header:8' \
    --expect ctrl-d
}

# The gist's first file as "<filename>\n<content>", in one request. Not
# `gh gist view --raw`, which glues the description on top of the content.
_gistpad_fetch() {
  gh api "gists/$1" --jq '.files | to_entries | .[0] | .key, .value.content'
}

# Sends new content through the API. `gh gist edit` in older versions only
# knows how to open an editor, so it cannot upload text we already have.
# Takes the current filename, which the caller already had to read.
_gistpad_upload() {
  local id="$1" filename="$2" key="$3" content="$4"

  # Renaming the file and the description too, so a note renamed in the
  # header stays consistent on GitHub.
  jq -n \
    --arg name "$filename" \
    --arg newname "gistpad-$key.md" \
    --arg desc "gistpad: $key" \
    --arg content "$content" \
    '{description: $desc, files: {($name): {filename: $newname, content: $content}}}' |
    gh api -X PATCH "gists/$id" --input - > /dev/null
}

# Names are the key of the map, so they have to be unique. A taken name
# gets a counter: "Untitled", "Untitled - 2", "Untitled - 3".
_gistpad_unique_key() {
  local key="$1" candidate="$1" n=1

  while [ -n "$(_gistpad_id "$candidate")" ]; do
    n=$((n + 1))
    candidate="$key - $n"
  done

  echo "$candidate"
}

# Confirms only when given a prompt.
_gistpad_delete() {
  local key="$1" id="$2" prompt="${3:-}" reply

  if [ -n "$prompt" ]; then
    read -rp "$prompt (y/N) " reply < /dev/tty

    case "$reply" in
      [yY] | [yY][eE][sS]) ;;
      *) return 1 ;;
    esac
  fi

  # --yes arrived in a later gh; older ones delete without asking anyway.
  if gh gist delete --help 2>&1 | grep -q -- '--yes'; then
    gh gist delete "$id" --yes || return 1
  else
    gh gist delete "$id" || return 1
  fi

  _gistpad_unset "$key"
  echo "Removed note '$key'"
}

gistpad() {
  local action key id tmp url before after newkey body filename picked pressed
  local editor="$_gistpad_default_editor" args=()

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

  # the pressed key, empty for Enter, then the selection
  pressed=$(printf '%s' "$picked" | sed -n 1p)
  key=$(printf '%s' "$picked" | sed -n 2p)

  [ "$pressed" = "ctrl-d" ] && action="rm"

  # The first entry is a label, not a note: a new one is named on the
  # header line, in the editor.
  [ "$key" = "$_gistpad_new_label" ] && key=""

  [ -n "$key" ] || [ "$action" != "rm" ] || return 1

  id=""
  [ -n "$key" ] && id=$(_gistpad_id "$key")

  if [ "$action" = "rm" ]; then
    if [ -z "$id" ]; then
      echo "No note named '$key'" >&2
      return 1
    fi

    _gistpad_delete "$key" "$id" "Delete note '$key'?"
    return
  fi

  mkdir -p "$(_gistpad_scratch)"

  # Editing is done here rather than by `gh gist edit`, which uploads on its
  # own: emptying a note has to become a delete, and a gist cannot be empty.
  if [ -n "$id" ]; then
    tmp=$(mktemp -d -p "$(_gistpad_scratch)")/"gistpad-$key.md"

    if ! _gistpad_fetch "$id" > "$tmp.raw"; then
      echo "Could not read note '$key'" >&2
      rm -rf "$(dirname "$tmp")"
      return 1
    fi

    filename=$(head -1 "$tmp.raw")

    # The first line carries the name, so renaming happens in the editor.
    { printf '# %s\n\n' "$key"; tail -n +2 "$tmp.raw"; } > "$tmp"

    before=$(cat "$tmp")
    $editor "$tmp"
    after=$(cat "$tmp")

    newkey=$(sed -n '1s/^#[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' "$tmp")

    if [ -n "$newkey" ]; then
      body=$(tail -n +2 "$tmp" | sed '/[^[:space:]]/,$!d')
    else
      newkey="$key"
      body="$after"
    fi

    if [ "$newkey" != "$key" ]; then
      newkey=$(_gistpad_unique_key "$newkey")
    fi

    if [ "$before" = "$after" ]; then
      echo "No changes."
    elif [ -z "${body//[[:space:]]/}" ]; then
      _gistpad_delete "$key" "$id"
    elif _gistpad_upload "$id" "$filename" "$newkey" "$body"; then
      if [ "$newkey" != "$key" ]; then
        _gistpad_unset "$key"
        _gistpad_set "$newkey" "$id"
        echo "Renamed note '$key' to '$newkey'"
      else
        echo "Saved note '$key'"
      fi
    fi

    rm -rf "$(dirname "$tmp")"
    return
  fi

  # A new note needs content before it can become a gist: gh refuses to
  # create one from an empty file.
  tmp=$(mktemp -d -p "$(_gistpad_scratch)")/"note.md"
  printf '# Untitled\n\n' > "$tmp"

  $editor "$tmp"

  newkey=$(sed -n '1s/^#[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' "$tmp")

  if [ -z "$newkey" ]; then
    echo "The first line must name the note, like '# groceries'." >&2
    rm -rf "$(dirname "$tmp")"
    return 1
  fi

  key=$(_gistpad_unique_key "$newkey")

  if [ "$key" != "$newkey" ]; then
    echo "A note named '$newkey' already exists, using '$key'." >&2
  fi

  # The header is ours, so only what comes after it becomes the note.
  body=$(tail -n +2 "$tmp" | sed '/[^[:space:]]/,$!d')

  if [ -z "${body//[[:space:]]/}" ]; then
    echo "Nothing written, note not created." >&2
    rm -rf "$(dirname "$tmp")"
    return 1
  fi

  # gh names the gist file after the path it is given.
  printf '%s\n' "$body" > "$(dirname "$tmp")/gistpad-$key.md"
  tmp="$(dirname "$tmp")/gistpad-$key.md"

  url=$(gh gist create "$tmp" -d "gistpad: $key") || {
    rm -rf "$(dirname "$tmp")"
    return 1
  }

  _gistpad_set "$key" "${url##*/}"
  rm -rf "$(dirname "$tmp")"

  echo "$url"
}
