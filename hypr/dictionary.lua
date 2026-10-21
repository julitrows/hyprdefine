-- omarchy-dict: open a floating dictionary lookup.
-- Loaded from ~/.config/hypr/hyprland.lua by install.sh.

local define = os.getenv("HOME") .. "/.local/bin/define"

-- TUI.* app-ids are already tagged as terminals by Omarchy, so the window
-- picks up the theme's terminal styling; the tag adds the standard float.
o.window("TUI.dictionary", { tag = "+floating-window" })

o.bind("SUPER + ALT + D", "Dictionary", "omarchy-launch-tui --app-id=TUI.dictionary " .. define)
