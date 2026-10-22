---
name: omarchy-dict
description: Look up words in any of 26 languages (definitions, synonyms, translations) with the omarchy-dict define command, manage its installed languages, and troubleshoot or customise its Super+Alt+D dictionary popup on Omarchy or Hyprland. Use when asked what a word means, for a synonym or a translation, or about the dictionary keybinding or languages.
---

# omarchy-dict

`define` searches every language that has a word. Installed languages come
from the user's own `dictd` (`omarchy-dict.service`, on localhost port 2629),
English from dict.org when it isn't installed, and every other language from
English Wiktionary, as English meanings. The installed codes are in
`~/.config/omarchy-dict/languages`, and the names in the repo's
`lib/languages`.

## Looking words up

Run it with a word to print the result and exit:

```bash
define casa                  # every language that has it, a heading each
define --en serendipity      # Webster's 1913, WordNet, Moby thesaurus, translations
define --es ñandú            # Spanish only: its Wiktionary if installed, else English meanings
define --es "casa de campo"  # multi-word headwords work
```

Answer from the output rather than from memory, and say which dictionary each
sense came from. For long entries, pipe through `head` or `grep` instead of
reading everything. To query a single database directly, name its server:
`dict -h localhost -p 2629 -d <db> <word>` for the installed ones (`gcide`, a
`<code>-<code>` Wiktionary per language such as `es-es`, and FreeDict pairs
such as `eng-spa`; list them with `dict -h localhost -p 2629 -D`), and
`dict -h dict.org -d <db> <word>` for the rest (`wn`, `moby-thesaurus`, and
the `fd-*` translation dictionaries).

If nothing is found, `define` prints "No definitions found" with spelling
suggestions. Try the suggestion or the base form of the word (infinitive or
singular).

## The keybindings

- **Super + Alt + D**: a lookup prompt in a floating terminal
- **Super + Alt + W**: looks up the selected text (`define --selection`).
  Needs `wl-clipboard`

After a lookup in the popup, `define` offers to install the languages it
showed that aren't installed. Languages the user doesn't pick go in
`~/.config/omarchy-dict/declined` and aren't offered again.

## Managing languages

`define --languages` (or `:languages` at the popup prompt) opens a menu to
add, remove or update languages, or to offer declined ones again. Without the
menu, use the repo's `lib/dictionaries`:

```bash
lib/dictionaries install fr de   # codes from lib/languages; downloads and builds
lib/dictionaries remove fr
lib/dictionaries update          # rebuild from reader.dict's latest release
```

None of this needs `sudo`. Each language takes a minute or two to build, and
lives in `~/.local/share/omarchy-dict/dictionaries`.

## Changing the keys

The keys are defined in `hypr/dictionary.lua` in the omarchy-dict repo, which
is loaded from `~/.config/hypr/hyprland.lua` by a line ending in
`-- omarchy-dict`. To change a key, edit its `bind(...)` line at the end of
that file. On Omarchy, check the new key is free with
`omarchy menu keybindings --print`. Then run
`hyprctl reload && hyprctl configerrors`.

## Troubleshooting

- **No results at all**: check the network first, since uninstalled languages
  come from the web. For installed ones, run
  `systemctl --user status omarchy-dict` and `dict -h localhost -p 2629 -D`.
  It should list `gcide` if English is installed and `<code>-<code>` for each
  other language. The server is stopped when nothing is installed.
- **A language didn't install**: read
  `~/.local/share/omarchy-dict/install.log`.
- **Nothing happens on the key**: the binding should appear exactly once in
  `omarchy menu keybindings --print | grep -i dictionary`, and
  `hyprctl configerrors` should be empty.
- **Outdated entries**: `lib/dictionaries update` rebuilds every installed
  language from reader.dict's latest release.

Report bugs at https://github.com/julitrows/omarchy-dict/issues.
