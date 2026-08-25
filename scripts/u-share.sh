# Carry one thing between machines through a gist, encrypted end to end.
#
#   u-copy  [file|-]    send the clipboard, a file, or stdin
#   u-paste [file|-]    receive into the clipboard, a file, or stdout
#   u-copy -c           drop what is stored, sending nothing
#
# The payload is a tar holding two members, so the kind and the original
# filename travel inside the encryption instead of in the gist listing:
#
#   meta   kind and name
#   data   the bytes
#
# Recipients are the SSH public keys registered on the GitHub account, which
# GitHub already publishes. Nothing has to be copied between machines: each
# one decrypts with the SSH private key it already owns.

_u_share_description="nikit.u-share"
_u_share_file="clip.age"
_u_share_inbox="${XDG_DATA_HOME:-$HOME/.local/share}/nikit/share"

# What raw_url still serves. Above it the gist has to be cloned, which is a
# different tool than this one wants to be.
_u_share_limit=$((10 * 1024 * 1024))

_u_share_human() {
  numfmt --to=iec --suffix=B "$1" 2> /dev/null || echo "$1 bytes"
}

_u_share_ready() {
  local missing=()

  command -v age > /dev/null || missing+=("age")
  command -v gh > /dev/null || missing+=("gh")
  command -v jq > /dev/null || missing+=("jq")

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing: ${missing[*]}. Install with: sudo apt install ${missing[*]}" >&2
    return 1
  fi

  if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "No SSH key at ~/.ssh/id_ed25519, and it is what decrypts here." >&2
    echo "Create one with: ssh-keygen -t ed25519" >&2
    return 1
  fi

  if ! gh auth status > /dev/null 2>&1; then
    echo "gh is not logged in. Run: gh auth login" >&2
    return 1
  fi
}

# The clipboard is only needed when no file and no stream was named.
_u_share_clipboard_ready() {
  if [ "$XDG_SESSION_TYPE" != "wayland" ]; then
    echo "Reaching the clipboard needs a Wayland session." >&2
    echo "Name a file or use '-' to work without it." >&2
    return 1
  fi

  if ! command -v wl-copy > /dev/null; then
    echo "Missing: wl-clipboard. Install with: sudo apt install wl-clipboard" >&2
    return 1
  fi
}

_u_share_gist() {
  _gist_find "$_u_share_description"
}

# Percent-decoding, for the URIs the file manager puts on the clipboard.
_u_share_unescape() {
  printf '%b' "${1//%/\\x}"
}

# The reverse, for handing a path back to the file manager. Everything that is
# not unreserved gets escaped, which is stricter than needed and always safe.
#
# The C locale is what makes this correct: a URI escapes bytes, so an accented
# name has to come out as its UTF-8 pair and not as one code point.
_u_share_escape() {
  local LC_ALL=C string="$1" out="" i char

  for ((i = 0; i < ${#string}; i++)); do
    char="${string:i:1}"

    case "$char" in
      [a-zA-Z0-9.~_/-]) out+="$char" ;;
      *)
        printf -v char '%%%02X' "'$char"
        out+="$char"
        ;;
    esac
  done

  printf '%s' "$out"
}

# Every machine on the account can open what any other one sends.
_u_share_recipients() {
  local user

  user=$(gh api user --jq '.login') || return 1

  curl -fsSL "https://github.com/$user.keys" || {
    echo "Could not read the public keys of '$user' from GitHub." >&2
    return 1
  }
}

# Fills $dir with 'meta' and 'data'. What lands there is decided here and
# nowhere else, so both the sending and the receiving side stay dumb.
_u_share_collect() {
  local dir="$1" source="$2" types line path

  if [ "$source" = "-" ]; then
    cat > "$dir/data"
    printf 'kind: text\nname: stdin\n' > "$dir/meta"
    return
  fi

  if [ -n "$source" ]; then
    if [ ! -f "$source" ]; then
      echo "Not a file: $source" >&2
      return 1
    fi

    cp -- "$source" "$dir/data" || return 1
    printf 'kind: file\nname: %s\n' "$(basename -- "$source")" > "$dir/meta"
    return
  fi

  _u_share_clipboard_ready || return 1

  types=$(wl-paste --list-types 2> /dev/null) || {
    echo "The clipboard is empty." >&2
    return 1
  }

  # A file copied in the file manager also offers text/plain holding its path,
  # so the file types have to be checked first or a file becomes a string.
  if grep -q '^x-special/gnome-copied-files$' <<< "$types"; then
    line=$(wl-paste --type x-special/gnome-copied-files 2> /dev/null | sed -n '2p')
    path=$(_u_share_unescape "${line#file://}")

    if [ ! -f "$path" ]; then
      echo "The clipboard points at something that is not a plain file:" >&2
      echo "  $path" >&2
      return 1
    fi

    cp -- "$path" "$dir/data" || return 1
    printf 'kind: file\nname: %s\n' "$(basename -- "$path")" > "$dir/meta"
    return
  fi

  if grep -q '^image/' <<< "$types"; then
    local mime ext
    mime=$(grep -m1 '^image/' <<< "$types")
    ext="${mime#image/}"

    wl-paste --type "$mime" > "$dir/data" 2> /dev/null || return 1
    printf 'kind: image\nname: clipboard-%s.%s\nmime: %s\n' \
      "$(date +%Y%m%d-%H%M%S)" "$ext" "$mime" > "$dir/meta"
    return
  fi

  # Naming 'text/plain' outright is wrong. The set of types on offer belongs
  # to whoever owns the clipboard, and that changes: once the application
  # that copied is closed, GNOME takes over and offers only
  # 'text/plain;charset=utf-8'. Older applications offer only the X11 names.
  # Take whichever is actually there.
  local text_type="" candidate
  for candidate in 'text/plain;charset=utf-8' 'text/plain' 'UTF8_STRING' 'STRING' 'TEXT'; do
    if grep -qxF "$candidate" <<< "$types"; then
      text_type="$candidate"
      break
    fi
  done

  if [ -z "$text_type" ]; then
    echo "The clipboard holds nothing this can carry." >&2
    echo "It offers: $(echo "$types" | tr '\n' ' ')" >&2
    return 1
  fi

  if ! wl-paste --no-newline --type "$text_type" > "$dir/data" 2> /dev/null; then
    echo "Could not read the clipboard as '$text_type'." >&2
    return 1
  fi

  printf 'kind: text\nname: clip.txt\n' > "$dir/meta"
}

_u_share_write() {
  local source="$1" dir id recipients armoured

  dir=$(mktemp -d) || return 1

  _u_share_collect "$dir" "$source" || { rm -rf "$dir"; return 1; }

  recipients="$dir/recipients"
  _u_share_recipients > "$recipients" || { rm -rf "$dir"; return 1; }

  if [ ! -s "$recipients" ]; then
    echo "No SSH public keys on the account, so there is nobody to encrypt to." >&2
    echo "Add one at: https://github.com/settings/keys" >&2
    rm -rf "$dir"
    return 1
  fi

  tar -cf "$dir/clip.tar" -C "$dir" meta data || { rm -rf "$dir"; return 1; }
  age -a -R "$recipients" -o "$dir/$_u_share_file" "$dir/clip.tar" || { rm -rf "$dir"; return 1; }

  # Past ten megabytes the API stops serving the file through raw_url and
  # wants the gist cloned instead, so refuse rather than store something the
  # other side cannot read back. Armouring costs a third, hence the check
  # lands here, on the real size, instead of guessing from the input.
  armoured=$(stat -c%s "$dir/$_u_share_file")

  if [ "$armoured" -gt "$_u_share_limit" ]; then
    echo "Too large: $(_u_share_human "$(stat -c%s "$dir/data")") becomes $(_u_share_human "$armoured") once encrypted." >&2
    echo "The limit is $(_u_share_human "$_u_share_limit"), which is about $(_u_share_human $((_u_share_limit * 3 / 4))) before encryption." >&2
    rm -rf "$dir"
    return 1
  fi

  # Only one thing is ever stored, so replacing means dropping the old gist
  # rather than committing over it: a gist keeps every revision reachable.
  id=$(_u_share_gist)
  [ -n "$id" ] && _gist_delete "$id" > /dev/null 2>&1

  jq -Rs --arg desc "$_u_share_description" --arg name "$_u_share_file" \
    '{description: $desc, public: false, files: {($name): {content: .}}}' \
    < "$dir/$_u_share_file" |
    gh api -X POST gists --input - --jq '.html_url' > "$dir/url" || {
      rm -rf "$dir"
      return 1
    }

  echo "Sent $(sed -n 's/^kind: //p' "$dir/meta") ($(stat -c%s "$dir/data") bytes)."
  rm -rf "$dir"
}

# Above a megabyte the API stops inlining the content and points at raw_url.
_u_share_fetch() {
  local id="$1" out="$2" response raw

  response=$(gh api "gists/$id") || return 1

  if [ "$(jq -r --arg n "$_u_share_file" '.files[$n].truncated' <<< "$response")" = "true" ]; then
    raw=$(jq -r --arg n "$_u_share_file" '.files[$n].raw_url' <<< "$response")
    curl -fsSL "$raw" -o "$out" || return 1
    return
  fi

  jq -r --arg n "$_u_share_file" '.files[$n].content' <<< "$response" > "$out"
}

# Nautilus shows a dialog here; a terminal gets the same question.
_u_share_may_write() {
  local path="$1" force="$2" answer

  [ -e "$path" ] || return 0
  [ -n "$force" ] && return 0

  if [ ! -t 0 ]; then
    echo "$path already exists. Pass -f to replace it." >&2
    return 1
  fi

  printf '%s already exists (%s bytes, %s).\nReplace? [y/N] ' \
    "$path" "$(stat -c%s -- "$path")" "$(date -d "@$(stat -c%Y -- "$path")" '+%b %d %H:%M')" >&2
  read -r answer

  case "$answer" in
    y | Y | yes | YES) return 0 ;;
    *)
      echo "Kept." >&2
      return 1
      ;;
  esac
}

_u_share_deliver() {
  local dir="$1" dest="$2" force="$3" kind name mime path

  kind=$(sed -n 's/^kind: //p' "$dir/meta")
  name=$(sed -n 's/^name: //p' "$dir/meta")
  mime=$(sed -n 's/^mime: //p' "$dir/meta")

  if [ "$dest" = "-" ]; then
    # Refusing beats scrambling the terminal, and refusing early leaves the
    # gist in place so the command can simply be run again.
    if [ "$kind" != "text" ] && [ -t 1 ] && [ -z "$force" ]; then
      echo "Binary output can mess up your terminal." >&2
      echo "Redirect it to a file or a pipe, or pass -f to write it here anyway." >&2
      return 1
    fi

    cat "$dir/data"

    # Bytes go out untouched, or binary would be corrupted and pipes would
    # gain a line nobody asked for. A prompt landing mid-text is only worth
    # avoiding when a person is the one reading.
    if [ "$kind" = "text" ] && [ -t 1 ] && [ -s "$dir/data" ] &&
      [ "$(tail -c1 "$dir/data" | od -An -c | tr -d ' ')" != '\n' ]; then
      echo
    fi

    return
  fi

  if [ -n "$dest" ]; then
    # A directory means "put it here under its own name", like cp does.
    [ -d "$dest" ] && dest="${dest%/}/$name"

    _u_share_may_write "$dest" "$force" || return 1
    cp -- "$dir/data" "$dest" || return 1
    echo "Wrote $dest."
    return
  fi

  _u_share_clipboard_ready || return 1

  case "$kind" in
    text)
      wl-copy < "$dir/data" || return 1
      echo "Text is on the clipboard."
      ;;
    image)
      wl-copy --type "${mime:-image/png}" < "$dir/data" || return 1
      echo "Image is on the clipboard."
      ;;
    file)
      # The file manager pastes paths, not bytes, so the file has to exist
      # somewhere before the clipboard can point at it.
      mkdir -p "$_u_share_inbox" || return 1

      # The inbox holds one arrival at a time. Whatever is still here was
      # never pasted, since pasting moves it out, so it is safe to drop and
      # the folder cannot grow. No prompt: this is scratch space, not a
      # destination the caller chose.
      if [ -n "$_u_share_inbox" ] && [ -d "$_u_share_inbox" ]; then
        find "$_u_share_inbox" -mindepth 1 -delete || return 1
      fi

      path="$_u_share_inbox/$name"

      cp "$dir/data" "$path" || return 1

      # 'cut' rather than 'copy': the file manager then moves it out of the
      # inbox on paste, so what was received does not pile up here.
      printf 'cut\nfile://%s' "$(_u_share_escape "$path")" |
        wl-copy --type x-special/gnome-copied-files || return 1

      echo "Saved $path, and it is on the clipboard to be moved on paste."
      ;;
    *)
      echo "Unknown kind '$kind' in the payload." >&2
      return 1
      ;;
  esac
}

_u_share_read() {
  local dest="$1" keep="$2" force="$3" id dir

  id=$(_u_share_gist)

  if [ -z "$id" ]; then
    echo "Nothing stored." >&2
    echo "Run 'u-share -w' on the other machine first." >&2
    return 1
  fi

  dir=$(mktemp -d) || return 1

  _u_share_fetch "$id" "$dir/$_u_share_file" || { rm -rf "$dir"; return 1; }

  if ! age -d -i "$HOME/.ssh/id_ed25519" -o "$dir/clip.tar" "$dir/$_u_share_file" 2> "$dir/err"; then
    echo "Could not decrypt it with ~/.ssh/id_ed25519." >&2
    echo "This machine's key was probably not on the account when it was sent." >&2
    sed 's/^/  /' "$dir/err" >&2
    rm -rf "$dir"
    return 1
  fi

  tar -xf "$dir/clip.tar" -C "$dir" || { rm -rf "$dir"; return 1; }

  _u_share_deliver "$dir" "$dest" "$force" || { rm -rf "$dir"; return 1; }

  rm -rf "$dir"

  [ -n "$keep" ] && return 0

  _gist_delete "$id" > /dev/null 2>&1
}

_u_share_clear() {
  local id

  id=$(_u_share_gist)

  if [ -z "$id" ]; then
    echo "Nothing stored." >&2
    return 1
  fi

  _gist_delete "$id" > /dev/null 2>&1 || return 1
  echo "Cleared."
}

# Both commands parse the same way, so the loop lives here and each one says
# which flags it knows. $_u_share_dest and the switches come back through
# these, since a function cannot return more than a number.
_u_share_dest=""
_u_share_flags=""

_u_share_parse() {
  local name="$1" allowed="$2" arg i args=()

  shift 2

  _u_share_dest=""
  _u_share_flags=""

  # Bundled short options, so -kf reads the same as -k -f. A lone '-' is the
  # stream marker and a long option is one word, so neither gets split.
  for arg in "$@"; do
    case "$arg" in
      -- | - | --*) args+=("$arg") ;;
      -?*)
        for ((i = 1; i < ${#arg}; i++)); do
          args+=("-${arg:i:1}")
        done
        ;;
      *) args+=("$arg") ;;
    esac
  done

  set -- "${args[@]}"

  while [ $# -gt 0 ]; do
    case "$1" in
      -)
        _u_share_dest="-"
        ;;
      # Everything after this is a name, however much it looks like a flag.
      # A file manager hands over whatever the file is called, and a file
      # called '-f' must not turn into an option.
      --)
        shift

        if [ $# -gt 1 ]; then
          echo "$name: only one file at a time" >&2
          return 1
        fi

        [ $# -eq 1 ] && _u_share_dest="$1"
        break
        ;;
      -*)
        arg="${1#-}"
        arg="${arg#-}"

        case ":$allowed:" in
          *":$arg:"*) _u_share_flags+="${arg:0:1}" ;;
          *)
            echo "$name: no such option '$1'" >&2
            return 1
            ;;
        esac
        ;;
      *)
        if [ -n "$_u_share_dest" ]; then
          echo "$name: only one file at a time" >&2
          return 1
        fi

        _u_share_dest="$1"
        ;;
    esac

    shift
  done
}

_u_share_has() {
  [[ "$_u_share_flags" == *"$1"* ]]
}

u-copy() {
  case " $* " in
    *" -h "* | *" --help "*)
      echo "Usage: u-copy [file|-]"
      echo
      echo "  (nothing)     Send what is on the clipboard"
      echo "  file          Send that file"
      echo "  -             Send stdin"
      echo
      echo "Options:"
      echo "  -c, --clear   Drop what is stored, sending nothing"
      return 0
      ;;
  esac

  _u_share_parse "u-copy" "c:clear" "$@" || return 1
  _u_share_ready || return 1

  if _u_share_has c; then
    _u_share_clear
    return
  fi

  _u_share_write "$_u_share_dest"
}

u-paste() {
  case " $* " in
    *" -h "* | *" --help "*)
      echo "Usage: u-paste [file|-]"
      echo
      echo "  (nothing)     Put it back on the clipboard"
      echo "  file          Write it there, asking before replacing"
      echo "  -             Write it to stdout"
      echo
      echo "Options:"
      echo "  -k, --keep    Leave it stored instead of consuming it"
      echo "  -f, --force   Replace an existing file without asking"
      return 0
      ;;
  esac

  _u_share_parse "u-paste" "k:keep:f:force" "$@" || return 1
  _u_share_ready || return 1

  _u_share_read "$_u_share_dest" \
    "$(_u_share_has k && echo 1)" \
    "$(_u_share_has f && echo 1)"
}
