# The clipboard, carried between machines through a gist. Wayland only.

_nikit_clip_description="nikit: clip"
_nikit_clip_file="clip.txt"

_nikit_clip_gist() {
  _gist_find "$_nikit_clip_description"
}

_nikit_clip_store() {
  local id url body

  # wl-paste fails outright when what was copied is not text, a file from the
  # file manager being the usual case. That is not the same as empty.
  if ! body=$(wl-paste --no-newline 2>/dev/null); then
    echo "The clipboard holds no text." >&2
    echo "Check what is in it with: wl-paste --list-types" >&2
    return 1
  fi

  if [ -z "$body" ]; then
    echo "The clipboard is empty." >&2
    return 1
  fi

  id=$(_nikit_clip_gist)

  if [ -z "$id" ]; then
    url=$(_gist_create "$_nikit_clip_description" "$_nikit_clip_file" "$body") || return 1
    echo "Stored at $url"
    return
  fi

  _gist_write "$id" "$_nikit_clip_file" "$body" || return 1
  echo "Stored."
}

# Taking it is the default: a clipboard left lying around on GitHub is worse
# than one you have to store again.
_nikit_clip_load() {
  local keep="${1:-}" id body

  id=$(_nikit_clip_gist)

  if [ -z "$id" ]; then
    echo "Nothing stored." >&2
    echo "Run 'nikit clip store' on the other machine first." >&2
    return 1
  fi

  body=$(_gist_read "$id" "$_nikit_clip_file") || return 1

  printf '%s' "$body" | wl-copy || return 1

  [ -n "$keep" ] && return 0

  _gist_delete "$id" > /dev/null 2>&1
}

_nikit_clip_clear() {
  local id

  id=$(_nikit_clip_gist)

  if [ -z "$id" ]; then
    echo "Nothing stored." >&2
    return 1
  fi

  _gist_delete "$id" > /dev/null 2>&1 || return 1
  echo "Cleared."
}

_nikit_clip() {
  local action="${1:-}" keep=""

  if [ "$XDG_SESSION_TYPE" != "wayland" ]; then
    echo "nikit clip needs a Wayland session." >&2
    return 1
  fi

  if ! command -v wl-copy > /dev/null; then
    echo "Missing: wl-clipboard. Install with: sudo apt install wl-clipboard" >&2
    return 1
  fi

  _gist_ready || return 1

  shift 2> /dev/null

  while [ $# -gt 0 ]; do
    case "$1" in
      -k | --keep) keep=1 ;;
      *)
        echo "nikit clip: no such option '$1'" >&2
        return 1
        ;;
    esac

    shift
  done

  case "$action" in
    store) _nikit_clip_store ;;
    load) _nikit_clip_load "$keep" ;;
    clear) _nikit_clip_clear ;;
    *)
      echo "Usage: nikit clip <subcommand>" >&2
      echo >&2
      echo "Subcommands:" >&2
      echo "  store              Send this machine's clipboard" >&2
      echo "  load [-k|--keep]   Paste it here, and drop it unless kept" >&2
      echo "  clear              Drop what is stored, without pasting" >&2
      return 1
      ;;
  esac
}
