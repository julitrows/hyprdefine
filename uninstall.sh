#!/bin/bash

# Remove the define command, the keybindings and the Spanish dictionary.
# Packages are left installed.

set -euo pipefail

HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
DICTD_CONF=/etc/dict/dictd.conf
SPANISH_DIR=/usr/local/share/dictd

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Only remove links that point into this repo, never someone else's files.
remove_link() {
  if [[ -L $1 && $(readlink "$1") == "$2" ]]; then
    rm "$1"
  fi
}

remove_link "$HOME/.local/bin/define" "$REPO/bin/define"
remove_link "$HOME/.claude/skills/omarchy-dict" "$REPO/skills/omarchy-dict"
if [[ -f $HYPRLAND_LUA ]]; then
  sed -i '/-- omarchy-dict$/d' "$HYPRLAND_LUA"
fi

sudo sed -i '/^# omarchy-dict begin$/,/^# omarchy-dict end$/d' "$DICTD_CONF"
sudo rm -f "$SPANISH_DIR/es-es.dict.dz" "$SPANISH_DIR/es-es.index"
if systemctl -q is-active dictd; then
  sudo systemctl restart dictd
fi

# hyprctl fails outside a Hyprland session, such as over SSH.
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null
fi

echo "Removed. Uninstall the packages with:"
if command -v omarchy >/dev/null; then
  echo "  omarchy pkg drop dict-freedict-spa-eng-bin dict-freedict-eng-spa-bin dict-gcide dictd"
else
  echo "  sudo pacman -Rns dict-freedict-spa-eng-bin dict-freedict-eng-spa-bin dict-gcide dictd"
fi
