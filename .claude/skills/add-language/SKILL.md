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
  alphabetical order by code after English. `install.sh`, `uninstall.sh` and
  `define` pick it up from there, including its AUR translation packages.
- **From another source**: add an install step to `install.sh` alongside
  `install_language`, guarded by `has <code>` and removed by
  `remove_language` when it isn't chosen, and give it a case in
  `databases_for` in `bin/define`, the way English uses GCIDE. Keep
  `"local remote"` pairs, with `-` for a side that doesn't exist.
- **README.md**: add it to the list of languages, and to the credits if the
  source is new.

The keybindings don't change: every key searches all installed languages.

## 3. Verify

Run the `test-define` skill, pointing `define` at a scratch config that
includes the new code. The user has to run `./install.sh --languages=...`
themselves, since it uses `sudo`. Then check `define --<code> <word>` against
the installed database.
