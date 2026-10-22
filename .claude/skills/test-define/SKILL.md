---
name: test-define
description: Test omarchy-dict end to end after changing define, the language management, the Wiktionary or FreeDict helpers, the Lua bindings, the reader.dict converter or the installer. Use before committing, or when a lookup misbehaves in the floating window.
---

# Test define

Run the checks that match what changed, from the repo root, and report each
result. Stop and fix the first failure before moving on.

1. **Syntax**, always:

   ```bash
   bash -n bin/define lib/dictionaries install.sh uninstall.sh
   luac -p hypr/dictionary.lua
   python3 -I -m py_compile lib/reader-dict.py lib/wiktionary.py lib/freedict.py tests/interactive.py
   rm -rf lib/__pycache__ tests/__pycache__
   ```

2. **Local server**: `dict -h localhost -p 2629 -D` should list `gcide` (if
   English is installed) and a `<code>-<code>` database for each other
   language in `~/.config/omarchy-dict/languages`, plus translation pairs
   between them. `systemctl --user status omarchy-dict` shows the server.

3. **One-shot lookups** for both languages and a miss:

   ```bash
   define house | head
   define serendipity | grep '^From'     # WordNet and Moby come from dict.org
   define --es ñandú | head
   define casa | grep -E '^(From|═|Also)' # headings, and "Also in" once one is installed
   define Haus | head -3                 # German, from Wiktionary unless installed
   define zzqxv                          # "No definitions found"
   ```

   To try languages without touching the user's, install them into a scratch
   home with stand-ins for `systemctl` and `notify-send`, serve them yourself
   on port 2629 (only while the user's `omarchy-dict.service` is stopped or
   not installed), and point `define` at the scratch config:

   ```bash
   dir="$(mktemp -d)"; mkdir -p "$dir/bin" "$dir/home"
   printf '#!/bin/sh\n' >"$dir/bin/systemctl"; cp "$dir/bin/systemctl" "$dir/bin/notify-send"
   chmod +x "$dir/bin/"*
   HOME="$dir/home" XDG_CONFIG_HOME="$dir/home/.config" PATH="$dir/bin:$PATH" lib/dictionaries install en la
   data="$dir/home/.local/share/omarchy-dict"
   dictd -c "$data/dictd.conf" -p 2629 --listen-to 127.0.0.1 --locale C.UTF-8 --pid-file "$dir/pid" -L "$dir/log"
   XDG_CONFIG_HOME="$dir/home/.config" define rosa | grep -E '^(From|═|Also)'
   kill "$(cat "$dir/pid")"
   ```

4. **Prompt loop**, the way the keybinding runs it. Include a short entry, a
   word starting with h, m or s, and one with prompt syntax:

   ```bash
   python3 -I tests/interactive.py house casa serendipity etc. "what?"
   python3 -I tests/interactive.py --es casa ñandú
   ```

5. **Keybindings**, after Lua changes:

   ```bash
   hyprctl reload && hyprctl configerrors
   omarchy menu keybindings --print | grep -i dictionary
   ```

   Each binding should appear exactly once. If one appears twice, the
   `dofile` line is duplicated in `~/.config/hypr/hyprland.lua`.

6. **Launcher environment**, if lookups work in your shell but not from the
   key. Run one through the same launcher and read its output:

   ```bash
   out="$(mktemp)"
   omarchy-launch-tui --app-id=TUI.dictionary bash -c "define house >$out 2>&1"
   sleep 4; cat "$out"
   ```

7. **Converter**, after changing `lib/reader-dict.py`: build into a
   scratch directory and serve it from a temporary `dictd` on another port.
   Don't touch `/usr/local/share/dictd`.

   ```bash
   dir="$(mktemp -d)"
   curl -fsSL -o "$dir/es.zip" https://www.reader-dict.com/file/es/dictorg-es-es-noetym.zip
   python3 -I lib/reader-dict.py "$dir/es.zip" |
     dictfmt -f --utf8 --quiet --columns 0 -s test "$dir/es-es"
   dictzip "$dir/es-es.dict"
   printf 'database es-es { data "%s/es-es.dict.dz" index "%s/es-es.index" }\n' "$dir" "$dir" >"$dir/dictd.conf"
   dictd -c "$dir/dictd.conf" -p 2639 --pid-file "$dir/pid" -L "$dir/log"
   for w in casa árbol ÁRBOL ñandú cigüeña "casa de alto"; do
     dict -h localhost -p 2639 -- "$w" >/dev/null 2>&1; echo "$w: $?"
   done
   dict -h localhost -p 2639 árbol | head -20
   kill "$(cat "$dir/pid")"
   ```

   Every word should exit 0, and entries should be wrapped text with numbered
   senses and no HTML tags.
