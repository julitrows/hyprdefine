# omarchy-dict

Super + Alt + D opens a floating, themed terminal for looking words up with
`dict` on Omarchy or plain Hyprland, in every language the user installed at
once. Super + Alt + W runs `define --selection`, which looks up the primary
selection (via `wl-paste --primary`) and closes when its pager does. With
nothing selected it falls through to the prompt loop.

## Layout

- `bin/define`: the lookup command and its prompt loop. Bash.
- `hypr/dictionary.lua`: keybindings and window rule, loaded by a `dofile`
  line that `install.sh` appends to `~/.config/hypr/hyprland.lua`.
- `lib/languages`: the supported languages (reader.dict code, FreeDict code,
  native name), read by `install.sh`, `uninstall.sh` and `define`.
- `lib/reader-dict.py`: converts a reader.dict download into `dictfmt -f`
  input. Standard library only, and works for every language.
- `install.sh` / `uninstall.sh`: idempotent setup and teardown.
- `tests/interactive.py`: drives `define`'s prompt loop in a pseudo-terminal.
- `skills/omarchy-dict/`: end-user Claude Code skill, linked into
  `~/.claude/skills` by `install.sh`.

The installed `~/.local/bin/define` is a symlink to this repo, so edits to
`bin/define` are live immediately. Edits to `hypr/dictionary.lua` need
`hyprctl reload`.

## Languages

`install.sh` asks for the languages (or takes `--languages=en,fr`) and saves
their codes, in `lib/languages` order, to `~/.config/omarchy-dict/languages`.
A missing file means English and Spanish, the only languages before this
existed. `define` reads it and searches every language at once, or one with
`--<code>`; the keybindings don't depend on it.

For each language, `define` searches its definitions (GCIDE, WordNet and Moby
for English, the reader.dict build `<code>-<code>` for the rest) and a FreeDict
translation database to every other installed language, `<from>-<to>` by
FreeDict code. Results are grouped under a heading per language when more than
one matched. A pair FreeDict doesn't have just finds nothing.

`install.sh` installs a `dict-freedict-<from>-<to>-bin` AUR package for each
pair that has one, checked through the AUR RPC; the rest come from dict.org.

## How lookups work

`define` searches databases as `"local remote"` pairs: the local `dictd`
server first, and dict.org only when the local server doesn't have that
database. `dict` exits 0 on a match and 20 or 21 on a miss, and anything else
(39 is a missing database) means "not available locally". Databases are
queried in parallel and printed in order.

Local database names differ from dict.org's: `eng-spa` locally is `fd-eng-spa`
on dict.org.

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
  otherwise `pacman` with `yay` or `paru` for the AUR packages.
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
- **Markers**: the `dofile` line ends in `-- omarchy-dict`, and the `dictd.conf`
  block sits between `# omarchy-dict begin` and `# omarchy-dict end`.
  `install.sh` rewrites the whole block every run, from the chosen languages. Use
  `grep -e` for patterns that start with `-`.
- **Never commit dictionary data.** It's Wiktionary content (CC BY-SA)
  downloaded at install time.

## Testing

```bash
bash -n bin/define install.sh uninstall.sh
luac -p hypr/dictionary.lua
define house; define --es casa              # one-shot lookups
python3 -I tests/interactive.py house casa serendipity etc.
python3 -I tests/interactive.py --es casa ñandú
hyprctl reload && hyprctl configerrors      # after Lua changes
```

`install.sh` and `uninstall.sh` need `sudo`, so ask the user to run them in
their own terminal rather than running them yourself.
