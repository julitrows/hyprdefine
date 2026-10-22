#!/bin/bash

# Install hyprdefine from this git checkout: the packages it needs, a link to
# bin/hyprdefine in ~/.local/bin, and `hyprdefine --setup` for the keys, the
# dictionary server and the `define` shortcut. Safe to run more than once.
#
# The AUR package does the same with files under /usr; see docs/packaging.md.
#
# Usage: ./install.sh [--languages=en,es,...]
#   --languages  install these languages now, by code from lib/hyprdefine/languages

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_aur() {
  if command -v omarchy >/dev/null; then
    omarchy pkg aur add "$@"
  elif command -v yay >/dev/null; then
    yay -S --needed --noconfirm "$@"
  elif command -v paru >/dev/null; then
    paru -S --needed --noconfirm "$@"
  else
    return 1
  fi
}

languages=()
for arg in "$@"; do
  case $arg in
    --languages=*) IFS=, read -r -a languages <<<"${arg#--languages=}" ;;
    *) echo "Usage: ./install.sh [--languages=en,es,...]" >&2; exit 2 ;;
  esac
done

echo "Installing packages..."
if command -v omarchy >/dev/null; then
  omarchy pkg add dictd python curl wl-clipboard gum libnotify
else
  sudo pacman -S --needed --noconfirm dictd python curl wl-clipboard gum libnotify xdg-terminal-exec
fi
# Webster's (GCIDE) is the one dictionary that comes as a package. English
# uses it when it's there, and dict.org when it isn't.
install_aur dict-gcide ||
  echo "Couldn't install dict-gcide from the AUR; English definitions will come from dict.org."

mkdir -p "$HOME/.local/bin"
ln -sfn "$REPO/bin/hyprdefine" "$HOME/.local/bin/hyprdefine"

"$REPO/bin/hyprdefine" --setup
if (( ${#languages[@]} )); then
  "$REPO/bin/hyprdefine" --install "${languages[@]}"
fi
