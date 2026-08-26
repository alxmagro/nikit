# Everything nikit adds to the shell. Sourced from ~/.bashrc.

_root=~/.local/share/nikit

source "$_root/shell/compression.sh"
source "$_root/shell/goto.sh"
source "$_root/shell/lanip.sh"
source "$_root/shell/nikit.sh"
source "$_root/shell/open.sh"

# bin/ holds what the install generates rather than copies, so it survives
# python/ being wiped and re-copied.
export PATH="$PATH:$_root/python/bin:$_root/bin"

unset _root
