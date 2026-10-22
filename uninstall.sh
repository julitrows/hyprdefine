#!/bin/bash

# Remove the define command, the keybindings, the dictionary server and every
# downloaded dictionary. Packages are left installed.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
DATA="$HOME/.local/share/omarchy-dict"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-dict"
UNIT="$HOME/.config/systemd/user/omarchy-dict.service"
# Where versions before the user-level server kept their dictionaries.
LEGACY_CONF=/etc/dict/dictd.conf
LEGACY_DIR=/usr/local/share/dictd

# Only remove links that point into this repo, never someone else's files.
remove_link() {
  if [[ -L $1 && $(readlink "$1") == "$2" ]]; then
    rm "$1"
  fi
}

if [[ -L $UNIT ]]; then
  systemctl --user disable --now omarchy-dict.service || true
fi
remove_link "$UNIT" "$REPO/systemd/omarchy-dict.service"
systemctl --user daemon-reload

remove_link "$HOME/.local/bin/define" "$REPO/bin/define"
remove_link "$HOME/.claude/skills/omarchy-dict" "$REPO/skills/omarchy-dict"
rm -rf "$DATA" "$CONFIG"
if [[ -f $HYPRLAND_LUA ]]; then
  sed -i '/-- omarchy-dict$/d' "$HYPRLAND_LUA"
fi

if grep -q '^# omarchy-dict begin$' "$LEGACY_CONF" 2>/dev/null; then
  sudo sed -i '/^# omarchy-dict begin$/,/^# omarchy-dict end$/d' "$LEGACY_CONF"
  while read -r code _; do
    [[ -z $code || $code == \#* ]] && continue
    sudo rm -f "$LEGACY_DIR/$code-$code.dict.dz" "$LEGACY_DIR/$code-$code.index"
  done <"$REPO/lib/languages"
  sudo systemctl try-restart dictd
fi

# hyprctl fails outside a Hyprland session, such as over SSH.
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null
fi

packages=$(pacman -Qq | grep -E '^dict-(freedict-.*-bin|gcide)$|^dictd$' | xargs)
echo "Removed. Uninstall the packages with:"
if command -v omarchy >/dev/null; then
  echo "  omarchy pkg drop $packages"
else
  echo "  sudo pacman -Rns $packages"
fi
