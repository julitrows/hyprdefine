---
name: omarchy-dict
description: Look up words (definitions, synonyms, translations) in English and the other languages the user installed, with the omarchy-dict define command, and troubleshoot or customise its Super+Alt+D dictionary popup on Omarchy or Hyprland. Use when asked what a word means, for a synonym or a translation, or about the dictionary keybinding.
---

# omarchy-dict

`define` looks words up through a local `dictd` server, falling back to
dict.org for databases that aren't installed. It searches every language the
user installed at once; their codes are in `~/.config/omarchy-dict/languages`
(English and Spanish when the file is missing), and the names in the repo's
`lib/languages`.

## Looking words up

Run it with a word to print the result and exit:

```bash
define serendipity           # every installed language, under a heading each
define --en serendipity      # Webster's 1913, WordNet, Moby thesaurus, translations
define --es ñandú            # Spanish Wiktionary, Spanish → other languages
define --es "casa de campo"  # multi-word headwords work
```

Answer from the output rather than from memory, and say which dictionary each
sense came from. For long entries, pipe through `head` or `grep` instead of
reading everything. To query a single database directly, name its server:
`dict -h localhost -d <db> <word>` for the local ones (`gcide`, a
`<code>-<code>` Wiktionary per language such as `es-es`, and FreeDict pairs
such as `eng-spa`; list them with `dict -h localhost -D`), and
`dict -h dict.org -d <db> <word>` for the rest (`wn`, `moby-thesaurus`, and
the `fd-*` translation dictionaries). A plain `dict` only asks dict.org when
the local server is down.

If nothing is found, `define` prints "No definitions found" with spelling
suggestions. Try the suggestion or the base form of the word (infinitive or
singular).

## The keybindings

- **Super + Alt + D**: a lookup prompt in a floating terminal, searching
  every installed language
- **Super + Alt + W**: looks up the selected text (`define --selection`).
  Needs `wl-clipboard`

To add or drop languages, the user runs `./install.sh` again from the repo in
their own terminal, or `./install.sh --languages=en,fr` with codes from
`lib/languages`.

They're defined in `hypr/dictionary.lua` in the omarchy-dict repo, which is
loaded from `~/.config/hypr/hyprland.lua` by a line ending in
`-- omarchy-dict`. To change a key, edit its `bind(...)` line at the end of
that file. On Omarchy, check the new key is
free with `omarchy menu keybindings --print`. Then run
`hyprctl reload && hyprctl configerrors`.

## Troubleshooting

- **No results at all**: run `systemctl is-active dictd` and
  `dict -h localhost -D`. It should list `gcide` if English is installed and
  `<code>-<code>` for each other language. If any are missing, the user should
  run `./install.sh` from the repo in their own terminal, because it needs
  `sudo`.
- **Nothing happens on the key**: the binding should appear exactly once in
  `omarchy menu keybindings --print | grep -i dictionary`, and
  `hyprctl configerrors` should be empty.
- **Outdated entries**: `./install.sh --update` rebuilds every installed
  language from reader.dict's latest release.

Report bugs at https://github.com/julitrows/omarchy-dict/issues.
