#!/bin/bash

# Remove the define command and the keybinding. Packages are left installed.

set -euo pipefail

HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"

rm -f "$HOME/.local/bin/define"
sed -i '/-- omarchy-dict$/d' "$HYPRLAND_LUA"
hyprctl reload >/dev/null

echo "Removed. Uninstall the packages with: omarchy pkg drop dict-gcide dictd"
