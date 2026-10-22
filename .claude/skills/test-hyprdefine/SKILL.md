---
name: test-hyprdefine
description: Test hyprdefine after changing anything in bin/, lib/, share/, the installer or the packaging, and before committing. Also use when a lookup, the popup or a language install misbehaves on the user's machine.
---

# Test hyprdefine

Run these from the repo root and report each result. Stop and fix the first
failure before moving on.

1. **The suite**, always:

   ```bash
   make test
   ```

   It's offline and sandboxed (see `tests/support.py`): a fake `dict`, a
   local web server for Wiktionary, reader.dict and FreeDict, and recorded
   `systemctl`, `notify-send` and `hyprctl`. If you changed behaviour, add or
   update a test in the matching file (see the table in
   docs/architecture.md) before calling it done.

2. **The user's real setup**, after changing lookups, setup or the bindings.
   These only read:

   ```bash
   hyprdefine casa | grep -E '^(From|═|Also)'
   systemctl --user is-active hyprdefine
   dict -h localhost -p 2629 -D
   hyprctl configerrors
   omarchy menu keybindings --print | grep -iE 'dictionary|define selection'
   ```

   Each key should appear exactly once. If one appears twice, the
   `-- hyprdefine` line is duplicated in `~/.config/hypr/hyprland.lua`;
   `hyprdefine --setup` fixes it.

3. **The launcher environment**, if lookups work in a shell but not from the
   key. Run one the way the key does and read its output:

   ```bash
   out="$(mktemp)"
   omarchy-launch-tui --app-id=TUI.hyprdefine bash -c "hyprdefine house >$out 2>&1"
   sleep 4; cat "$out"
   ```

4. **Real reader.dict data**, after changing `lib/hyprdefine/reader-dict.py`.
   The suite uses small fixtures; this builds a real download in a scratch
   directory and serves it on a spare port:

   ```bash
   dir="$(mktemp -d)"
   curl -fsSL -o "$dir/es.zip" https://www.reader-dict.com/file/es/dictorg-es-es-noetym.zip
   python3 -I lib/hyprdefine/reader-dict.py "$dir/es.zip" |
     dictfmt -f --utf8 --quiet --columns 0 -s test "$dir/es-es"
   dictzip "$dir/es-es.dict"
   printf 'database es-es { data "%s/es-es.dict.dz" index "%s/es-es.index" }\n' "$dir" "$dir" >"$dir/dictd.conf"
   dictd -c "$dir/dictd.conf" -p 2639 --locale C.UTF-8 --pid-file "$dir/pid" -L "$dir/log"
   for w in casa árbol ÁRBOL ñandú cigüeña "casa de alto"; do
     dict -h localhost -p 2639 -- "$w" >/dev/null 2>&1; echo "$w: $?"
   done
   dict -h localhost -p 2639 árbol | head -20
   kill "$(cat "$dir/pid")"
   ```

   Every word should exit 0, and entries should be wrapped text with numbered
   senses and no HTML tags.

5. **The package**, after changing the Makefile, the layout or `packaging/`:
   build it from the working tree as in "Trying the package before a release"
   in docs/packaging.md. `makepkg` runs the suite in `check()`. Then list it
   with `tar -tf hyprdefine-*.pkg.tar.zst` and check every file under `lib/`
   and `share/` made it in.
