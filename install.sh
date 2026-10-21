#!/bin/bash

# Install omarchy-dict: dictionary packages, the define command and the
# Hyprland keybinding. Safe to run more than once.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
MARKER="-- omarchy-dict"

echo "Installing dictionary packages..."
omarchy pkg add dictd
omarchy pkg aur add dict-gcide || echo "Could not install dict-gcide from the AUR; define will use dict.org."
sudo systemctl enable --now dictd

echo "Linking define into ~/.local/bin..."
mkdir -p "$HOME/.local/bin"
ln -sfn "$REPO/bin/define" "$HOME/.local/bin/define"

if ! grep -qF "$MARKER" "$HYPRLAND_LUA"; then
  echo "Loading the keybinding from $HYPRLAND_LUA..."
  printf '\ndofile("%s/hypr/dictionary.lua") %s\n' "$REPO" "$MARKER" >>"$HYPRLAND_LUA"
fi

hyprctl reload >/dev/null
hyprctl configerrors

echo "Done. Press SUPER + ALT + D to look up a word."
