# Installing, removing and updating languages, and the --languages menu.
#
# Dictionaries live in ~/.local/share/hyprdefine/dictionaries and are served by
# a user-level dictd (hyprdefine.service), so none of this needs sudo:
#
#   <code>-<code>   a language's own Wiktionary, built from reader.dict
#   <from>-<to>     FreeDict translations, by FreeDict code, between every pair
#                   of installed languages
#
# English has no download: it's served from the dict-gcide package when that's
# installed, and from dict.org otherwise. The URLs can be pointed elsewhere for
# tests.

READER_URL=${HYPRDEFINE_READER_URL:-https://www.reader-dict.com/file}
FREEDICT_URL=${HYPRDEFINE_FREEDICT_URL:-https://freedict.org/freedict-database.json}
GCIDE=${HYPRDEFINE_GCIDE:-/usr/share/dictd/gcide}

# Save codes to a state file, in catalogue order and without duplicates.
save_state() {
  local file=$1 code
  shift
  mkdir -p "$CONFIG"
  for code in "${LANGUAGES[@]}"; do
    if contains "$code" "$@"; then printf '%s ' "$code"; fi
  done | xargs >"$CONFIG/$file"
}

check_codes() {
  local code
  if (( $# == 0 )); then
    echo "Name at least one language: ${LANGUAGES[*]}." >&2
    exit 2
  fi
  for code; do
    if [[ -z ${NAME[$code]:-} ]]; then
      echo "Unknown language \"$code\". Choose from: ${LANGUAGES[*]}." >&2
      exit 2
    fi
  done
}

# Download reader.dict's dictionary for a language and build it as
# <code>-<code>. See reader-dict.py for why it can't be used as downloaded.
build_language() {
  local code=$1 dir
  dir=$(mktemp -d)

  echo "Downloading the ${NAME[$code]} dictionary..."
  curl -fL --progress-bar -o "$dir/download.zip" "$READER_URL/$code/dictorg-$code-$code-noetym.zip"

  echo "Building the ${NAME[$code]} dictionary..."
  python3 -I "$LIB/reader-dict.py" "$dir/download.zip" |
    dictfmt -f --utf8 --quiet --columns 0 \
      -u https://www.reader-dict.com -s "${NAME[$code]} (Wiktionary, reader.dict)" \
      "$dir/$code-$code"
  dictzip "$dir/$code-$code.dict"
  mkdir -p "$DICTS"
  mv "$dir/$code-$code.dict.dz" "$dir/$code-$code.index" "$DICTS/"
  rm -rf "$dir"
}

# FreeDict's catalogue, downloaded when missing, a week old, or with --refresh.
catalogue() {
  local file="$DATA/freedict.json"
  if [[ ${1:-} == --refresh || ! -s $file || -n $(find "$file" -mtime +7) ]]; then
    curl -fsSL -o "$file.new" "$FREEDICT_URL" && mv "$file.new" "$file"
  fi
  echo "$file"
}

# Download one FreeDict release into $DICTS, checking it against the
# catalogue's SHA-512. A failure skips that pair: define then uses dict.org.
fetch_translation() {
  local name=$1 url=$2 checksum=$3 dir
  dir=$(mktemp -d)

  echo "Downloading the $name translations..."
  if ! curl -fsSL -o "$dir/release.tar.xz" "$url"; then
    echo "Couldn't download the $name translations; skipping them." >&2
  elif ! sha512sum --quiet -c <<<"$checksum  $dir/release.tar.xz"; then
    echo "The $name download doesn't match its checksum; skipping it." >&2
  else
    tar -xJf "$dir/release.tar.xz" -C "$dir"
    mkdir -p "$DICTS"
    mv "$dir/$name/$name.dict.dz" "$dir/$name/$name.index" "$DICTS/"
  fi
  rm -rf "$dir"
}

# Make the translations match the installed languages: download the pairs that
# are missing (or all of them with --refresh), and delete the ones whose
# languages aren't both installed any more.
sync_translations() {
  local from to pair file name url checksum wanted=() missing=()
  load_state

  for from in "${installed[@]}"; do
    for to in "${installed[@]}"; do
      [[ $from == "$to" ]] && continue
      pair="${FREEDICT[$from]}-${FREEDICT[$to]}"
      wanted+=("$pair")
      if [[ ${1:-} == --refresh || ! -f $DICTS/$pair.index ]]; then missing+=("$pair"); fi
    done
  done

  for file in "$DICTS"/*.index; do
    [[ -e $file ]] || continue
    pair=$(basename "$file" .index)
    # Leave the languages' own dictionaries, named <code>-<code>.
    [[ $pair == "${pair%%-*}-${pair%%-*}" ]] && continue
    contains "$pair" "${wanted[@]}" || rm -f "$DICTS/$pair.index" "$DICTS/$pair.dict.dz"
  done

  (( ${#missing[@]} )) || return 0
  python3 -I "$LIB/freedict.py" "$(catalogue "$@")" "${missing[@]}" >"$DATA/releases"
  while read -r name url checksum; do
    fetch_translation "$name" "$url" "$checksum"
  done <"$DATA/releases"
  rm -f "$DATA/releases"
}

# Point dictd at every installed dictionary and restart it, or stop it when
# there's nothing to serve, because dictd won't start without a database.
serve() {
  local file conf="$DATA/dictd.conf"
  load_state
  mkdir -p "$DATA"

  {
    if contains en "${installed[@]}" && [[ -f $GCIDE.index ]]; then
      printf 'database gcide { data "%s.dict.dz" index "%s.index" }\n' "$GCIDE" "$GCIDE"
    fi
    for file in "$DICTS"/*.index; do
      [[ -e $file ]] || continue
      printf 'database %s { data "%s" index "%s" }\n' \
        "$(basename "$file" .index)" "${file%.index}.dict.dz" "$file"
    done
  } >"$conf"

  if [[ -s $conf ]]; then
    systemctl --user restart "$SERVICE"
  else
    systemctl --user stop "$SERVICE"
  fi
}

# Usage: install_languages [--notify] <code>...
# With --notify, as when define installs in the background, a desktop
# notification says how it went.
install_languages() {
  local notify=false code failed
  if [[ ${1:-} == --notify ]]; then
    notify=true
    shift
  fi
  check_codes "$@"
  if [[ $notify == true ]]; then
    failed="Couldn't install $(names "$@"). See $DATA/install.log."
    trap 'notify-send -u critical Dictionary "$failed" || true' ERR
  fi

  for code; do
    if [[ $code != en && ! -f $DICTS/$code-$code.index ]]; then
      build_language "$code"
    fi
  done
  load_state
  save_state languages "${installed[@]}" "$@"
  sync_translations
  serve

  echo "Installed $(names "$@")."
  if [[ $notify == true ]]; then
    notify-send Dictionary "$(names "$@") installed for offline lookups." || true
  fi
}

remove_languages() {
  local code keep=()
  check_codes "$@"
  load_state

  for code in "${installed[@]}"; do
    contains "$code" "$@" || keep+=("$code")
  done
  save_state languages "${keep[@]}"
  for code; do
    rm -f "$DICTS/$code-$code.dict.dz" "$DICTS/$code-$code.index"
  done
  sync_translations
  serve
  echo "Removed $(names "$@")."
}

update_languages() {
  local code
  load_state
  for code in "${installed[@]}"; do
    [[ $code == en ]] || build_language "$code"
  done
  sync_translations --refresh
  serve
}

# Stop offering languages after a lookup.
decline_languages() {
  check_codes "$@"
  load_state
  save_state declined "${declined[@]}" "$@"
}

# Pick languages with gum from the given codes, and print the chosen codes.
pick() {
  local header=$1 code options=()
  shift
  for code; do options+=("${NAME[$code]} ($code)"); done
  gum choose --no-limit --height 20 --header "$header" "${options[@]}" |
    sed -n 's/.*(\([a-z]*\))$/\1/p'
}

# The --languages menu. Each change runs as its own hyprdefine process, so a
# failure is reported and the menu carries on.
manage_languages() {
  local action code picked available size

  while true; do
    load_state
    available=()
    for code in "${LANGUAGES[@]}"; do
      contains "$code" "${installed[@]}" || available+=("$code")
    done
    size=$(du -sh "$DICTS" 2>/dev/null | cut -f1)

    clear
    echo "Installed: $(names "${installed[@]}" | grep . || echo none) (${size:-0})"
    echo "Not offered again: $(names "${declined[@]}" | grep . || echo none)"
    echo
    action=$(gum choose --header "Dictionary languages" \
      "Add languages" "Remove languages" "Update all" "Offer every language again" "Done") || return 0

    case $action in
      "Add languages")
        picked=$(pick "Languages to add (x picks, Enter confirms)" "${available[@]}") || continue
        [[ -z $picked ]] || "$SELF" --install $picked || true
        ;;
      "Remove languages")
        (( ${#installed[@]} )) || continue
        picked=$(pick "Languages to remove (x picks, Enter confirms)" "${installed[@]}") || continue
        [[ -z $picked ]] || "$SELF" --remove $picked || true
        ;;
      "Update all") "$SELF" --update || true ;;
      "Offer every language again") : >"$CONFIG/declined" ;;
      *) return 0 ;;
    esac
    gum input --placeholder "Press Enter to continue" >/dev/null || true
  done
}
