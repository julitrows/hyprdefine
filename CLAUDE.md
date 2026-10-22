# hyprdefine

A floating dictionary popup for Hyprland (themed on Omarchy). Super + Alt + D
opens a prompt; Super + Alt + W looks up the selection. Each lookup searches
every language that has the word (installed ones on a user-level `dictd`,
English on dict.org, the rest through English Wiktionary's API) and then
offers to install the languages it showed. Formerly omarchy-dict.

Read [docs/architecture.md](docs/architecture.md) first: it has the diagrams
and the reasoning. This file is the short version plus the pitfalls.

## Layout

The repo mirrors the installed layout, so `make install` is a plain copy and
`bin/hyprdefine` finds everything relative to its own real path:

- `bin/hyprdefine`: the only executable. Dispatches on its first option and
  sources what that job needs.
- `lib/hyprdefine/common.sh`: paths, the language catalogue, state helpers.
- `lib/hyprdefine/lookup.sh`: lookups (`gather`, `choose`, `render`), the
  prompt loop and the install offer. Runs without `set -e`.
- `lib/hyprdefine/dictionaries.sh`: `--install`, `--remove`, `--update`,
  `--decline`, `--serve` and the `--languages` menu. Runs under
  `set -eEuo pipefail`.
- `lib/hyprdefine/setup.sh`: `--setup` and `--teardown`, everything per user.
- `lib/hyprdefine/languages`: the 26 languages (reader.dict code, FreeDict
  code, own name). The only list of languages; everything reads it.
- `lib/hyprdefine/{wiktionary,freedict,reader-dict}.py`: standard-library
  helpers.
- `lib/systemd/user/hyprdefine.service`: the user-level `dictd` on
  127.0.0.1:2629.
- `share/hyprdefine/hyprland.lua`: the keys and window rule.
- `share/hyprdefine/skill/`: the end-user Claude Code skill.
- `packaging/`: the AUR PKGBUILD and install script (see docs/packaging.md).
- `tests/`: `make test`.

In this checkout, `~/.local/bin/hyprdefine` and `define` link here, so edits
are live immediately; edits to `hyprland.lua` need `hyprctl reload`.

## Rules

- **No sudo outside `install.sh`.** Languages live in
  `~/.local/share/hyprdefine` so the popup can install them in the background.
- **`lib/hyprdefine/languages` is the only list of languages.** Nothing else
  names one, apart from English's own databases (`gcide`, `wn`,
  `moby-thesaurus`).
- **Local first.** dict.org is only asked when the local server can't answer
  (exit 39 or 41), never on a miss (20 or 21).
- **Never write over something that isn't ours.** `setup.sh`'s `link` and
  `ours` decide; keep using them.
- **Read `/usr/share/omarchy/` freely, never edit it.** `hyprland.lua` uses
  Omarchy's `o.bind`/`o.window` when they exist and raw `hl.*` otherwise; keep
  both branches' window rules in step.
- **Never commit dictionary data**: it's Wiktionary and FreeDict content.

## Pitfalls already hit

- **`dictfmt -f` swallows the first two headwords** as database info, so
  `reader-dict.py` writes two header lines first.
- **`read` returns 1 on an empty file**, which ends a `set -e` script; see
  `load_state`.
- **Counters in background jobs**: `$((i++))` in the redirect of a `&` job, or
  inside `$(...)`, runs in a subshell and never increments.
- **Bash regexes have no back-references.**
- **`systemctl --user disable` deletes a linked unit file itself.**
- **`set -e` is off inside `$(...)` and in an `if`/`||` condition**, so
  functions called there don't stop on errors.
- **gum 2 toggles with `x` or Tab**, not Space, in `gum choose --no-limit`.
  **gum panics without a window size**, so pty tests set one.
- **Wiktionary**: only English Wiktionary has the definition API (others
  return 501). Its English entries for words GCIDE and WordNet lack are
  mostly names, so English ignores them. Send a descriptive User-Agent.
- **`dictd` won't start without a database**: the unit has
  `ConditionFileNotEmpty`, and `serve` stops it when nothing is installed.
- **less prompts**: `--prompt=` treats the first letter as a prompt-type
  selector, and `?`, `%`, `\`, `:` and `.` are prompt syntax. Keep the leading
  `s` and the escaping in `lookup`.
- **Short entries**: in the popup, `less` must not use
  `--quit-if-one-screen` (the following `clear` or the window closing wipes
  the entry), and does use `--clear-screen` (or short entries sit at the
  bottom).
- **The user's shell may export `XDG_CONFIG_HOME`.** When pointing `HOME` at
  a scratch directory by hand, unset or override it too, or you'll read the
  real config. The test sandbox builds its environment from scratch.

## Testing

```bash
make check    # bash -n, luac -p, Python syntax
make test     # everything, offline, ~30 s
python3 -I -m unittest discover -s tests -p 'test_lookup.py'   # one file
```

The tests never touch the network, the user's home or their server: see
`tests/support.py`. Add a test with every behaviour change. `install.sh`,
`uninstall.sh` and anything with `sudo` are for the user to run in their own
terminal; `hyprdefine --setup` doesn't need `sudo`.
