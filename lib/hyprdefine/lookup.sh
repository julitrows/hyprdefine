# Looking words up: the one-shot lookup, the popup's prompt loop, and the offer
# to install languages afterwards.
#
# A lookup has three steps:
#
#   gather  query every source in parallel, one output file per language
#   choose  decide which languages to show in full, list as "Also in", and
#           offer to install
#   render  print the chosen languages, under a heading each when there are
#           several
#
# Installed languages come from the local dictd (with dict.org standing in for
# databases it doesn't have), English from dict.org's GCIDE, WordNet and Moby,
# and every other language from English Wiktionary.

WIKTIONARY=("python3" "-I" "$LIB/wiktionary.py")
INSTALL_LOG="$DATA/install.log"

# A language's databases, as "local remote" pairs: the local dictd server is
# used when it has the database, and dict.org when it doesn't. A "-" means
# there is no such database on that side. Installed languages also get
# translations to every other installed language.
databases_for() {
  local code=$1 other

  if [[ $code == en ]]; then
    printf '%s\n' "gcide gcide" "- wn" "- moby-thesaurus"
  else
    echo "$code-$code -"
  fi
  contains "$code" "${installed[@]}" || return 0
  for other in "${installed[@]}"; do
    [[ $other == "$code" ]] && continue
    echo "${FREEDICT[$code]}-${FREEDICT[$other]} fd-${FREEDICT[$code]}-${FREEDICT[$other]}"
  done
}

# Print a database's definitions without dict's "N definitions found" banner.
query() {
  local server=(-h dict.org)
  [[ $1 == local ]] && server=(-h localhost -p "$PORT")
  dict "${server[@]}" -d "$2" -- "$3" 2>/dev/null | sed '1{/definitions\? found$/{N;d}}'
  return "${PIPESTATUS[0]}"
}

search() {
  local local_db remote_db status=39
  read -r local_db remote_db <<<"$1"

  if [[ $local_db != - ]]; then
    query local "$local_db" "$2"
    status=$?
  fi

  # 0 is a match and 20/21 a miss; anything else (39 a missing database, 41
  # no server) means the local server can't answer, so ask dict.org.
  if (( status != 0 && status != 20 && status != 21 )) && [[ $remote_db != - ]]; then
    query remote "$remote_db" "$2"
  fi
}

# The languages a lookup covers: all of them, or the one named with --<code>.
searched() {
  if [[ -n $only ]]; then echo "$only"; else echo "${LANGUAGES[@]}"; fi
}

# Letters that may carry marks, and the marked forms each stands for.
ACCENTS=(a áàâäãåāăą c çčć d ď e éèêëēěę g ğ i íìîïīı l ł n ñńň o óòôöõøōő
  r ř s śšşș t ťţț u úùûüūůű y ýÿ z źżž)

# A POSIX regex matching the word with or without marks on its letters:
# "arbol" and "árbol" both give ^[aáàâäãåāăą]rb[oóòôöõøōő]l$.
accent_pattern() {
  local LC_ALL=C.UTF-8 word=${1,,} pattern="" char base i k
  for (( i = 0; i < ${#word}; i++ )); do
    char=${word:i:1}
    base=""
    for (( k = 0; k < ${#ACCENTS[@]}; k += 2 )); do
      if [[ $char == "${ACCENTS[k]}" || ${ACCENTS[k + 1]} == *"$char"* ]]; then
        base=${ACCENTS[k]}
        break
      fi
    done
    if [[ -n $base ]]; then
      pattern+="[$base${ACCENTS[k + 1]}]"
    elif [[ $char == [][.\\^\$*+?\(\){}\|] ]]; then
      pattern+="\\$char"
    else
      pattern+=$char
    fi
  done
  echo "^$pattern\$"
}

# Up to three headwords in a local database that are the word with different
# marks, such as "tropelía" for "tropelia".
accented() {
  local word=$2
  dict -h localhost -p "$PORT" -d "$1" -f -m -s re -- "$(accent_pattern "$word")" 2>/dev/null |
    cut -f4 | awk -v word="$word" 'NF && tolower($0) != tolower(word)' | head -n3
}

# Search all of a language's databases for a word in the background, one
# numbered file each. i is gather's: incrementing it here, in the main shell,
# keeps the numbers going (an increment in the job's redirect would be lost in
# a subshell).
queue() {
  local code=$1 word=$2 database file
  while read -r database; do
    printf -v file '%s/%s/%03d' "$work" "$code" "$i"
    i=$((i + 1))
    search "$database" "$word" >"$file" </dev/null &
  done < <(databases_for "$code")
}

# Query every source at once, then leave each language's result in
# $work/<code>.out. Only English and installed languages have dictionaries to
# query; the rest come from Wiktionary. An installed language that misses the
# word is searched again for it with other marks, so "tropelia" finds
# "tropelía".
gather() {
  local word=$1 code database variant file i=0

  mkdir "$work/wiktionary"
  "${WIKTIONARY[@]}" "$word" "$LIB/languages" "$work/wiktionary" 2>/dev/null &

  for code in $(searched); do
    [[ $code == en ]] || contains "$code" "${installed[@]}" || continue
    mkdir "$work/$code"
    queue "$code" "$word"
  done
  wait

  for code in $(searched); do
    contains "$code" "${installed[@]}" && [[ -d $work/$code ]] || continue
    found_in "$code" && continue
    read -r database _ < <(databases_for "$code")
    [[ $database != - ]] || continue
    while read -r variant; do
      queue "$code" "$variant"
    done < <(accented "$database" "$word")
  done
  wait

  for code in $(searched); do
    if [[ -d $work/$code ]]; then
      for file in "$work/$code"/*; do
        [[ -s $file ]] && cat "$file" && echo
      done >"$work/$code.out"
    fi
    # English Wiktionary's English entries for words GCIDE and WordNet lack
    # are mostly names, so English only counts through its dictionaries.
    if [[ ! -s $work/$code.out && $code != en && -f $work/wiktionary/$code ]]; then
      mv "$work/wiktionary/$code" "$work/$code.out"
    fi
  done
}

# Whether any of a language's searches so far found something.
found_in() {
  local file
  for file in "$work/$1"/*; do
    [[ -s $file ]] && return 0
  done
  return 1
}

# Set shown, also and offer from what gather found. When an installed language
# has the word, only installed languages are shown and the rest are "also in";
# otherwise everything found is shown. Offer the shown languages that aren't
# installed or declined.
choose() {
  local code found=() yours=()
  shown=()
  also=()
  offer=()

  for code in $(searched); do
    [[ -s $work/$code.out ]] || continue
    found+=("$code")
    if contains "$code" "${installed[@]}"; then yours+=("$code"); fi
  done

  if [[ -n $only || ${#yours[@]} -eq 0 ]]; then
    shown=("${found[@]}")
  else
    shown=("${yours[@]}")
    for code in "${found[@]}"; do
      contains "$code" "${yours[@]}" || also+=("$code")
    done
  fi

  for code in "${shown[@]}"; do
    contains "$code" "${installed[@]}" "${declined[@]}" || offer+=("$code")
  done
}

render() {
  local code
  for code in "${shown[@]}"; do
    if (( ${#shown[@]} > 1 )); then
      printf '%s\n%s\n\n' "${NAME[$code]}" "${NAME[$code]//?/═}"
    fi
    cat "$work/$code.out"
  done
  if (( ${#also[@]} )); then
    echo "Also in: $(names "${also[@]}")"
  fi
}

# Spelling suggestions from the local server, or WordNet when it's not there.
suggest() {
  dict -h localhost -p "$PORT" -m -s lev -- "$1" 2>/dev/null ||
    dict -h dict.org -d wn -m -s lev -- "$1" 2>/dev/null
}

# Look a word up and show it in less. Leaves offer set for offer_install.
lookup() {
  local word=$1 work found suggestions

  work=$(mktemp -d)
  gather "$word"
  choose
  found=$(render)
  rm -r "$work"

  if [[ -z $found ]]; then
    found="No definitions found for \"$word\""
    if suggestions=$(suggest "$word"); then
      found+=$'\n\nPerhaps you mean:\n'"$suggestions"
    fi
  fi

  # The leading "s" picks less's short prompt, and the escapes keep prompt
  # syntax such as "?" and "." in the word literal.
  less "${pager[@]}" --prompt="s$(sed 's/[?%\\:.]/\\&/g' <<<"$word") (q to $leave)" <<<"$found"
}

# Offer to install the languages in offer. Picked ones install in the
# background; the rest are declined. Esc (gum's non-zero exit) asks again next
# time. HYPRDEFINE_NO_OFFER turns this off, for tests.
offer_install() {
  local code picked names=() install=() decline=()
  (( ${#offer[@]} )) && [[ -t 0 && -z ${HYPRDEFINE_NO_OFFER:-} ]] || return 0

  for code in "${offer[@]}"; do names+=("${NAME[$code]}"); done
  clear
  if command -v gum >/dev/null; then
    # gum 2 toggles with x or Tab, not Space.
    picked=$(gum choose --no-limit --header "Install for offline lookups and definitions in their own language?
x picks, Enter confirms. Languages you don't pick won't be offered again." "${names[@]}") || return 0
  else
    read -rp "Install $(names "${offer[@]}") for offline lookups? [y/N] " picked
    if [[ $picked == [yY]* ]]; then picked=$(printf '%s\n' "${names[@]}"); else picked=""; fi
  fi

  for code in "${offer[@]}"; do
    if grep -qxF -e "${NAME[$code]}" <<<"$picked"; then install+=("$code"); else decline+=("$code"); fi
  done

  if (( ${#decline[@]} )); then
    "$SELF" --decline "${decline[@]}"
  fi
  if (( ${#install[@]} )); then
    mkdir -p "$DATA"
    setsid -f "$SELF" --install --notify "${install[@]}" >>"$INSTALL_LOG" 2>&1 </dev/null
    echo "Installing $(names "${install[@]}") in the background. A notification will say when it's ready."
    sleep 2
  fi
  # Don't offer them again in this session, whatever the answer.
  declined+=("${offer[@]}")
}

# The primary selection's first line, without surrounding punctuation or space.
selected() {
  wl-paste --primary --no-newline 2>/dev/null | head -n1 |
    sed 's/^[^[:alnum:]]*//; s/[^[:alnum:]]*$//'
}

ask() {
  local prompt="Define: " placeholder="Word to define (Enter on empty to quit, :languages to manage)" word

  if command -v gum >/dev/null; then
    gum input --placeholder "$placeholder" --prompt "$prompt"
  else
    read -rp "$prompt" word && echo "$word"
  fi
}

# Usage: run_lookup [--<code>] [--selection] [word...]
run_lookup() {
  local selection=false word
  only=""
  while [[ ${1:-} == --* ]]; do
    case $1 in
      --selection) selection=true ;;
      *)
        if [[ -z ${NAME[${1#--}]:-} ]]; then
          echo "hyprdefine: unknown option $1 (see hyprdefine --help)" >&2
          exit 2
        fi
        only=${1#--}
        ;;
    esac
    shift
  done
  load_state

  if (( $# > 0 )); then
    pager=(--quit-if-one-screen)
    leave=quit
    lookup "$*"
    return
  fi

  # Keep the pager open even for short entries, or the clear that follows
  # wipes them; and clear the screen first, so short entries are drawn from
  # the top rather than scrolled up from the bottom, without "~" filler.
  pager=(--clear-screen --tilde)
  leave="go back"

  if [[ $selection == true ]] && word=$(selected) && [[ -n $word ]]; then
    leave=close
    lookup "$word"
    offer_install
    return
  fi

  while word=$(ask) && [[ -n $word ]]; do
    clear
    if [[ $word == :languages ]]; then
      "$SELF" --languages
      load_state
    else
      lookup "$word"
      offer_install
    fi
    clear
  done
}
