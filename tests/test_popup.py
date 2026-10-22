"""The popup, driven in a pseudo-terminal the way the keybinding runs it: the
prompt loop, the pager, --selection and the offer to install languages."""

import fcntl
import os
import pty
import re
import select
import shutil
import signal
import struct
import termios
import time
import unittest
import warnings

from support import HYPRDEFINE, Sandbox, entry, wiktionary_entry

ESCAPES = re.compile(r"\x1b\[[0-9;?<>=$]*[a-zA-Z]|\x1b[=>()][0-9A-Za-z]?|\r")
KEYS = {"enter": b"\r", "esc": b"\x1b", "x": b"x", "q": b"q"}


class Terminal:
    """hyprdefine running in a pty, with the text it has drawn since the last
    wait_for."""

    def __init__(self, args, env):
        # The test web server runs in a thread, which makes Python warn about
        # forking. The child only sets the window size and execs, so it's safe.
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", DeprecationWarning)
            self.pid, self.fd = pty.fork()
        if self.pid == 0:
            # gum panics without a window size, so give it a real one.
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 100, 0, 0))
            os.execve(HYPRDEFINE, [HYPRDEFINE, *args], env)
        self.screen = ""

    def read(self, seconds=0.1):
        deadline = time.time() + seconds
        while time.time() < deadline:
            if select.select([self.fd], [], [], 0.05)[0]:
                try:
                    self.screen += ESCAPES.sub("", os.read(self.fd, 65536).decode(errors="replace"))
                except OSError:
                    return

    def wait_for(self, text, timeout=10):
        deadline = time.time() + timeout
        while text not in self.screen:
            if time.time() > deadline:
                raise AssertionError(f"never saw {text!r} on screen:\n{self.screen[-1500:]}")
            self.read()
        seen, self.screen = self.screen, ""
        return seen

    def type(self, text):
        os.write(self.fd, text.encode() + b"\r")

    def press(self, *keys):
        for key in keys:
            os.write(self.fd, KEYS[key])
            time.sleep(0.3)

    def exit_status(self, timeout=10):
        deadline = time.time() + timeout
        while time.time() < deadline:
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid:
                return os.waitstatus_to_exitcode(status)
            self.read()
        return None

    def close(self):
        try:
            os.kill(self.pid, signal.SIGKILL)
            os.waitpid(self.pid, 0)
        except (ProcessLookupError, ChildProcessError):
            pass
        os.close(self.fd)


@unittest.skipUnless(shutil.which("gum"), "needs gum")
class PopupTest(Sandbox):
    def setUp(self):
        super().setUp()
        self.servers["dict.org:2628"] = {
            "gcide": {
                "house": entry("gcide", "house", "A building.\n" + "        More.\n" * 60),
                "serendipity": entry("gcide", "serendipity", "A happy accident."),
                "etc.": entry("gcide", "etc.", "Et cetera."),
                "what?": entry("gcide", "what?", "A question."),
            },
            "wn": {}, "moby-thesaurus": {},
        }
        self.wiktionary["haus"] = {"de": wiktionary_entry("house, building")}

    def start(self, *args, **env):
        terminal = Terminal(args, self.env(**env))
        self.addCleanup(terminal.close)
        return terminal

    def test_each_lookup_stays_on_screen_until_q(self):
        # A long entry, a short one, and words with less's prompt syntax.
        terminal = self.start()
        terminal.wait_for("Define:")
        for word in ("house", "serendipity", "etc.", "what?"):
            terminal.type(word)
            terminal.wait_for(f"{word} (q to go back)")
            terminal.press("q")
            terminal.wait_for("Define:")
        terminal.press("enter")
        self.assertEqual(terminal.exit_status(), 0)

    def test_a_short_entry_is_drawn_from_the_top(self):
        terminal = self.start()
        terminal.wait_for("Define:")
        terminal.type("serendipity")
        screen = terminal.wait_for("serendipity (q to go back)")
        self.assertNotIn("~", screen)
        self.assertLess(screen.index("A happy accident."), screen.index("serendipity (q to go back)"))

    def test_selection_closes_with_the_pager(self):
        terminal = self.start("--selection", FAKE_SELECTION=" serendipity,\nsecond line")
        terminal.wait_for("serendipity (q to close)")
        terminal.press("q")
        self.assertEqual(terminal.exit_status(), 0)

    def test_an_empty_selection_opens_the_prompt(self):
        terminal = self.start("--selection", FAKE_SELECTION="")
        terminal.wait_for("Define:")

    def wait_until(self, condition, message, timeout=60):
        deadline = time.time() + timeout
        while not condition():
            self.assertLess(time.time(), deadline, message)
            time.sleep(0.2)

    def offer(self, *keys):
        """Look up "haus", which only German has, and answer the offer."""
        terminal = self.start(HYPRDEFINE_NO_OFFER="")
        terminal.wait_for("Define:")
        terminal.type("haus")
        terminal.wait_for("haus (q to go back)")
        terminal.press("q")
        terminal.wait_for("Install for offline lookups")
        terminal.press(*keys)
        return terminal

    def test_picking_a_language_installs_it_in_the_background(self):
        self.serve_reader_dict("de", {"Haus": "<ol><li>Gebäude.</li></ol>"})
        self.serve_freedict()
        terminal = self.offer("x", "enter")
        terminal.wait_for("Installing Deutsch in the background")
        self.wait_until(lambda: os.path.exists(self.path(".config/hyprdefine/languages")),
                        "the background install never finished")
        self.assertEqual(self.read(".config/hyprdefine/languages").strip(), "de")
        self.assertIn("Dictionary Deutsch installed for offline lookups.", self.recorded("notify-send"))

    def test_not_picking_a_language_declines_it(self):
        terminal = self.offer("enter")
        terminal.wait_for("Define:")
        self.assertEqual(self.read(".config/hyprdefine/declined").strip(), "de")

    def test_esc_asks_again_next_time(self):
        terminal = self.offer("esc")
        terminal.wait_for("Define:")
        self.assertFalse(os.path.exists(self.path(".config/hyprdefine/declined")))

    def test_declined_languages_are_not_offered(self):
        self.install_state(declined="de")
        terminal = self.start(HYPRDEFINE_NO_OFFER="")
        terminal.wait_for("Define:")
        terminal.type("haus")
        terminal.wait_for("haus (q to go back)")
        terminal.press("q")
        screen = terminal.wait_for("Define:")
        self.assertNotIn("Install for offline lookups", screen)


if __name__ == "__main__":
    unittest.main()
