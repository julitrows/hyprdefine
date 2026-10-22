#!/bin/bash

# Install omarchy-dict: packages, the user-level dictionary server, the define
# command and the Hyprland keybindings. Safe to run more than once. Works on
# Omarchy and on any Arch install running Hyprland with a Lua config.
#
# Languages are offered as words are looked up in them, and managed with
# `define --languages`; they don't need sudo.
#
# Usage: ./install.sh [--languages=en,es,...] [--update]
#   --languages  install these languages now, by code from lib/languages
#   --update     rebuild the installed languages from the latest downloads

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
MARKER="-- omarchy-dict"
DATA="$HOME/.local/share/omarchy-dict"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-dict"
UNIT="$HOME/.config/systemd/user/omarchy-dict.service"
# Where versions before the user-level server kept their dictionaries.
LEGACY_CONF=/etc/dict/dictd.conf
LEGACY_DIR=/usr/local/share/dictd

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

# Move dictionaries an earlier version installed system-wide into $DATA, and
# print their codes. Copying them saves rebuilding.
migrate() {
  local code
  grep -q '^# omarchy-dict begin$' "$LEGACY_CONF" 2>/dev/null || return 0

  echo "Moving dictionaries from an earlier version into $DATA..." >&2
  mkdir -p "$DATA/dictionaries"
  while read -r code _; do
    [[ -z $code || $code == \#* ]] && continue
    if [[ -f $LEGACY_DIR/$code-$code.index ]]; then
      # Runs inside $(...), where set -e doesn't apply, so only delete the
      # originals once they're copied.
      if cp -n "$LEGACY_DIR/$code-$code.dict.dz" "$LEGACY_DIR/$code-$code.index" "$DATA/dictionaries/"; then
        sudo rm -f "$LEGACY_DIR/$code-$code.dict.dz" "$LEGACY_DIR/$code-$code.index"
        echo "$code"
      fi
    fi
  done <"$REPO/lib/languages"
  sudo sed -i '/^# omarchy-dict begin$/,/^# omarchy-dict end$/d' "$LEGACY_CONF"
  sudo systemctl try-restart dictd
}

languages=()
update=false
for arg in "$@"; do
  case $arg in
    --languages=*) read -r -a languages <<<"$(tr ',' ' ' <<<"${arg#--languages=}")" ;;
    --update) update=true ;;
    *) echo "Usage: ./install.sh [--languages=en,es,...] [--update]" >&2; exit 2 ;;
  esac
done

if [[ ! -f $HYPRLAND_LUA ]]; then
  echo "omarchy-dict needs Hyprland's Lua config, and $HYPRLAND_LUA doesn't exist." >&2
  exit 1
fi

echo "Installing packages..."
if command -v omarchy >/dev/null; then
  omarchy pkg add dictd python wl-clipboard gum libnotify
else
  sudo pacman -S --needed --noconfirm dictd python wl-clipboard gum libnotify xdg-terminal-exec
fi
# GCIDE is the one dictionary that isn't downloaded per user: English uses it
# from the package when it's there, and from dict.org when it isn't.
install_aur dict-gcide ||
  echo "Could not install dict-gcide from the AUR; English definitions will come from dict.org."

read -r -a migrated <<<"$(migrate | xargs)"
# Earlier versions always had English, so keep it alongside what they built.
if (( ${#migrated[@]} )) && [[ ! -s $CONFIG/languages ]]; then
  languages+=(en "${migrated[@]}")
fi

echo "Setting up the dictionary server..."
mkdir -p "$(dirname "$UNIT")"
ln -sfn "$REPO/systemd/omarchy-dict.service" "$UNIT"
systemctl --user daemon-reload
systemctl --user enable omarchy-dict.service

if (( ${#languages[@]} )); then
  "$REPO/lib/dictionaries" install "${languages[@]}"
fi
if [[ $update == true ]]; then
  "$REPO/lib/dictionaries" update
fi

echo "Linking define into ~/.local/bin..."
mkdir -p "$HOME/.local/bin"
ln -sfn "$REPO/bin/define" "$HOME/.local/bin/define"

if [[ -d $HOME/.claude ]]; then
  echo "Linking the omarchy-dict skill into ~/.claude/skills..."
  mkdir -p "$HOME/.claude/skills"
  ln -sfn "$REPO/skills/omarchy-dict" "$HOME/.claude/skills/omarchy-dict"
fi

if ! grep -qF -e "$MARKER" "$HYPRLAND_LUA"; then
  echo "Loading the keybindings from $HYPRLAND_LUA..."
  # No blank line before it, so uninstall.sh's one-line delete leaves the file
  # as it was. Only add a newline if the file doesn't end with one.
  [[ -z $(tail -c1 "$HYPRLAND_LUA") ]] || echo >>"$HYPRLAND_LUA"
  printf 'dofile("%s/hypr/dictionary.lua") %s\n' "$REPO" "$MARKER" >>"$HYPRLAND_LUA"
fi

# hyprctl fails outside a Hyprland session, such as over SSH; the bindings load
# on the next login instead.
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null
  hyprctl configerrors
fi

echo "Done. Press SUPER + ALT + D to look a word up, or SUPER + ALT + W for the selected word."
echo "Languages are offered as you use them; run 'define --languages' to manage them."
