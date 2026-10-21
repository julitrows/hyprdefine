---
name: omarchy-dict
description: Look up English or Spanish words (definitions, synonyms, translations) with the omarchy-dict define command, and troubleshoot or customise its Super+Alt+D dictionary popup on Omarchy. Use when asked what a word means, for a synonym or a translation between English and Spanish, or about the dictionary keybinding.
---

# omarchy-dict

`define` looks words up through a local `dictd` server, falling back to
dict.org for databases that aren't installed.

## Looking words up

Run it with a word to print the result and exit:

```bash
define serendipity           # Webster's 1913, WordNet, Moby thesaurus, English → Spanish
define --es ñandú            # Spanish Wiktionary, Spanish → English
define "casa de campo"       # multi-word headwords work
```

Answer from the output rather than from memory, and say which dictionary each
sense came from. For long entries, pipe through `head` or `grep` instead of
reading everything. To query a single database directly, use
`dict -d <db> <word>`, listing local databases with `dict -h localhost -D`.

If nothing is found, `define` prints "No definitions found" with spelling
suggestions. Try the suggestion or the base form of the word (infinitive or
singular).

## The keybindings

- **Super + Alt + D**: English lookup in a floating terminal
- **Super + Shift + Alt + D**: Spanish lookup

They're defined in `hypr/dictionary.lua` in the omarchy-dict repo, which is
loaded from `~/.config/hypr/hyprland.lua` by a line ending in
`-- omarchy-dict`. To change a key, edit the `o.bind(...)` line there, check
the new key is free with `omarchy menu keybindings --print`, then run
`hyprctl reload && hyprctl configerrors`.

## Troubleshooting

- **No results at all**: run `systemctl is-active dictd` and
  `dict -h localhost -D`. The local databases are `gcide`, `eng-spa`,
  `spa-eng` and `es-es`. If any are missing, the user should run `./install.sh`
  from the repo in their own terminal, because it needs `sudo`.
- **Nothing happens on the key**: the binding should appear exactly once in
  `omarchy menu keybindings --print | grep -i dictionary`, and
  `hyprctl configerrors` should be empty.
- **Outdated Spanish entries**: `./install.sh --update` rebuilds the Spanish
  dictionary from reader.dict's latest release.

Report bugs at https://github.com/julitrows/omarchy-dict/issues.
