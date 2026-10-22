#!/bin/bash

# Remove hyprdefine installed from this git checkout: `hyprdefine --teardown`
# (keys, dictionary server, dictionaries, `define`) and the ~/.local/bin link.
# Packages are left installed.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$REPO/bin/hyprdefine" --teardown

link="$HOME/.local/bin/hyprdefine"
if [[ -L $link && $(readlink "$link") == "$REPO/bin/hyprdefine" ]]; then
  rm "$link"
fi

# Only the dictionary packages: gum and the rest are likely used elsewhere.
packages=$(pacman -Qq dictd dict-gcide 2>/dev/null | xargs)
if [[ -n $packages ]]; then
  echo "To remove the dictionary packages too: sudo pacman -Rns $packages"
fi
