---
name: add-language
description: Add another language to hyprdefine, such as one reader.dict has started publishing, or wire in a dictionary from another source. Use when asked to support a new language or dictionary.
---

# Add a language

Read `CLAUDE.md` first. Every language comes from `lib/hyprdefine/languages`,
so most additions are a single line there.

## 1. Find the dictionaries

- **Definitions in the language**: reader.dict's DICT.org file is
  `https://www.reader-dict.com/file/<code>/dictorg-<code>-<code>-noetym.zip`.
  Check it exists with `curl -sI`, then build and query it as in step 4 of
  the `test-hyprdefine` skill, with common words including ones with accents
  or other non-ASCII letters.
- **Translations**: find the language's FreeDict code with
  `dict -h dict.org -D | grep -i <language>`. Databases there are named
  `fd-<from>-<to>`.
- **Wiktionary**: check English Wiktionary's API uses the same code, with
  `curl -s https://en.wiktionary.org/api/rest_v1/page/definition/<word>`.

Tell the user what you found, including anything missing, before writing code.

## 2. Wire it in

- **From reader.dict**: add a line to `lib/hyprdefine/languages` with the
  reader.dict code, the FreeDict code and the language's own name for itself,
  in alphabetical order by code after English. Lookups, installs and the menu
  all pick it up from there, including its FreeDict translations. If English
  Wiktionary uses a different code, add it to `ALIASES` in
  `lib/hyprdefine/wiktionary.py`.
- **From another source**: add a build step to `install_languages` in
  `lib/hyprdefine/dictionaries.sh` alongside `build_language`, make
  `remove_languages` delete its files, and give it a case in `databases_for`
  in `lib/hyprdefine/lookup.sh`, the way English uses GCIDE. Keep
  `"local remote"` pairs, with `-` for a side that doesn't exist.
- **README.md** and **share/hyprdefine/skill/SKILL.md**: add it to the lists
  of languages and codes, and to the credits if the source is new.

The keys don't change: every lookup searches all languages.

## 3. Verify

`make test` checks the language list is well formed. Then check
`hyprdefine --<code> <word>` before installing (English meanings from
Wiktionary), and ask the user to try `hyprdefine --install <code>` and the
same lookup again (the language's own Wiktionary).
