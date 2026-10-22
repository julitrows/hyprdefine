#!/bin/bash

# Install omarchy-dict: dictionary packages, a dictionary for each chosen
# language, the define command and the Hyprland keybindings. Safe to run more
# than once. Works on Omarchy and on any Arch install running Hyprland with a
# Lua config.
#
# Usage: ./install.sh [--update] [--languages=en,es,...]
#   --update     download and rebuild the chosen dictionaries even if they're
#                installed
#   --languages  the languages to install, by code from lib/languages. Without
#                it, asks, starting from the last choice (or from English and
#                Spanish, the first time). Run again to change them.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
DICTD_CONF=/etc/dict/dictd.conf
DICT_DIR=/usr/local/share/dictd
READER_URL=https://www.reader-dict.com/file
MARKER="-- omarchy-dict"
LANGUAGES_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-dict/languages"

# Supported languages, in the order they're offered and saved.
LANGUAGES=()
declare -A FREEDICT NAMES
while read -r code freedict name; do
  [[ -z $code || $code == \#* ]] && continue
  LANGUAGES+=("$code")
  FREEDICT[$code]=$freedict
  NAMES[$code]=$name
done <"$REPO/lib/languages"

# Download reader.dict's dictionary for a language and install it as
# <code>-<code>. English uses GCIDE from the AUR instead.
install_language() {
  local code=$1 dir="$build/$1"
  mkdir -p "$dir"

  echo "Downloading the ${NAMES[$code]} dictionary..."
  curl -fL --progress-bar -o "$dir/download.zip" "$READER_URL/$code/dictorg-$code-$code-noetym.zip"

  echo "Building the ${NAMES[$code]} dictionary (takes a minute or two)..."
  python3 -I "$REPO/lib/reader-dict.py" "$dir/download.zip" |
    dictfmt -f --utf8 --quiet --columns 0 \
      -u https://www.reader-dict.com -s "${NAMES[$code]} (Wiktionary, reader.dict)" \
      "$dir/$code-$code"
  dictzip "$dir/$code-$code.dict"
  sudo install -Dm644 -t "$DICT_DIR" "$dir/$code-$code.dict.dz" "$dir/$code-$code.index"
}

remove_language() {
  if [[ -f $DICT_DIR/$1-$1.index ]]; then
    echo "Removing the ${NAMES[$1]} dictionary..."
    sudo rm -f "$DICT_DIR/$1-$1.dict.dz" "$DICT_DIR/$1-$1.index"
  fi
}

# Rewrite the block in dictd.conf on every install, so it lists exactly the
# chosen languages, and comes back if it was lost.
register_languages() {
  local code block=""

  for code in $languages; do
    [[ $code == en ]] && continue
    block+=$(printf 'database %s {\n\tdata %s\n\tindex %s\n}' "$code-$code" \
      "$DICT_DIR/$code-$code.dict.dz" "$DICT_DIR/$code-$code.index")$'\n'
  done

  sudo sed -i '/^# omarchy-dict begin$/,/^# omarchy-dict end$/d' "$DICTD_CONF"
  if [[ -n $block ]]; then
    printf '# omarchy-dict begin\n%s# omarchy-dict end\n' "$block" | sudo tee -a "$DICTD_CONF" >/dev/null
  fi
}

# Ask which languages to install, with the given ones selected, and print
# their codes.
ask_languages() {
  local code options=() selected=() answer

  for code in "${LANGUAGES[@]}"; do options+=("${NAMES[$code]} ($code)"); done
  if command -v gum >/dev/null; then
    for code in $1; do selected+=("${NAMES[$code]} ($code)"); done
    answer=$(IFS=,; gum choose --no-limit --height 20 --header "Languages to install" \
      --selected="${selected[*]}" "${options[@]}")
    sed -n 's/.*(\([a-z]*\))$/\1/p' <<<"$answer"
  else
    printf '%s\n' "${options[@]}" | column >&2
    read -rp "Languages to install, by code [$1]: " answer
    echo "${answer:-$1}"
  fi
}

has() {
  [[ " $languages " == *" $1 "* ]]
}

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

# Print which of the given packages exist in the AUR.
aur_packages() {
  local query
  query=$(printf '&arg[]=%s' "$@")
  curl -fsS "https://aur.archlinux.org/rpc/v5/info?${query#&}" |
    python3 -I -c 'import json, sys; print(*(r["Name"] for r in json.load(sys.stdin)["results"]))'
}

update=false
languages=""
for arg in "$@"; do
  case $arg in
    --update) update=true ;;
    --languages=*) languages=${arg#--languages=} ;;
    *) echo "Usage: ./install.sh [--update] [--languages=en,es,...]" >&2; exit 2 ;;
  esac
done

if [[ ! -f $HYPRLAND_LUA ]]; then
  echo "omarchy-dict needs Hyprland's Lua config, and $HYPRLAND_LUA doesn't exist." >&2
  exit 1
fi

if [[ -z $languages ]]; then
  saved=$(cat "$LANGUAGES_FILE" 2>/dev/null || echo "en es")
  if [[ -t 0 ]]; then
    languages=$(ask_languages "$saved")
  else
    languages=$saved
  fi
fi
picked=" $(tr ',\n' '  ' <<<"$languages") "
for code in $picked; do
  if [[ -z ${NAMES[$code]:-} ]]; then
    echo "Unknown language \"$code\". Choose from: ${LANGUAGES[*]}." >&2
    exit 2
  fi
done
# Always in LANGUAGES order, so results are listed in a stable order.
languages=""
for code in "${LANGUAGES[@]}"; do
  [[ $picked != *" $code "* ]] || languages+="$code "
done
languages=${languages% }
if [[ -z $languages ]]; then
  echo "Choose at least one language." >&2
  exit 2
fi
echo "Installing: $(for code in $languages; do printf '%s, ' "${NAMES[$code]}"; done | sed 's/, $//')"

echo "Installing dictionary packages..."
if command -v omarchy >/dev/null; then
  omarchy pkg add dictd python wl-clipboard
else
  sudo pacman -S --needed --noconfirm dictd python wl-clipboard xdg-terminal-exec
fi

# GCIDE for English, and any prebuilt FreeDict translations between the chosen
# languages. define uses dict.org for the ones that aren't packaged.
wanted=()
has en && wanted+=(dict-gcide)
for from in $languages; do
  for to in $languages; do
    [[ $from == "$to" ]] || wanted+=("dict-freedict-${FREEDICT[$from]}-${FREEDICT[$to]}-bin")
  done
done
read -r -a aur <<<"$(aur_packages "${wanted[@]}" || true)"
if (( ${#aur[@]} )); then
  install_aur "${aur[@]}" ||
    echo "Could not install the offline dictionaries from the AUR; define will use dict.org."
fi

build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
for code in "${LANGUAGES[@]}"; do
  [[ $code == en ]] && continue
  if ! has "$code"; then
    remove_language "$code"
  elif [[ $update == true || ! -f $DICT_DIR/$code-$code.index ]]; then
    install_language "$code"
  fi
done
register_languages

# define reads this, so write it before the first lookup.
mkdir -p "$(dirname "$LANGUAGES_FILE")"
echo "$languages" >"$LANGUAGES_FILE"

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

echo "Done. Press SUPER + ALT + D to look a word up, or SUPER + ALT + W for the selected word."
