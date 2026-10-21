# omarchy-dict

A dictionary on a keystroke for [Omarchy](https://omarchy.org/). Press
**Super + Alt + D**, type a word and read its definition in a floating terminal
that follows your theme. **Super + Shift + Alt + D** does the same in Spanish.

| Lookup  | Definitions                                    | Translations       |
| ------- | ---------------------------------------------- | ------------------ |
| English | Webster's 1913 (GCIDE), WordNet, Moby thesaurus | English → Spanish |
| Spanish | Spanish Wiktionary                             | Spanish → English  |

Everything runs through [`dict`](https://github.com/cheusov/dictd) and a local
`dictd` server. WordNet and the thesaurus come from dict.org, as do any
dictionaries that aren't installed locally, so lookups work offline and get
richer online.

## Install

```bash
git clone https://github.com/julitrows/omarchy-dict.git ~/code/omarchy-dict
cd ~/code/omarchy-dict
./install.sh
```

The installer:

- installs `dictd`, `dict-gcide`, `dict-freedict-eng-spa-bin` and
  `dict-freedict-spa-eng-bin` (AUR) and enables the local `dictd` server
- downloads the Spanish dictionary from reader.dict, converts it to plain text
  and installs it to `/usr/local/share/dictd`, registered as `es-es` in
  `/etc/dict/dictd.conf`
- links `bin/define` to `~/.local/bin/define`
- links the Claude Code skill into `~/.claude/skills`, if you use Claude Code
- appends a `dofile(...)` line to `~/.config/hypr/hyprland.lua` that loads
  `hypr/dictionary.lua`

The repo stays the source of truth, so edits here take effect after a
`hyprctl reload`. Don't move the repo after installing; if you do, run
`./uninstall.sh` and `./install.sh` again.

reader.dict publishes a new Spanish build twice a month. To pick one up, run
`./install.sh --update`.

## Usage

- **Super + Alt + D** opens the English lookup and **Super + Shift + Alt + D**
  the Spanish one. Type a word and press Enter, then `q` to get back to the
  prompt. Press Enter on an empty prompt to close it.
- From any terminal: `define serendipity` or `define --es ñandú`.

## Claude Code

- **For users:** `skills/omarchy-dict` is a skill that lets Claude look words
  up with `define`, and fix or rebind the popup. `install.sh` links it into
  `~/.claude/skills` when `~/.claude` exists.
- **For contributors:** `CLAUDE.md` explains how the project works and the
  pitfalls it has already hit. Under `.claude/`, the `test-define` skill runs
  the end-to-end checks, `add-language` walks through adding a language, and
  the `reviewer` agent reviews changes before a commit.

## Changing the keys

Edit the `o.bind(...)` lines in `hypr/dictionary.lua`. Check that a key is free
with `omarchy menu keybindings --print`, or call `hl.unbind("<keys>")` before
the binding to replace an Omarchy default.

## Uninstall

```bash
./uninstall.sh
```

This removes the link, the keybindings and the Spanish dictionary, and leaves
the packages installed.

## Credits

The Spanish definitions come from [Wiktionary](https://es.wiktionary.org/)
(CC BY-SA), packaged by [reader.dict](https://www.reader-dict.com). They're
downloaded at install time and aren't part of this repo.
