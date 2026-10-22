# omarchy-dict

A dictionary on a keystroke for [Omarchy](https://omarchy.org/), or any Arch
install running Hyprland. Press **Super + Alt + D**, type a word and read its
definitions, in every language you've installed, in a floating terminal.

![Looking up "serendipity" in English and "ñandú" in Spanish](docs/demo.gif)

You choose the languages when you install. Each one gets:

| Language  | Definitions                                     | Translations                                 |
| --------- | ----------------------------------------------- | -------------------------------------------- |
| English   | Webster's 1913 (GCIDE), WordNet, Moby thesaurus | to every other installed language (FreeDict) |
| Any other | that language's Wiktionary                      | to every other installed language (FreeDict) |

The other languages are Bulgarian, Catalan, Chinese, Czech, Danish, Dutch,
Esperanto, Finnish, French, German, Greek, Italian, Japanese, Korean, Latin,
Lithuanian, Norwegian, Polish, Portuguese, Romanian, Russian, Spanish, Swedish,
Thai, Turkish and Ukrainian: everything [reader.dict](https://www.reader-dict.com)
publishes for DICT servers. Not every pair has a FreeDict translation.

Everything runs through [`dict`](https://github.com/cheusov/dictd) and a local
`dictd` server. WordNet, the thesaurus and translations that aren't packaged
come from dict.org, so lookups work offline and get richer online.

## Install

```bash
git clone https://github.com/julitrows/omarchy-dict.git ~/code/omarchy-dict
cd ~/code/omarchy-dict
./install.sh
```

The installer asks which languages you want, starting with English and
Spanish ticked. To skip the question, pass their codes from `lib/languages`:
`./install.sh --languages=en,fr,de`. Run it again to change them; dropping a
language removes its dictionary.

The installer:

- installs `dictd` and `wl-clipboard` (to read the selection), and enables the
  local `dictd` server
- installs from the AUR `dict-gcide` for English, and the prebuilt FreeDict
  translations (`dict-freedict-*-bin`) between your languages where they exist
- for each language other than English, downloads its dictionary from
  reader.dict, converts it to plain text and installs it to
  `/usr/local/share/dictd`, registered as `<code>-<code>` in
  `/etc/dict/dictd.conf`. Each takes a minute or two
- saves your languages in `~/.config/omarchy-dict/languages`
- links `bin/define` to `~/.local/bin/define`
- links the Claude Code skill into `~/.claude/skills`, if you use Claude Code
- appends a `dofile(...)` line to `~/.config/hypr/hyprland.lua` that loads
  `hypr/dictionary.lua`

Outside Omarchy it uses `pacman`, plus `yay` or `paru` for the AUR, and
installs `xdg-terminal-exec` to open your default terminal. Hyprland must use
the Lua config (`~/.config/hypr/hyprland.lua`), as Omarchy and current Hyprland
do. On Omarchy the popup follows your theme; elsewhere it's your default
terminal, floated and centred.

The repo stays the source of truth, so edits here take effect after a
`hyprctl reload`. Don't move the repo after installing; if you do, run
`./uninstall.sh` and `./install.sh` again.

reader.dict publishes new builds twice a month. To pick them up, run
`./install.sh --update`.

## Usage

- **Super + Alt + D** opens the prompt. Type a word and press Enter to see its
  definitions and translations in every installed language, each under its
  own heading, then `q` to get back to the prompt. Press Enter on an empty
  prompt to close it.
- **Super + Alt + W** looks up the text you've selected, and `q` closes it.
  Select a word by highlighting it; it doesn't need to be copied. With nothing
  selected, it opens the prompt.
- From any terminal: `define serendipity`, `define --es ñandú` to search one
  language, or `define --selection` for the selected text.

## Claude Code

- **For users:** `skills/omarchy-dict` is a skill that lets Claude look words
  up with `define`, and fix or rebind the popup. `install.sh` links it into
  `~/.claude/skills` when `~/.claude` exists.
- **For contributors:** `CLAUDE.md` explains how the project works and the
  pitfalls it has already hit. Under `.claude/`, the `test-define` skill runs
  the end-to-end checks, `add-language` walks through adding a language, and
  the `reviewer` agent reviews changes before a commit.

## Changing the keys

Edit the `bind(...)` lines at the end of `hypr/dictionary.lua`. On Omarchy,
check that a key is free with `omarchy menu keybindings --print`, or call
`hl.unbind("<keys>")` before the binding to replace an Omarchy default.

## Uninstall

```bash
./uninstall.sh
```

This removes the link, the keybindings, the dictionaries it built and the
saved languages, and prints the command to remove the packages too.

## Credits

The definitions in languages other than English come from
[Wiktionary](https://www.wiktionary.org/) (CC BY-SA), packaged by
[reader.dict](https://www.reader-dict.com). Translations come from
[FreeDict](https://freedict.org/). They're downloaded at install time and
aren't part of this repo.
