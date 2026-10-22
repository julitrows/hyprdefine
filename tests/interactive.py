#!/usr/bin/env python3

# Drive define's interactive loop in a pseudo-terminal, the way the keybinding
# runs it: type each word, check its pager opened, press q, and finally submit
# an empty word to quit. Exits non-zero if any lookup didn't stay on screen.
#
# Usage: tests/interactive.py [--es] word [word...]

import fcntl
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import time

DEFINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "define")
ESCAPES = re.compile(rb"\x1b\[[0-9;?<>=$]*[a-zA-Z]|\x1b[=>]|\r")


def main():
    flags = [arg for arg in sys.argv[1:] if arg.startswith("--")]
    words = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    if not words:
        sys.exit(__doc__ or "usage: tests/interactive.py [--es] word [word...]")

    pid, fd = pty.fork()
    if pid == 0:
        # gum panics without a window size, so give the child a real one.
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 100, 0, 0))
        os.environ["TERM"] = "xterm-256color"
        # Offering to install languages would stand between q and the prompt.
        os.environ["OMARCHY_DICT_NO_OFFER"] = "1"
        os.execv(DEFINE, [DEFINE, *flags])

    def read(seconds):
        output = b""
        deadline = time.time() + seconds
        while time.time() < deadline:
            if select.select([fd], [], [], 0.1)[0]:
                try:
                    output += os.read(fd, 65536)
                except OSError:
                    break
        return ESCAPES.sub(b"", output).decode(errors="replace")

    failures = 0
    read(1.5)
    for word in words:
        os.write(fd, word.encode() + b"\r")
        screen = read(5)
        if f"{word} (q to go back)" in screen:
            print(f"ok    {word}")
        else:
            print(f"FAIL  {word}: pager didn't stay open\n{screen[-800:]}")
            failures += 1
        os.write(fd, b"q")
        read(1.5)

    os.write(fd, b"\r")
    read(1)

    # An empty word should end the loop; kill define rather than hang if not.
    deadline = time.time() + 5
    while (status := os.waitpid(pid, os.WNOHANG)) == (0, 0) and time.time() < deadline:
        read(0.1)
    if status == (0, 0):
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
        print("FAIL  define didn't exit on an empty word")
        failures += 1
    elif status[1] != 0:
        print(f"FAIL  define exited with status {status[1]}")
        failures += 1

    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
