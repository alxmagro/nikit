#!/bin/bash
#
# Bootstrap for a fresh machine:
#
#   wget -qO - https://raw.githubusercontent.com/alxmagro/nikit/main/get.sh | bash -s debian_13
#
# Unpacks the repo into a temporary folder and hands over to the install.sh
# inside it. Arguments go straight through.

set -eo pipefail

repo="alxmagro/nikit"
ref="main"
src="$(mktemp -d)"
url="https://github.com/$repo/archive/refs/heads/$ref.tar.gz"

trap 'rm -rf "$src"' EXIT

echo "nikit  $repo@$ref"
echo

mkdir -p "$src"

if command -v curl > /dev/null; then
  curl -fsSL "$url"
else
  wget -qO - "$url"
fi | tar xz -C "$src" --strip-components 1

bash "$src/install.sh" "$@"
