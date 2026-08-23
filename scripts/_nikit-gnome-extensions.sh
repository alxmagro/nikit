# GNOME extensions kept in a gist: which ones to install, and how each one
# is configured. One file per extension, so saving one leaves the rest alone.

_nikit_ext_description="nikit: gnome-extensions"
_nikit_ext_manifest="_extensions.list"
_nikit_ext_base="/org/gnome/shell/extensions/"
_nikit_ext_site="https://extensions.gnome.org"

_nikit_ext_dir() {
  echo "$HOME/.local/share/gnome-shell/extensions"
}

_nikit_ext_shell_version() {
  gnome-shell --version | awk '{ print $3 }' | cut -d. -f1
}

# The enabled-extensions key keeps the uuid of everything ever tried, so it
# only means something intersected with what is actually on disk.
_nikit_ext_active() {
  comm -12 \
    <(gnome-extensions list | sort) \
    <(gsettings get org.gnome.shell enabled-extensions |
      tr -d "[]'" | tr ',' '\n' | sed 's/^ *//' | sort -u)
}

# Settings live under the extension's schema id, which is not the uuid:
# rounded-window-corners@fxgn writes to rounded-window-corners-reborn. The
# id comes from metadata.json when it declares one, and from the installed
# schema when it does not. Guessing from the uuid would quietly save the
# wrong subtree, so an extension without either simply has no settings.
_nikit_ext_path() {
  local uuid="$1" dir schema rel

  dir="$(_nikit_ext_dir)/$uuid"

  schema=$(jq -r '."settings-schema" // empty' "$dir/metadata.json" 2>/dev/null)

  if [ -z "$schema" ]; then
    schema=$(grep -ho 'id="org\.gnome\.shell\.extensions\.[^"]*"' \
      "$dir"/schemas/*.gschema.xml 2>/dev/null |
      sed 's/id="//; s/"$//' | head -1)
  fi

  [ -n "$schema" ] || return 1

  rel="${schema#org.gnome.shell.extensions.}"
  [ "$rel" != "$schema" ] || return 1

  echo "${rel//.//}"
}

# dconf dump anchors its sections at [/]. Re-anchor them under the
# extension's own subpath so the result loads back into the extensions root.
_nikit_ext_dump() {
  local uuid="$1" rel dump

  rel=$(_nikit_ext_path "$uuid") || return 1

  dump=$(dconf dump "$_nikit_ext_base$rel/" 2>/dev/null) || return 1
  [ -n "$dump" ] || return 1

  echo "$dump" | awk -v rel="$rel" '
    /^\[\/\]$/ { print "[" rel "]"; next }
    /^\[/      { sub(/^\[/, "[" rel "/"); print; next }
               { print }
  '
}

_nikit_ext_gist() {
  _gist_find "$_nikit_ext_description"
}

_nikit_ext_missing() {
  echo "Nothing stored yet." >&2
  echo "Run 'nikit gnome-extensions sync' first." >&2
}

# Everything that could be in the manifest: installed here, or listed there
# already. An extension uninstalled locally still shows up, so it can be
# unmarked.
_nikit_ext_choices() {
  local listed="$1"

  {
    _nikit_ext_active
    printf '%s\n' "$listed"
  } | awk 'NF' | sort -u
}

# fzf cannot start with items selected, so they are selected on the load
# event, which is when the list is finished and pos(n) has somewhere to land.
_nikit_ext_preselect() {
  local choices="$1" marked="$2" line binds="" n=0

  while read -r line; do
    n=$((n + 1))

    case $'\n'"$marked"$'\n' in
      *$'\n'"$line"$'\n'*) binds="$binds+pos($n)+select" ;;
    esac
  done <<< "$choices"

  printf 'load:%spos(1)' "${binds:++${binds#+}+}" | sed 's/^load:+/load:/'
}

_nikit_ext_pick() {
  local choices="$1" marked="$2"

  if [ -z "$choices" ]; then
    echo "No extension is both installed and enabled." >&2
    return 1
  fi

  if ! command -v fzf > /dev/null; then
    echo "fzf is needed to choose which extensions to mark." >&2
    return 1
  fi

  printf '%s\n' "$choices" | fzf \
    --multi \
    --height 40% \
    --layout reverse \
    --info hidden \
    --no-separator \
    --prompt '$ ' \
    --header 'tab mark · ctrl-a all · enter confirm · ctrl-c exit' \
    --header-first \
    --pointer '›' \
    --marker '✓ ' \
    --bind 'ctrl-a:select-all' \
    --bind "$(_nikit_ext_preselect "$choices" "$marked")" \
    --color 'fg+:-1:regular,bg+:-1,prompt:15:regular,query:-1:regular,pointer:4,hl:4,hl+:4,header:8,marker:4'
}

# Every extension goes into one buffer, split apart again by its marker
# line. dconf reads '#' as a comment, so the markers survive a round trip.
#
# stdin lists which extensions go in; $2 says which of them come fresh from
# this machine instead of from the stored copy in $1. That is what makes a
# partial sync possible: an extension left out keeps what was stored,
# trimming included.
_nikit_ext_buffer() {
  local stored="$1" fresh="$2" uuid section

  while read -r uuid; do
    [ -n "$uuid" ] || continue

    case $'\n'"$fresh"$'\n' in
      *$'\n'"$uuid"$'\n'*) section=$(_nikit_ext_dump "$uuid") ;;
      *) section=$(printf '%s\n' "$stored" | _nikit_ext_section "$uuid") ;;
    esac

    [ -n "$section" ] || continue

    printf '## %s\n%s\n\n' "$uuid" "$section"
  done
}

# The whole gist as one buffer: every stored section, in one string.
_nikit_ext_stored() {
  local id="$1" dir uuid out=""

  dir=$(mktemp -d)

  if ! _gist_read -O "$dir" "$id"; then
    rm -rf "$dir"
    return 1
  fi

  while read -r uuid _; do
    [ -f "$dir/$uuid.dconf" ] || continue

    out="$out## $uuid"$'\n'"$(cat "$dir/$uuid.dconf")"$'\n\n'
  done < "$dir/$_nikit_ext_manifest"

  rm -rf "$dir"

  printf '%s' "$out"
}

_nikit_ext_section() {
  awk -v uuid="$1" '
    /^## / { keep = ($2 == uuid); next }
    keep   { print }
  ' | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba'
}

# What was marked becomes the manifest. A line that was already there comes
# back verbatim, so anything you added to it by hand survives.
_nikit_ext_manifest_merge() {
  local existing="$1" picked="$2"

  awk '
    NR == FNR { if (NF) kept[$1] = $0; next }
    NF        { print ($1 in kept) ? kept[$1] : $1 }
  ' <(printf '%s\n' "$existing") <(printf '%s\n' "$picked")
}

_nikit_ext_manifest_uuids() {
  awk 'NF { print $1 }'
}

# Adds what was marked, keeping the lines already there untouched.
_nikit_ext_manifest_union() {
  local existing="$1" picked="$2"

  {
    printf '%s\n' "$existing"
    printf '%s\n' "$picked"
  } | awk 'NF && !seen[$1]++'
}

# Opens the buffer, then writes back only what actually differs from what
# the gist already holds. Everything here is compared against the stored
# copy, so a run where nothing was touched sends nothing.
_nikit_ext_commit() {
  local id="$1" manifest="$2" existing="$3" stored="$4" buffer="$5"
  local tmp after uuid new old kept touched=0

  tmp=$(mktemp -d)/extensions.dconf
  printf '%s' "$buffer" > "$tmp"

  # An extension can be listed and have nothing to configure.
  [ -s "$tmp" ] && "${EDITOR:-nano}" "$tmp"

  after=$(cat "$tmp")
  rm -rf "$(dirname "$tmp")"

  kept=$(printf '%s\n' "$manifest" | _nikit_ext_manifest_uuids)

  if [ "$manifest" != "$existing" ]; then
    _gist_write "$id" "$_nikit_ext_manifest" "$manifest" || return 1
    touched=1
  fi

  while read -r uuid; do
    [ -n "$uuid" ] || continue

    new=$(printf '%s\n' "$after" | _nikit_ext_section "$uuid")
    old=$(printf '%s\n' "$stored" | _nikit_ext_section "$uuid")

    [ -n "$new" ] || continue
    [ "$new" = "$old" ] && continue

    _gist_write "$id" "$uuid.dconf" "$new" && touched=1
  done <<< "$kept"

  while read -r uuid; do
    [ -n "$uuid" ] || continue

    case $'\n'"$kept"$'\n' in
      *$'\n'"$uuid"$'\n'*) continue ;;
    esac

    _gist_remove "$id" "$uuid.dconf" && touched=1
  done <<< "$(printf '%s\n' "$existing" | _nikit_ext_manifest_uuids)"

  [ "$touched" -eq 1 ] && echo "Saved."
}

# Push this machine's settings for the extensions you mark. What is left
# unmarked keeps the stored copy, trimming and all.
_nikit_ext_sync() {
  local id url existing picked stored manifest

  id=$(_nikit_ext_gist)

  if [ -n "$id" ]; then
    existing=$(_gist_read "$id" "$_nikit_ext_manifest" 2>/dev/null)
    stored=$(_nikit_ext_stored "$id")
  fi

  picked=$(_nikit_ext_pick "$(_nikit_ext_active)" "") || return 1
  [ -n "$picked" ] || return 1

  manifest=$(_nikit_ext_manifest_union "$existing" "$picked")

  if [ -z "$id" ]; then
    url=$(_gist_create "$_nikit_ext_description" "$_nikit_ext_manifest" \
      "$manifest") || return 1

    id="${url##*/}"
    echo "Created at $url"
  fi

  _nikit_ext_commit "$id" "$manifest" "$existing" "$stored" \
    "$(printf '%s\n' "$manifest" | _nikit_ext_manifest_uuids |
      _nikit_ext_buffer "$stored" "$picked")"
}

# Correct what is stored, without touching this machine. Unmarking removes.
_nikit_ext_edit() {
  local id existing listed picked stored manifest

  id=$(_nikit_ext_gist)

  if [ -z "$id" ]; then
    _nikit_ext_missing
    return 1
  fi

  existing=$(_gist_read "$id" "$_nikit_ext_manifest" 2>/dev/null)
  stored=$(_nikit_ext_stored "$id")
  listed=$(printf '%s\n' "$existing" | _nikit_ext_manifest_uuids)

  picked=$(_nikit_ext_pick "$listed" "$listed") || return 1
  [ -n "$picked" ] || return 1

  manifest=$(_nikit_ext_manifest_merge "$existing" "$picked")

  _nikit_ext_commit "$id" "$manifest" "$existing" "$stored" \
    "$(printf '%s\n' "$picked" | _nikit_ext_buffer "$stored" "")"
}

_nikit_ext_show() {
  local id dir uuid

  id=$(_nikit_ext_gist)

  if [ -z "$id" ]; then
    _nikit_ext_missing
    return 1
  fi

  if [ "${1:-}" != "--config" ]; then
    _gist_read "$id" "$_nikit_ext_manifest"
    return
  fi

  dir=$(mktemp -d)

  if ! _gist_read -O "$dir" "$id"; then
    rm -rf "$dir"
    return 1
  fi

  # Same shape the editor shows during an edit, so the two read alike.
  while read -r uuid _; do
    [ -f "$dir/$uuid.dconf" ] || continue

    printf '## %s\n' "$uuid"
    cat "$dir/$uuid.dconf"
    echo
  done < "$dir/$_nikit_ext_manifest"

  rm -rf "$dir"
}

_nikit_ext_install_site() {
  local uuid="$1" version="$2" info path zip status=1

  info=$(curl -fsSL "$_nikit_ext_site/extension-info/?uuid=$uuid&shell_version=$version") || return 1

  path=$(printf '%s' "$info" | jq -r '.download_url // empty')
  [ -n "$path" ] || return 1

  zip=$(mktemp --suffix=.zip)

  curl -fsSL "$_nikit_ext_site$path" -o "$zip" &&
    gnome-extensions install --force "$zip" &&
    status=0

  rm -f "$zip"
  return $status
}

# Only what extensions.gnome.org publishes. Installing from an arbitrary
# repository would mean running its build as you, on the word of a gist.
_nikit_ext_restore() {
  local id dir version uuid failed=() installed=0

  id=$(_nikit_ext_gist)

  if [ -z "$id" ]; then
    _nikit_ext_missing
    return 1
  fi

  dir=$(mktemp -d)

  if ! _gist_read -O "$dir" "$id"; then
    rm -rf "$dir"
    return 1
  fi

  if [ ! -f "$dir/$_nikit_ext_manifest" ]; then
    echo "The gist has no $_nikit_ext_manifest." >&2
    rm -rf "$dir"
    return 1
  fi

  version=$(_nikit_ext_shell_version)

  while read -r uuid _; do
    [ -n "$uuid" ] || continue

    if gnome-extensions list | grep -qx "$uuid"; then
      :
    elif ! _nikit_ext_install_site "$uuid" "$version"; then
      failed+=("$uuid")
      continue
    fi

    gnome-extensions enable "$uuid" 2>/dev/null
    installed=$((installed + 1))

    [ -f "$dir/$uuid.dconf" ] &&
      dconf load "$_nikit_ext_base" < "$dir/$uuid.dconf"
  done < "$dir/$_nikit_ext_manifest"

  rm -rf "$dir"

  echo "Restored $installed extension(s)."

  if [ ${#failed[@]} -gt 0 ]; then
    echo
    echo "Not published for GNOME $version, install these by hand:"
    printf '  %s\n' "${failed[@]}"
  fi

  echo
  echo "Log out and back in for the shell to pick them up."
}

_nikit_gnome_extensions() {
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    echo "No desktop session: dconf and gnome-extensions need one." >&2
    return 1
  fi

  _gist_ready || return 1

  case "${1:-}" in
    sync) _nikit_ext_sync ;;
    edit) _nikit_ext_edit ;;
    restore) _nikit_ext_restore ;;
    show)
      shift
      _nikit_ext_show "$@"
      ;;
    *)
      echo "Usage: nikit gnome-extensions <subcommand>" >&2
      echo >&2
      echo "Subcommands:" >&2
      echo "  sync               Send this machine's settings for the ones you mark" >&2
      echo "  edit               Change what is stored, without reading this machine" >&2
      echo "  restore            Install and configure them on this machine" >&2
      echo "  show [--config]    Print the stored list, or the stored settings" >&2
      return 1
      ;;
  esac
}
