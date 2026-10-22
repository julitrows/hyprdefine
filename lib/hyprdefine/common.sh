# Shared by everything bin/hyprdefine sources: paths, the language catalogue
# and the user's language state. Expects LIB to be set.

# hyprdefine's install root: the repo in a git checkout, /usr when packaged.
ROOT="$(dirname "$(dirname "$LIB")")"
SELF="$ROOT/bin/hyprdefine"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hyprdefine"
# Fixed rather than XDG_DATA_HOME, because the systemd unit names it with %h.
DATA="$HOME/.local/share/hyprdefine"
DICTS="$DATA/dictionaries"
SERVICE=hyprdefine.service
# The user-level dictd, from lib/systemd/user/hyprdefine.service. Tests point
# HYPRDEFINE_PORT at a server of their own.
PORT=${HYPRDEFINE_PORT:-2629}

# The supported languages, in lib/hyprdefine/languages order, with their
# FreeDict codes and their own names for themselves.
LANGUAGES=()
declare -A FREEDICT NAME
while read -r code freedict name; do
  [[ -z $code || $code == \#* ]] && continue
  LANGUAGES+=("$code")
  FREEDICT[$code]=$freedict
  NAME[$code]=$name
done <"$LIB/languages"

# Read the installed and declined languages into arrays of the same name.
load_state() {
  installed=()
  declined=()
  # read fails on an empty or missing file, which just means none.
  read -r -a installed 2>/dev/null <"$CONFIG/languages" || true
  read -r -a declined 2>/dev/null <"$CONFIG/declined" || true
}

# Whether the first argument is one of the rest.
contains() {
  local item=$1
  shift
  [[ " $* " == *" $item "* ]]
}

# The languages' own names, comma-separated.
names() {
  local code list=()
  for code; do list+=("${NAME[$code]}"); done
  local IFS=,
  echo "${list[*]}" | sed 's/,/, /g'
}
