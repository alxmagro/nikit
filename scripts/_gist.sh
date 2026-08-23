# Thin wrappers over the gists API, for scripts that keep state in a gist.
# Nothing here knows what the content is for.

# Without these, gh's own errors reach the caller as an empty answer, which
# reads like "there is nothing there" instead of "I could not ask".
_gist_ready() {
  local missing=()

  command -v gh > /dev/null || missing+=("gh")
  command -v jq > /dev/null || missing+=("jq")

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing: ${missing[*]}. Install with: sudo apt install ${missing[*]}" >&2
    return 1
  fi

  if ! gh auth status > /dev/null 2>&1; then
    echo "gh is not logged in. Run: gh auth login" >&2
    return 1
  fi
}

# Id of the first gist whose description matches exactly. Empty if none.
_gist_find() {
  gh gist list --limit 100 |
    awk -F'\t' -v desc="$1" '$2 == desc { print $1; exit }'
}

# Creates a secret gist with one file. Prints its URL, which ends in the id.
_gist_create() {
  local description="$1" filename="$2" content="$3"

  jq -n \
    --arg desc "$description" \
    --arg name "$filename" \
    --arg content "$content" \
    '{description: $desc, public: false, files: {($name): {content: $content}}}' |
    gh api -X POST gists --input - --jq '.html_url'
}

# Filenames in the gist, one per line.
_gist_files() {
  gh api "gists/$1" --jq '.files | keys[]'
}

# Content of one file. Without a name, the first file.
#
#   _gist_read <id> [file]       content
#   _gist_read -n <id> [file]    filename, then content
#   _gist_read -O <dir> <id>     every file written under its own name
#
# One request either way.
_gist_read() {
  local withname="" outdir="" id filename response

  while [ $# -gt 0 ]; do
    case "$1" in
      -n)
        withname=1
        shift
        ;;
      -O)
        if [ -z "${2:-}" ]; then
          echo "-O needs a directory" >&2
          return 1
        fi

        outdir="$2"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  id="${1:-}"
  filename="${2:-}"

  [ -n "$id" ] || { echo "_gist_read needs a gist id" >&2; return 1; }

  response=$(gh api "gists/$id") || return 1

  if [ -n "$outdir" ]; then
    mkdir -p "$outdir" || return 1

    # Names come from the gist, so refuse anything that escapes the folder.
    echo "$response" | jq -r '.files | keys[]' | while read -r name; do
      case "$name" in
        */* | ..*)
          echo "Skipped '$name': not a plain filename" >&2
          continue
          ;;
      esac

      echo "$response" |
        jq -r --arg name "$name" '.files[$name].content' > "$outdir/$name"
    done

    return 0
  fi

  if [ -z "$filename" ]; then
    filename=$(echo "$response" | jq -r '.files | keys[0]')
  fi

  [ -n "$withname" ] && printf '%s\n' "$filename"

  echo "$response" | jq -r --arg name "$filename" '.files[$name].content'
}

# Creates or replaces one file, leaving the others alone.
_gist_write() {
  local id="$1" filename="$2" content="$3"

  jq -n \
    --arg name "$filename" \
    --arg content "$content" \
    '{files: {($name): {content: $content}}}' |
    gh api -X PATCH "gists/$id" --input - > /dev/null
}

_gist_describe() {
  jq -n --arg desc "$2" '{description: $desc}' |
    gh api -X PATCH "gists/$1" --input - > /dev/null
}

# Renames one file, keeping its content.
_gist_rename() {
  jq -n --arg name "$2" --arg newname "$3" \
    '{files: {($name): {filename: $newname}}}' |
    gh api -X PATCH "gists/$1" --input - > /dev/null
}

# A null entry is how the API spells "drop this file".
_gist_remove() {
  local id="$1" filename="$2"

  jq -n --arg name "$filename" '{files: {($name): null}}' |
    gh api -X PATCH "gists/$id" --input - > /dev/null
}

_gist_delete() {
  # --yes arrived in a later gh; older ones delete without asking anyway.
  if gh gist delete --help 2>&1 | grep -q -- '--yes'; then
    gh gist delete "$1" --yes
  else
    gh gist delete "$1"
  fi
}
