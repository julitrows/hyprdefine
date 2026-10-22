-- omarchy-dict: open a floating dictionary lookup.
-- Loaded from ~/.config/hypr/hyprland.lua by install.sh.

local define = os.getenv("HOME") .. "/.local/bin/define"

local bind

if o and o.bind then
  -- Omarchy: TUI.* app-ids are already tagged as terminals, so the window
  -- picks up the theme's terminal styling; the tag adds the standard float.
  local launch = "omarchy-launch-tui --app-id=TUI.dictionary " .. define

  o.window("TUI.dictionary", { tag = "+floating-window" })

  bind = function(keys, description, args)
    o.bind(keys, description, launch .. args)
  end
else
  -- Plain Hyprland: open the default terminal and float it the way Omarchy's
  -- floating-window tag does.
  local launch = "xdg-terminal-exec --app-id=TUI.dictionary " .. define

  hl.window_rule({ match = { class = "TUI.dictionary" }, float = true, center = true, size = { 875, 600 } })

  bind = function(keys, description, args)
    hl.bind(keys, hl.dsp.exec_cmd(launch .. args), { description = description })
  end
end

-- define searches every installed language at once.
bind("SUPER + ALT + D", "Dictionary", "")
bind("SUPER + ALT + W", "Define selection", " --selection")
