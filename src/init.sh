# Everything nikit adds to the shell. Sourced from ~/.bashrc.

_root=~/.local/share/nikit

source "$_root/shell/compression.sh"
source "$_root/shell/goto.sh"
source "$_root/shell/lanip.sh"
source "$_root/shell/nikit.sh"
source "$_root/shell/open.sh"

export PATH="$PATH:$_root/python/bin"

unset _root
