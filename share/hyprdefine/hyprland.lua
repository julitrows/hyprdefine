-- hyprdefine: the dictionary popup's keybindings and window rule.
--
-- `hyprdefine --setup` loads this from ~/.config/hypr/hyprland.lua with
--   loadfile("<this file>")("<path to hyprdefine>") -- hyprdefine
-- so the keys run the hyprdefine that set them up.

local hyprdefine = ... or "hyprdefine"
local app_id = "TUI.hyprdefine"

local bind

if o and o.bind then
  -- Omarchy: TUI.* app-ids are already tagged as terminals, so the window
  -- picks up the theme's terminal styling; the tag adds the standard float.
  local launch = "omarchy-launch-tui --app-id=" .. app_id .. " " .. hyprdefine

  o.window(app_id, { tag = "+floating-window" })

  bind = function(keys, description, args)
    o.bind(keys, description, launch .. args)
  end
else
  -- Plain Hyprland: open the default terminal and float it the way Omarchy's
  -- floating-window tag does.
  local launch = "xdg-terminal-exec --app-id=" .. app_id .. " " .. hyprdefine

  hl.window_rule({ match = { class = app_id }, float = true, center = true, size = { 875, 600 } })

  bind = function(keys, description, args)
    hl.bind(keys, hl.dsp.exec_cmd(launch .. args), { description = description })
  end
end

bind("SUPER + ALT + D", "Dictionary", "")
bind("SUPER + ALT + W", "Define selection", " --selection")
