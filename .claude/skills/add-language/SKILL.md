---
name: add-language
description: Add another language to omarchy-dict, such as French or German definitions, translations, and a keybinding. Use when asked to support a new language or dictionary.
---

# Add a language

Read `CLAUDE.md` first. Spanish is the worked example, so mirror how it's
wired.

## 1. Find the dictionaries

- **Definitions in the language**: check reader.dict's downloads at
  `https://www.reader-dict.com/<lang>/download/<lang>`. The DICT.org file is
  `https://www.reader-dict.com/file/<lang>/dictorg-<lang>-<lang>-noetym.zip`.
  Download it to a scratch directory and check that it has the same layout as
  Spanish (one `.index` with base64 offsets, one `.dict.dz` of HTML) before
  reusing `lib/spanish-dict.py`.
- **Translations**: list FreeDict databases with
  `dict -h dict.org -D | grep -i <language>`, and look for prebuilt AUR
  packages with
  `curl -s 'https://aur.archlinux.org/rpc/v5/search/freedict?by=name'`.
  Prefer the `-bin` packages: they register themselves in
  `/etc/dict/dictd.conf` and need no build tools. Locally they're named like
  `fra-eng`, and on dict.org like `fd-fra-eng`.

Tell the user what you found, including anything missing, before writing code.

## 2. Wire it in

- **Converter**: if the download matches Spanish, make the converter generic
  rather than copying it. Rename it to `lib/reader-dict.py`, keep it
  standard-library only, and update both `install.sh` and the `test-define`
  skill.
- **`install.sh`**: download, build and install as `<lang>-<lang>` into
  `/usr/local/share/dictd`, inside the same `# omarchy-dict begin/end` block,
  and add the AUR packages. `--update` should rebuild every language.
- **`uninstall.sh`**: remove the new files, and list the new packages in the
  `omarchy pkg drop` and `pacman -Rns` hints.
- **`bin/define`**: add a database array and a `--<lang>` flag with a prompt
  and placeholder in that language. Keep `"local remote"` pairs, with `-` for
  a side that doesn't exist.
- **`hypr/dictionary.lua`**: add a binding to both the Omarchy and the
  plain-Hyprland branch. Check the key is free with
  `omarchy menu keybindings --print` and say which key you chose.
- **README.md and `skills/omarchy-dict/SKILL.md`**: update the table, keys and
  credits.

## 3. Verify

Run the `test-define` skill, using the new flag and words with accents or
other non-ASCII letters. The user has to run `./install.sh` themselves, since
it uses `sudo`. Then run the interactive test against the installed database.
