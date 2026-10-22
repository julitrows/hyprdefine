---
name: test-define
description: Test omarchy-dict end to end after changing define, the Lua bindings, the reader.dict converter, the language list or the installer. Use before committing, or when a lookup misbehaves in the floating window.
---

# Test define

Run the checks that match what changed, from the repo root, and report each
result. Stop and fix the first failure before moving on.

1. **Syntax**, always:

   ```bash
   bash -n bin/define install.sh uninstall.sh
   luac -p hypr/dictionary.lua
   python3 -I -m py_compile lib/reader-dict.py tests/interactive.py
   ```

2. **Local server**: `dict -h localhost -D` should list `gcide` and a
   `<code>-<code>` database for each other language in
   `~/.config/omarchy-dict/languages`. If any are missing, the user needs to
   run `./install.sh` in their own terminal, because it uses `sudo`.

3. **One-shot lookups** for both languages and a miss:

   ```bash
   define house | head
   define serendipity | grep '^From'     # WordNet and Moby come from dict.org
   define --es ñandú | head
   define casa | grep -E '^(From|═)'     # a heading per language that matched
   define zzqxv                          # "No definitions found"
   ```

   To try other language sets without touching the user's config, point
   `define` at a scratch one:

   ```bash
   dir="$(mktemp -d)"; mkdir "$dir/omarchy-dict"
   echo "en es fr" >"$dir/omarchy-dict/languages"
   XDG_CONFIG_HOME="$dir" define chat | grep -E '^(From|═)'
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
