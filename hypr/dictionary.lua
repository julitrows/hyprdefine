-- omarchy-dict: open a floating dictionary lookup.
-- Loaded from ~/.config/hypr/hyprland.lua by install.sh.

local define = "omarchy-launch-tui --app-id=TUI.dictionary " .. os.getenv("HOME") .. "/.local/bin/define"

-- TUI.* app-ids are already tagged as terminals by Omarchy, so the window
-- picks up the theme's terminal styling; the tag adds the standard float.
o.window("TUI.dictionary", { tag = "+floating-window" })

o.bind("SUPER + ALT + D", "Dictionary", define)
o.bind("SUPER + SHIFT + ALT + D", "Spanish dictionary", define .. " --es")
