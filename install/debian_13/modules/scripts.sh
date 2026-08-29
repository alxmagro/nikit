#!/bin/bash

set -e

log 'Copying commands...'

# Emptied rather than copied over: a file that was renamed or dropped would
# otherwise keep being loaded from an earlier install. config/ is left alone.
rm -rf "$PROJECT_ROOT/python" "$PROJECT_ROOT/shell" "$PROJECT_ROOT/init.sh"

ensure_folder "$PROJECT_ROOT"

cp -r "$SH_ROOT"/src/* "$PROJECT_ROOT/"

append_once "$HOME/.bashrc" 'source ~/.local/share/nikit/init.sh'

# Writes $PROJECT_ROOT/bin/<tool>: a wrapper that refuses to install the tool
# silently, but keeps it up to date once you have installed it yourself.
mise_wrapper() {
  local tool="$1"

  cat > "$PROJECT_ROOT/bin/$tool" << EOF
#!/bin/bash
if ! mise which "$tool" > /dev/null 2>&1; then
  echo "$tool is not installed. Run: mise use -g $tool" >&2
  exit 127
fi

mise use -g --quiet "$tool"
exec mise x "$tool" -- "$tool" "\$@"
EOF

  chmod +x "$PROJECT_ROOT/bin/$tool"
}

log 'Adding AI agent wrappers...'

ensure_folder "$PROJECT_ROOT/bin"

mise_wrapper claude
mise_wrapper codex
mise_wrapper copilot
mise_wrapper gemini
