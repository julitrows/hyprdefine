#!/bin/bash

# Install omarchy-dict: dictionary packages, the Spanish dictionary, the define
# command and the Hyprland keybindings. Safe to run more than once.
#
# Usage: ./install.sh [--update]
#   --update  download and rebuild the Spanish dictionary even if it's installed

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
DICTD_CONF=/etc/dict/dictd.conf
SPANISH_DIR=/usr/local/share/dictd
SPANISH_URL=https://www.reader-dict.com/file/es/dictorg-es-es-noetym.zip
MARKER="-- omarchy-dict"

install_spanish() {
  build=$(mktemp -d)
  trap 'rm -rf "$build"' EXIT

  echo "Downloading the Spanish dictionary..."
  curl -fL --progress-bar -o "$build/es.zip" "$SPANISH_URL"

  echo "Building the Spanish dictionary (takes a minute or two)..."
  python3 -I "$REPO/lib/spanish-dict.py" "$build/es.zip" |
    dictfmt -f --utf8 --quiet --columns 0 \
      -u https://www.reader-dict.com -s "Diccionario español (Wiktionary, reader.dict)" \
      "$build/es-es"
  dictzip "$build/es-es.dict"
  sudo install -Dm644 -t "$SPANISH_DIR" "$build/es-es.dict.dz" "$build/es-es.index"
}

# Runs on every install, so a block lost from dictd.conf comes back even when
# the dictionary files are already in place.
register_spanish() {
  if ! grep -q "^database es-es" "$DICTD_CONF"; then
    printf '# omarchy-dict begin\ndatabase es-es {\n\tdata %s/es-es.dict.dz\n\tindex %s/es-es.index\n}\n# omarchy-dict end\n' \
      "$SPANISH_DIR" "$SPANISH_DIR" | sudo tee -a "$DICTD_CONF" >/dev/null
  fi
}

echo "Installing dictionary packages..."
omarchy pkg add dictd python
omarchy pkg aur add dict-gcide dict-freedict-eng-spa-bin dict-freedict-spa-eng-bin ||
  echo "Could not install the offline dictionaries from the AUR; define will use dict.org."

if [[ ${1:-} == --update || ! -f $SPANISH_DIR/es-es.index ]]; then
  install_spanish
fi
register_spanish

sudo systemctl enable dictd
sudo systemctl restart dictd

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

echo "Done. Press SUPER + ALT + D for English or SUPER + SHIFT + ALT + D for Spanish."
