# hyprdefine --setup and --teardown: everything per user that a package can't
# do, because pacman runs as root. Safe to run more than once.

HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
MARKER="-- hyprdefine"
USER_UNITS="$HOME/.config/systemd/user"
UNIT="$ROOT/lib/systemd/user/$SERVICE"
BIN="$HOME/.local/bin"
SKILLS="$HOME/.claude/skills"

# Link target to link_name, unless link_name is something else's.
link() {
  local target=$1 link_name=$2
  if [[ -e $link_name || -L $link_name ]] && ! ours "$link_name"; then
    echo "Leaving $link_name alone; it isn't hyprdefine's." >&2
    return 0
  fi
  mkdir -p "$(dirname "$link_name")"
  ln -sfn "$target" "$link_name"
}

# Whether a path is a link into this install, or into an omarchy-dict
# checkout, hyprdefine's earlier name.
ours() {
  [[ -L $1 ]] || return 1
  local target
  target=$(readlink "$1")
  [[ $target == "$ROOT"/* || $target == */omarchy-dict/* ]]
}

unlink_ours() {
  if ours "$1"; then rm "$1"; fi
}

# Move an omarchy-dict install over: its state, dictionaries, service,
# keybindings line and links.
migrate() {
  local old_config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-dict"
  local old_data="$HOME/.local/share/omarchy-dict"

  if [[ -d $old_config && ! -e $CONFIG ]]; then
    echo "Moving $old_config to $CONFIG..."
    mv "$old_config" "$CONFIG"
  fi
  if [[ -d $old_data && ! -e $DATA ]]; then
    echo "Moving $old_data to $DATA..."
    mv "$old_data" "$DATA"
    # Its dictd.conf names the old directory; serve writes a fresh one.
    rm -f "$DATA/dictd.conf"
  fi
  if [[ -L $USER_UNITS/omarchy-dict.service ]]; then
    systemctl --user disable --now omarchy-dict.service >/dev/null 2>&1 || true
    # disable removes a linked unit itself, so it may already be gone.
    rm -f "$USER_UNITS/omarchy-dict.service"
  fi
  if [[ -f $HYPRLAND_LUA ]]; then
    sed -i '/-- omarchy-dict$/d' "$HYPRLAND_LUA"
  fi
  unlink_ours "$SKILLS/omarchy-dict"
}

hyprland_line() {
  printf 'loadfile("%s")("%s") %s\n' "$ROOT/share/hyprdefine/hyprland.lua" "$SELF" "$MARKER"
}

setup() {
  if [[ ! -f $HYPRLAND_LUA ]]; then
    echo "hyprdefine needs Hyprland's Lua config, and $HYPRLAND_LUA doesn't exist." >&2
    exit 1
  fi

  migrate

  echo "Setting up the dictionary server..."
  # A package installs the unit system-wide; a git checkout links its own.
  if [[ $UNIT != /usr/* ]]; then
    link "$UNIT" "$USER_UNITS/$SERVICE"
  fi
  systemctl --user daemon-reload
  systemctl --user enable "$SERVICE"
  if [[ -s $CONFIG/languages ]]; then
    "$SELF" --serve
  fi

  # `define` is the short name for lookups, kept from before the rename.
  link "$SELF" "$BIN/define"
  if [[ -d $HOME/.claude ]]; then
    link "$ROOT/share/hyprdefine/skill" "$SKILLS/hyprdefine"
  fi

  # Replace the line rather than skip it, so it follows the install's paths.
  sed -i "/$MARKER\$/d" "$HYPRLAND_LUA"
  # No blank line before it, so --teardown's one-line delete leaves the file as
  # it was. Only add a newline if the file doesn't end with one.
  [[ -z $(tail -c1 "$HYPRLAND_LUA") ]] || echo >>"$HYPRLAND_LUA"
  hyprland_line >>"$HYPRLAND_LUA"
  reload_hyprland

  echo "Done. Press SUPER + ALT + D to look a word up, or SUPER + ALT + W for the selected word."
  echo "Languages are offered as you use them; run 'hyprdefine --languages' to manage them."
}

teardown() {
  systemctl --user disable --now "$SERVICE" >/dev/null 2>&1 || true
  unlink_ours "$USER_UNITS/$SERVICE"
  systemctl --user daemon-reload

  unlink_ours "$BIN/define"
  unlink_ours "$SKILLS/hyprdefine"
  rm -rf "$DATA" "$CONFIG"
  if [[ -f $HYPRLAND_LUA ]]; then
    sed -i "/$MARKER\$/d" "$HYPRLAND_LUA"
  fi
  reload_hyprland

  echo "Removed hyprdefine's keybindings, dictionary server and dictionaries."
}

# hyprctl fails outside a Hyprland session, such as over SSH; the change then
# applies at the next login.
reload_hyprland() {
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload >/dev/null
    hyprctl configerrors
  fi
}
