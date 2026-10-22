"""share/hyprdefine/hyprland.lua, run under Lua with stand-ins for Hyprland's
`hl` API and Omarchy's `o` helpers."""

import os
import shutil
import subprocess
import unittest

from support import REPO

LUA = shutil.which("lua") or shutil.which("luajit")
BINDINGS = os.path.join(REPO, "share", "hyprdefine", "hyprland.lua")

# Prints one line per binding and window rule.
HARNESS = """
hl = {
  dsp = { exec_cmd = function(command) return command end },
  bind = function(keys, command, options)
    print("bind|" .. keys .. "|" .. command .. "|" .. options.description)
  end,
  window_rule = function(rule)
    print("rule|" .. rule.match.class .. "|float=" .. tostring(rule.float) .. "|center=" .. tostring(rule.center)
      .. "|size=" .. rule.size[1] .. "x" .. rule.size[2])
  end,
}
if OMARCHY then
  o = {
    bind = function(keys, description, command) print("bind|" .. keys .. "|" .. command .. "|" .. description) end,
    window = function(class, rules) print("rule|" .. class .. "|tag=" .. rules.tag) end,
  }
end
loadfile(BINDINGS)(HYPRDEFINE)
"""


@unittest.skipUnless(LUA, "needs lua or luajit")
class HyprlandLuaTest(unittest.TestCase):
    def run_bindings(self, omarchy, hyprdefine='"/usr/bin/hyprdefine"'):
        script = f"OMARCHY = {str(omarchy).lower()}\nBINDINGS = {BINDINGS!r}\nHYPRDEFINE = {hyprdefine}\n" + HARNESS
        result = subprocess.run([LUA, "-"], input=script, capture_output=True, text=True, check=True)
        return result.stdout.splitlines()

    def test_omarchy_uses_its_launcher_and_floating_tag(self):
        self.assertEqual(self.run_bindings(omarchy=True), [
            "rule|TUI.hyprdefine|tag=+floating-window",
            "bind|SUPER + ALT + D|omarchy-launch-tui --app-id=TUI.hyprdefine /usr/bin/hyprdefine|Dictionary",
            "bind|SUPER + ALT + W|omarchy-launch-tui --app-id=TUI.hyprdefine /usr/bin/hyprdefine --selection|Define selection",
        ])

    def test_plain_hyprland_floats_the_default_terminal(self):
        self.assertEqual(self.run_bindings(omarchy=False), [
            "rule|TUI.hyprdefine|float=true|center=true|size=875x600",
            "bind|SUPER + ALT + D|xdg-terminal-exec --app-id=TUI.hyprdefine /usr/bin/hyprdefine|Dictionary",
            "bind|SUPER + ALT + W|xdg-terminal-exec --app-id=TUI.hyprdefine /usr/bin/hyprdefine --selection|Define selection",
        ])

    def test_without_a_path_it_runs_hyprdefine_from_path(self):
        self.assertIn("bind|SUPER + ALT + D|xdg-terminal-exec --app-id=TUI.hyprdefine hyprdefine|Dictionary",
                      self.run_bindings(omarchy=False, hyprdefine="nil"))


if __name__ == "__main__":
    unittest.main()
