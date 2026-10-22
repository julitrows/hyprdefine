# omarchy-dict

Super + Alt + D opens a floating, themed terminal for looking words up with
`dict` on Omarchy or plain Hyprland. It searches every language that has the
word, online through Wiktionary and dict.org, and offers to install the
languages it finds for offline use. Super + Alt + W runs `define --selection`,
which looks up the primary selection (via `wl-paste --primary`) and closes
when its pager does. With nothing selected it falls through to the prompt
loop.

## Layout

- `bin/define`: the lookup command, its prompt loop and the install offer.
  Bash.
- `lib/dictionaries`: installs, removes and updates languages, and runs the
  `define --languages` menu. Bash, no sudo.
- `lib/languages`: the supported languages (reader.dict code, FreeDict code,
  native name), read by everything else.
- `lib/wiktionary.py`: English Wiktionary's English meanings for a word, one
  file per supported language that has it. Standard library only.
- `lib/freedict.py`: finds FreeDict's dictd downloads in its catalogue.
- `lib/reader-dict.py`: converts a reader.dict download into `dictfmt -f`
  input. Standard library only, and works for every language.
- `systemd/omarchy-dict.service`: the user-level `dictd`, linked into
  `~/.config/systemd/user` by `install.sh`.
- `hypr/dictionary.lua`: keybindings and window rule, loaded by a `dofile`
  line that `install.sh` appends to `~/.config/hypr/hyprland.lua`.
- `install.sh` / `uninstall.sh`: idempotent setup and teardown.
- `tests/interactive.py`: drives `define`'s prompt loop in a pseudo-terminal.
- `skills/omarchy-dict/`: end-user Claude Code skill, linked into
  `~/.claude/skills` by `install.sh`.

The installed `~/.local/bin/define` is a symlink to this repo, so edits to
`bin/define` and `lib/` are live immediately. Edits to `hypr/dictionary.lua`
need `hyprctl reload`.

## Languages

Installed languages are listed in `~/.config/omarchy-dict/languages`, and ones
the user said no to in `~/.config/omarchy-dict/declined`. Their dictionaries
live in `~/.local/share/omarchy-dict/dictionaries`: `<code>-<code>` built from
reader.dict, and FreeDict translations `<from>-<to>` (by FreeDict code)
between every pair of installed languages, downloaded from freedict.org and
checked against the catalogue's SHA-512. English has no download; installing
it serves GCIDE from the `dict-gcide` package when that's there.

`lib/dictionaries` writes `~/.local/share/omarchy-dict/dictd.conf` and
restarts `omarchy-dict.service`, a `dictd` on 127.0.0.1:2629. `dictd` won't
start without a database, so the unit has `ConditionFileNotEmpty` and
`lib/dictionaries` stops it when nothing is installed. Installs take a lock,
so a background install and the menu don't clash.

## How lookups work

For one word, `define` queries in parallel:

- each installed language's databases, as `"local remote"` pairs: the local
  server first, and dict.org only when the local server doesn't have that
  database. `dict` exits 0 on a match and 20 or 21 on a miss, and anything
  else (39 is a missing database, 41 no server) means "not available
  locally". Local names differ from dict.org's: `eng-spa` is `fd-eng-spa`.
- English's dict.org dictionaries (GCIDE, WordNet, Moby), installed or not.
- `lib/wiktionary.py`, for every other language.

A language counts as having the word if its dictionaries matched, or, except
for English, if Wiktionary has it. When an installed language has it, only
installed languages are shown in full and the rest go on an "Also in:" line.
Otherwise every language that has it is shown. With more than one shown, each
gets a heading.

In the popup (prompt loop and `--selection`), after the pager closes, `define`
offers to install the languages it showed in full that aren't installed or
declined. Picked ones install in the background (`setsid`, logging to
`~/.local/share/omarchy-dict/install.log`, with a notification when done);
unpicked ones are declined; Esc asks again next time. `OMARCHY_DICT_NO_OFFER=1`
turns the offer off, which the tests do.

## Gotchas

- **Omarchy and plain Hyprland on Arch are both supported.** Only Hyprland's
  Lua config is, not `hyprland.conf`. `hypr/dictionary.lua` picks a `bind`
  helper and window rule by whether Omarchy's `o.bind` exists, then declares
  the keys once; keep the two window rules in step. Read
  `/usr/share/omarchy/` freely but never edit it.
- On Omarchy, launch through `omarchy-launch-tui --app-id=TUI.dictionary`,
  whose `TUI.*` app-id gets Omarchy's terminal styling, and float with the
  `floating-window` tag. On plain Hyprland, launch through
  `xdg-terminal-exec --app-id=TUI.dictionary` and set `float`, `center` and
  `size` directly, matching that tag.
- **Packages**: `install.sh` uses `omarchy pkg` when `omarchy` exists, and
  otherwise `pacman` with `yay` or `paru` for `dict-gcide`.
- **gum 2 toggles with `x` or Tab**, not Space, in `gum choose --no-limit`.
- **Wiktionary**: only English Wiktionary has the definition API (others
  answer 501), so other languages get English meanings until installed.
  Wikimedia wants a descriptive User-Agent. Its English entries for words
  GCIDE and WordNet lack are mostly names, so English ignores them.
- **less prompts**: `--prompt=` treats the first letter as a prompt-type
  selector (`h`, `s`, `m`, `M`, `=`, `w`), and `?`, `%`, `\`, `:` and `.` are
  prompt syntax. Keep the leading `s` and the escaping in `lookup`.
- **Short entries**: in the prompt loop and `--selection`, `less` must not use
  `--quit-if-one-screen`, or the following `clear` (or the window closing)
  wipes the definition. It does use `--clear-screen`, or short entries are
  drawn at the bottom of the window.
- **gum panics without a window size.** Any pty test must set one.
- **reader.dict data**: its DICT.org index isn't sorted the way `dictd`
  searches, and its entries are single lines of HTML, which `dictd` truncates.
  That's why `lib/reader-dict.py` re-renders everything and `dictfmt` builds
  a fresh index (`--utf8 --columns 0`). Don't install the download as is.
- **Background jobs in Bash**: a `$((i++))` in a redirect of a `&` job, or
  inside `$(...)`, runs in a subshell and never increments. Bash regexes have
  no back-references.
- **Earlier versions** kept dictionaries in `/usr/local/share/dictd`,
  registered between `# omarchy-dict begin` and `# omarchy-dict end` in
  `/etc/dict/dictd.conf`. `install.sh` moves them into the user's data
  directory, and `uninstall.sh` cleans up any that are left.
- **Markers**: the `dofile` line ends in `-- omarchy-dict`. Use `grep -e` for
  patterns that start with `-`.
- **Never commit dictionary data.** It's Wiktionary and FreeDict content
  downloaded at run time.

## Testing

```bash
bash -n bin/define lib/dictionaries install.sh uninstall.sh
luac -p hypr/dictionary.lua
define house; define casa; define --es casa # one-shot lookups
python3 -I tests/interactive.py house casa serendipity etc.
python3 -I tests/interactive.py --es casa ñandú
hyprctl reload && hyprctl configerrors      # after Lua changes
```

To try languages without touching the user's, run `lib/dictionaries` with
`HOME` and `XDG_CONFIG_HOME` pointed at a scratch directory and stand-in
`systemctl` and `notify-send` on `PATH`, then serve the scratch
`dictd.conf` on port 2629 yourself. `install.sh` and `uninstall.sh` need
`sudo`, so ask the user to run them in their own terminal rather than running
them yourself.
