#!/bin/bash

# Remove the define command, the keybindings and the Spanish dictionary.
# Packages are left installed.

set -euo pipefail

HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
DICTD_CONF=/etc/dict/dictd.conf
SPANISH_DIR=/usr/local/share/dictd

rm -f "$HOME/.local/bin/define"
if [[ -L $HOME/.claude/skills/omarchy-dict ]]; then
  rm "$HOME/.claude/skills/omarchy-dict"
fi
sed -i '/-- omarchy-dict$/d' "$HYPRLAND_LUA"
hyprctl reload >/dev/null

sudo sed -i '/^# omarchy-dict begin$/,/^# omarchy-dict end$/d' "$DICTD_CONF"
sudo rm -f "$SPANISH_DIR/es-es.dict.dz" "$SPANISH_DIR/es-es.index"
if systemctl -q is-active dictd; then
  sudo systemctl restart dictd
fi

echo "Removed. Uninstall the packages with:"
echo "  omarchy pkg drop dict-freedict-spa-eng-bin dict-freedict-eng-spa-bin dict-gcide dictd"
