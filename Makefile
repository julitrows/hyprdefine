# hyprdefine's checks, tests and system-wide install.
#
#   make check     syntax-check the shell, Lua and Python
#   make test      run the test suite (offline; needs dictd, gum and lua)
#   make install   install under $(DESTDIR)$(PREFIX), as the AUR package does
#
# A git checkout doesn't need `make install`: ./install.sh runs it in place.

PREFIX ?= /usr
DESTDIR ?=

SHELL_SCRIPTS := bin/hyprdefine $(wildcard lib/hyprdefine/*.sh) install.sh uninstall.sh
PYTHON := $(wildcard lib/hyprdefine/*.py) $(wildcard tests/*.py)

.PHONY: check test install

check:
	@for script in $(SHELL_SCRIPTS); do bash -n "$$script" || exit 1; done
	luac -p share/hyprdefine/hyprland.lua
	python3 -I -c 'import ast, sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]' $(PYTHON)
	@echo "Syntax OK."

test: check
	python3 -I -m unittest discover -s tests

install:
	install -Dm755 bin/hyprdefine "$(DESTDIR)$(PREFIX)/bin/hyprdefine"
	install -Dm644 -t "$(DESTDIR)$(PREFIX)/lib/hyprdefine" \
		lib/hyprdefine/common.sh lib/hyprdefine/dictionaries.sh lib/hyprdefine/lookup.sh \
		lib/hyprdefine/setup.sh lib/hyprdefine/languages
	install -Dm755 -t "$(DESTDIR)$(PREFIX)/lib/hyprdefine" \
		lib/hyprdefine/freedict.py lib/hyprdefine/reader-dict.py lib/hyprdefine/wiktionary.py
	install -Dm644 lib/systemd/user/hyprdefine.service "$(DESTDIR)$(PREFIX)/lib/systemd/user/hyprdefine.service"
	install -Dm644 share/hyprdefine/hyprland.lua "$(DESTDIR)$(PREFIX)/share/hyprdefine/hyprland.lua"
	install -Dm644 share/hyprdefine/skill/SKILL.md "$(DESTDIR)$(PREFIX)/share/hyprdefine/skill/SKILL.md"
	install -Dm644 -t "$(DESTDIR)$(PREFIX)/share/doc/hyprdefine" README.md docs/architecture.md
	install -Dm644 LICENSE "$(DESTDIR)$(PREFIX)/share/licenses/hyprdefine/LICENSE"
