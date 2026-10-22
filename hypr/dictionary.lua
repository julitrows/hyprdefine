-- omarchy-dict: open a floating dictionary lookup.
-- Loaded from ~/.config/hypr/hyprland.lua by install.sh.

local define = os.getenv("HOME") .. "/.local/bin/define"

if o and o.bind then
  -- Omarchy: TUI.* app-ids are already tagged as terminals, so the window
  -- picks up the theme's terminal styling; the tag adds the standard float.
  local launch = "omarchy-launch-tui --app-id=TUI.dictionary " .. define

  o.window("TUI.dictionary", { tag = "+floating-window" })

  o.bind("SUPER + ALT + D", "Dictionary", launch)
  o.bind("SUPER + SHIFT + ALT + D", "Spanish dictionary", launch .. " --es")
else
  -- Plain Hyprland: open the default terminal and float it the way Omarchy's
  -- floating-window tag does.
  local launch = "xdg-terminal-exec --app-id=TUI.dictionary " .. define

  hl.window_rule({ match = { class = "TUI.dictionary" }, float = true, center = true, size = { 875, 600 } })

  hl.bind("SUPER + ALT + D", hl.dsp.exec_cmd(launch), { description = "Dictionary" })
  hl.bind("SUPER + SHIFT + ALT + D", hl.dsp.exec_cmd(launch .. " --es"), { description = "Spanish dictionary" })
end
