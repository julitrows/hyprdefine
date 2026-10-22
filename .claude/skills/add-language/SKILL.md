---
name: add-language
description: Add another language to omarchy-dict's installer, such as one reader.dict has started publishing, or wire in a dictionary from another source. Use when asked to support a new language or dictionary.
---

# Add a language

Read `CLAUDE.md` first. Every language comes from `lib/languages`, so most
additions are a single line there.

## 1. Find the dictionaries

- **Definitions in the language**: reader.dict's DICT.org file is
  `https://www.reader-dict.com/file/<code>/dictorg-<code>-<code>-noetym.zip`.
  Check it exists with `curl -sI`. Download it to a scratch directory and build
  it with `lib/reader-dict.py` as in step 7 of the `test-define` skill, then
  look up a few common words, including ones with accents or other non-ASCII
  letters.
- **Translations**: find the language's FreeDict code with
  `dict -h dict.org -D | grep -i <language>`. Databases there are named
  `fd-<from>-<to>`.

Tell the user what you found, including anything missing, before writing code.

## 2. Wire it in

- **From reader.dict**: add a line to `lib/languages` with the reader.dict
  code, the FreeDict code and the language's own name for itself, in
  alphabetical order by code after English. `lib/dictionaries`, `define`,
  `lib/wiktionary.py` and `uninstall.sh` pick it up from there, including its
  FreeDict translations. If English Wiktionary uses a different code for it,
  add it to `ALIASES` in `lib/wiktionary.py`.
- **From another source**: add a build step to `install` in
  `lib/dictionaries` alongside `build_language`, make `remove` delete its
  files, and give it a case in `databases_for` in `bin/define`, the way
  English uses GCIDE. Keep
  `"local remote"` pairs, with `-` for a side that doesn't exist.
- **README.md**: add it to the list of languages, and to the credits if the
  source is new.

The keybindings don't change: every lookup searches all languages.

## 3. Verify

Run the `test-define` skill, installing the new code into a scratch home as
it describes, and check `define --<code> <word>` both before (Wiktionary) and
after (the local dictionary) installing it.
