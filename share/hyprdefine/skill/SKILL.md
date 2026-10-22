---
name: hyprdefine
description: Look words up in English and 25 other languages (definitions, synonyms, translations) with the hyprdefine command, manage its installed languages, and troubleshoot or customise its Super+Alt+D dictionary popup on Hyprland or Omarchy. Use when asked what a word means, for a synonym or a translation, or about the dictionary popup, its keys or its languages.
---

# hyprdefine

`hyprdefine` (or its short name, `define`) looks a word up in every language
that has it:

- **Installed languages** come from the user's own `dictd`
  (`hyprdefine.service`, on localhost port 2629), with their translations to
  each other.
- **English** comes from GCIDE (Webster's 1913), WordNet and the Moby
  thesaurus, on dict.org when they aren't installed.
- **Every other language** comes from English Wiktionary, as short English
  meanings.

The installed language codes are in `~/.config/hyprdefine/languages`.

## Looking words up

Give it a word to print the result and exit:

```bash
hyprdefine casa                  # every language that has it, a heading each
hyprdefine --en serendipity      # English only
hyprdefine --es ñandú            # Spanish only
hyprdefine --es "casa de campo"  # multi-word headwords work
```

When an installed language has the word, the others are listed on a last
"Also in:" line; look one of them up with its `--<code>` for details.

Answer from the output rather than from memory, and say which dictionary each
sense came from. For long entries, pipe through `head` or `grep` instead of
reading everything. To query one database directly:
`dict -h localhost -p 2629 -d <db> <word>` for installed ones (list them with
`dict -h localhost -p 2629 -D`: `gcide`, `<code>-<code>` such as `es-es`, and
FreeDict pairs such as `eng-spa`), and `dict -h dict.org -d <db> <word>` for
`wn`, `moby-thesaurus` and the `fd-*` translations.

Installed languages also match the word with other accents, so `tropelia`
finds `tropelía`. If nothing is found, it prints "No definitions found" with spelling
suggestions. Try the suggestion or the base form of the word (infinitive or
singular).

## Languages

```bash
hyprdefine --install fr de   # codes: en bg ca cs da de el eo es fi fr it ja ko la lt nl no pl pt ro ru sv th tr uk zh
hyprdefine --remove de
hyprdefine --update          # rebuild from the latest Wiktionary releases
```

None of this needs `sudo`; each language takes a minute or two to download
and build into `~/.local/share/hyprdefine`. `hyprdefine --languages` is the
interactive menu for the same, which the user can also open by typing
`:languages` in the popup. After a lookup in the popup, hyprdefine offers to
install languages it showed; ones the user doesn't pick are listed in
`~/.config/hyprdefine/declined` and aren't offered again.

## The popup

- **Super + Alt + D**: the lookup prompt in a floating terminal
- **Super + Alt + W**: looks up the selected text (`hyprdefine --selection`)

`hyprdefine --setup` loads the keys through a line ending in `-- hyprdefine`
in `~/.config/hypr/hyprland.lua`, which runs hyprdefine's `hyprland.lua` (in
`share/hyprdefine/` of a git checkout, or `/usr/share/hyprdefine/`). To
change a key, copy that file, edit the `bind(...)` lines at the end, and
point the `-- hyprdefine` line at the copy. On Omarchy, check a key is free
with `omarchy menu keybindings --print`. Then run
`hyprctl reload && hyprctl configerrors`.

## Troubleshooting

- **Nothing happens on the key**: run `hyprdefine --setup` again (it's safe to
  repeat), then check `hyprctl configerrors`.
- **No results at all**: uninstalled languages need the network. For installed
  ones, `systemctl --user status hyprdefine` should be active; it's stopped
  on purpose when nothing is installed.
- **A language didn't install**: read `~/.local/share/hyprdefine/install.log`.

Report bugs at https://github.com/julitrows/hyprdefine/issues.
