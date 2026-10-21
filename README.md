# omarchy-dict

A dictionary on a keystroke for [Omarchy](https://omarchy.org/). Press
**Super + Alt + D**, type a word and read its definition in a floating terminal
that follows your theme.

Definitions come from [`dict`](https://github.com/cheusov/dictd): Webster's 1913
(GCIDE) is installed locally, and anything else, such as WordNet, the Moby
thesaurus or FOLDOC, is fetched from dict.org.

## Install

```bash
git clone https://github.com/julitrows/omarchy-dict.git ~/code/omarchy-dict
cd ~/code/omarchy-dict
./install.sh
```

The installer:

- installs `dictd` and `dict-gcide` (AUR) and enables the local `dictd` server
- links `bin/define` to `~/.local/bin/define`
- appends a `dofile(...)` line to `~/.config/hypr/hyprland.lua` that loads
  `hypr/dictionary.lua`

The repo stays the source of truth, so edits here take effect after a
`hyprctl reload`. Don't move the repo after installing; if you do, run
`./uninstall.sh` and `./install.sh` again.

## Usage

- **Super + Alt + D** opens the lookup. Type a word and press Enter, then `q`
  to get back to the prompt. Press Enter on an empty prompt to close it.
- From any terminal: `define serendipity`.

## Changing the key

Edit the `o.bind(...)` line in `hypr/dictionary.lua`. Check that the key is free
with `omarchy menu keybindings --print`, or call `hl.unbind("<keys>")` before
the binding to replace an Omarchy default.

## Uninstall

```bash
./uninstall.sh
```

This removes the link and the `dofile` line and leaves the packages installed.
