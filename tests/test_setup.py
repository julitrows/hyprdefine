"""hyprdefine --setup and --teardown in a scratch home."""

import os
import unittest

from support import REPO, Sandbox, HYPRDEFINE

LINE = (f'loadfile("{REPO}/share/hyprdefine/hyprland.lua")("{REPO}/bin/hyprdefine") -- hyprdefine')
USER_CONFIG = "-- the user's own config\n"


class SetupTest(Sandbox):
    def setUp(self):
        super().setUp()
        self.write(".config/hypr/hyprland.lua", USER_CONFIG)
        os.makedirs(self.path(".claude"))

    def hyprland(self):
        return self.read(".config/hypr/hyprland.lua")

    def link(self, relative):
        path = self.path(relative)
        return os.readlink(path) if os.path.islink(path) else None

    def test_setup_loads_the_keys_and_links_everything(self):
        self.run_hyprdefine("--setup")
        self.assertEqual(self.hyprland(), USER_CONFIG + LINE + "\n")
        self.assertEqual(self.link(".local/bin/define"), HYPRDEFINE)
        self.assertEqual(self.link(".config/systemd/user/hyprdefine.service"),
                         f"{REPO}/lib/systemd/user/hyprdefine.service")
        self.assertEqual(self.link(".claude/skills/hyprdefine"), f"{REPO}/share/hyprdefine/skill")
        self.assertIn("--user enable hyprdefine.service", self.recorded("systemctl"))

    def test_setup_is_idempotent(self):
        self.run_hyprdefine("--setup")
        self.run_hyprdefine("--setup")
        self.assertEqual(self.hyprland().count("-- hyprdefine"), 1)

    def test_setup_adds_a_missing_final_newline(self):
        self.write(".config/hypr/hyprland.lua", "-- no newline")
        self.run_hyprdefine("--setup")
        self.assertEqual(self.hyprland(), "-- no newline\n" + LINE + "\n")

    def test_setup_leaves_someone_elses_define_alone(self):
        os.makedirs(self.path(".local/bin"))
        os.symlink("/usr/bin/true", self.path(".local/bin/define"))
        result = self.run_hyprdefine("--setup")
        self.assertEqual(self.link(".local/bin/define"), "/usr/bin/true")
        self.assertIn("isn't hyprdefine's", result.stderr)

    def test_setup_starts_the_server_when_languages_are_installed(self):
        self.install_state("en")
        for suffix in (".index", ".dict.dz"):
            open(os.path.join(self.root, "gcide" + suffix), "w").close()
        self.run_hyprdefine("--setup")
        self.assertIn("--user restart hyprdefine.service", self.recorded("systemctl"))

    def test_setup_needs_the_lua_config(self):
        os.remove(self.path(".config/hypr/hyprland.lua"))
        result = self.run_hyprdefine("--setup", check=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("needs Hyprland's Lua config", result.stderr)

    def test_setup_moves_an_omarchy_dict_install_over(self):
        old = "/home/someone/code/omarchy-dict"
        self.write(".config/hypr/hyprland.lua",
                   USER_CONFIG + f'dofile("{old}/hypr/dictionary.lua") -- omarchy-dict\n')
        self.write(".config/omarchy-dict/languages", "en es\n")
        self.write(".local/share/omarchy-dict/dictionaries/es-es.index", "")
        self.write(".local/share/omarchy-dict/dictd.conf", f"database es-es {{ {old} }}\n")
        os.makedirs(self.path(".config/systemd/user"))
        os.symlink(f"{old}/systemd/omarchy-dict.service", self.path(".config/systemd/user/omarchy-dict.service"))
        os.makedirs(self.path(".local/bin"))
        os.symlink(f"{old}/bin/define", self.path(".local/bin/define"))
        os.makedirs(self.path(".claude/skills"))
        os.symlink(f"{old}/skills/omarchy-dict", self.path(".claude/skills/omarchy-dict"))

        self.run_hyprdefine("--setup")

        self.assertEqual(self.hyprland(), USER_CONFIG + LINE + "\n")
        self.assertEqual(self.read(".config/hyprdefine/languages"), "en es\n")
        self.assertTrue(os.path.exists(self.path(".local/share/hyprdefine/dictionaries/es-es.index")))
        self.assertNotIn(old, self.read(".local/share/hyprdefine/dictd.conf"))
        for gone in (".config/omarchy-dict", ".local/share/omarchy-dict",
                     ".config/systemd/user/omarchy-dict.service", ".claude/skills/omarchy-dict"):
            self.assertFalse(os.path.lexists(self.path(gone)), gone)
        self.assertIn("--user disable --now omarchy-dict.service", self.recorded("systemctl"))
        self.assertEqual(self.link(".local/bin/define"), HYPRDEFINE)

    def test_teardown_undoes_setup(self):
        self.run_hyprdefine("--setup")
        self.install_state("en")
        self.write(".local/share/hyprdefine/dictionaries/es-es.index", "")
        self.run_hyprdefine("--teardown")

        self.assertEqual(self.hyprland(), USER_CONFIG)
        for gone in (".local/bin/define", ".config/systemd/user/hyprdefine.service",
                     ".claude/skills/hyprdefine", ".config/hyprdefine", ".local/share/hyprdefine"):
            self.assertFalse(os.path.lexists(self.path(gone)), gone)
        self.assertIn("--user disable --now hyprdefine.service", self.recorded("systemctl"))

    def test_teardown_leaves_someone_elses_define_alone(self):
        os.makedirs(self.path(".local/bin"))
        os.symlink("/usr/bin/true", self.path(".local/bin/define"))
        self.run_hyprdefine("--teardown")
        self.assertEqual(self.link(".local/bin/define"), "/usr/bin/true")

    def test_hyprland_is_reloaded_inside_a_session(self):
        self.run_hyprdefine("--setup", HYPRLAND_INSTANCE_SIGNATURE="test")
        self.assertEqual(self.recorded("hyprctl"), ["reload", "configerrors"])

    def test_hyprland_is_left_alone_outside_a_session(self):
        self.run_hyprdefine("--setup", HYPRLAND_INSTANCE_SIGNATURE="")
        self.assertEqual(self.recorded("hyprctl"), [])


if __name__ == "__main__":
    unittest.main()
