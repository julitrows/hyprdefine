"""Shared test fixtures: a sandboxed home, stand-ins for the commands
hyprdefine calls, a fake dict(1) and a local web server.

Nothing here touches the network, the user's home or their dictionary server.
"""

import gzip
import hashlib
import http.server
import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
import threading
import unittest
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HYPRDEFINE = os.path.join(REPO, "bin", "hyprdefine")
LIB = os.path.join(REPO, "lib", "hyprdefine")

# A stand-in for dict(1), answering from the JSON file in HYPRDEFINE_TEST_DICT:
#   {"servers": {"localhost:2629": {"es-es": {"casa": "..."}}, "dict.org:2628": {...}},
#    "matches": {"wrod": ["word"]}}
# Unknown servers exit 41 (no connection), unknown databases 39, and missing
# words 20, as dict does. Every query is appended to HYPRDEFINE_TEST_DICT_LOG.
FAKE_DICT = r'''#!/usr/bin/env python3
import json, os, sys
args, host, port, db, match, words = sys.argv[1:], "dict.org", "2628", None, False, []
while args:
    arg = args.pop(0)
    if arg == "-h": host = args.pop(0)
    elif arg == "-p": port = args.pop(0)
    elif arg == "-d": db = args.pop(0)
    elif arg == "-m": match = True
    elif arg == "-s": args.pop(0)
    elif arg == "--": words = args; break
    else: words.append(arg)
word = " ".join(words)
fixture = json.load(open(os.environ["HYPRDEFINE_TEST_DICT"]))
with open(os.environ["HYPRDEFINE_TEST_DICT_LOG"], "a") as log:
    log.write(f"{host}:{port} {db or '*'} {'match ' if match else ''}{word}\n")
server = fixture["servers"].get(f"{host}:{port}")
if server is None:
    sys.exit(41)
if match:
    found = fixture.get("matches", {}).get(word)
    if not found:
        sys.exit(20)
    print("\n".join(found))
    sys.exit(0)
databases = [db] if db else list(server)
if db and db not in server:
    sys.exit(39)
entries = [server[d][word.lower()] for d in databases if word.lower() in server[d]]
if not entries:
    sys.exit(20)
print(f"{len(entries)} definitions found\n")
print("\n".join(entries))
'''

# Record each call, so tests can check what was run.
RECORDER = """#!/bin/sh
echo "$(basename "$0") $*" >>"$HYPRDEFINE_TEST_CALLS"
"""

WL_PASTE = """#!/bin/sh
printf '%s' "$FAKE_SELECTION"
"""


def entry(database, word, text):
    """A dict-style entry, as the fake dict prints it."""
    return f"From Test dictionary [{database}]:\n\n  {word}\n        {text}\n"


def wiktionary_entry(*definitions, part="Noun"):
    """One language's entries in English Wiktionary's definition API."""
    return [{"partOfSpeech": part, "language": "Test",
             "definitions": [{"definition": d} for d in definitions]}]


def b64_number(number):
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    digits = ""
    while True:
        digits = alphabet[number % 64] + digits
        number //= 64
        if not number:
            return digits


def reader_dict_zip(entries):
    """A reader.dict-style download: a gzipped .dict of HTML entries and an
    .index of base64 offsets, zipped."""
    data, index = b"", ["00-database-short\tA\tA"]
    for headword, html in entries.items():
        encoded = html.encode()
        index.append(f"{headword}\t{b64_number(len(data))}\t{b64_number(len(encoded))}")
        data += encoded
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, "w") as zf:
        zf.writestr("test.dict.dz", gzip.compress(data))
        zf.writestr("test.index", "\n".join(index) + "\n")
    return archive.getvalue()


def freedict_release(name):
    """A FreeDict dictd release: a .tar.xz holding <name>/<name>.{dict.dz,index}."""
    archive = io.BytesIO()
    with tarfile.open(fileobj=archive, mode="w:xz") as tar:
        for suffix, content in ((".dict.dz", gzip.compress(b"translation")), (".index", b"x\tA\tB\n")):
            info = tarfile.TarInfo(f"{name}/{name}{suffix}")
            info.size = len(content)
            tar.addfile(info, io.BytesIO(content))
    return archive.getvalue()


class WebServer:
    """Serves a dict of path -> bytes on localhost, 404 for anything else."""

    def __init__(self):
        self.routes = {}
        routes = self.routes

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                body = routes.get(self.path)
                self.send_response(200 if body is not None else 404)
                self.end_headers()
                if body is not None:
                    self.wfile.write(body)

            def log_message(self, *args):
                pass

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class Sandbox(unittest.TestCase):
    """A test case with a scratch home, stand-in commands on PATH, a fake
    dict and a local web server for Wiktionary, reader.dict and FreeDict."""

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="hyprdefine-test-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.home = os.path.join(self.root, "home")
        self.bin = os.path.join(self.root, "bin")
        os.makedirs(os.path.join(self.home, ".config", "hypr"))
        os.makedirs(self.bin)
        self.calls = os.path.join(self.root, "calls")
        self.dict_log = os.path.join(self.root, "dict.log")
        self.dict_fixture = os.path.join(self.root, "dict.json")
        open(self.calls, "w").close()
        open(self.dict_log, "w").close()

        self.write_script("dict", FAKE_DICT)
        self.write_script("wl-paste", WL_PASTE)
        for name in ("systemctl", "notify-send", "hyprctl"):
            self.write_script(name, RECORDER)

        self.web = WebServer()
        self.addCleanup(self.web.close)
        self.wiktionary = {}
        self.servers = {"dict.org:2628": {}}
        self.matches = {}

    def write_script(self, name, content):
        path = os.path.join(self.bin, name)
        with open(path, "w") as script:
            script.write(content)
        os.chmod(path, 0o755)

    def path(self, *parts):
        return os.path.join(self.home, *parts)

    def write(self, relative, content):
        path = self.path(relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as out:
            out.write(content)
        return path

    def read(self, relative):
        with open(self.path(relative)) as f:
            return f.read()

    def install_state(self, languages="", declined=""):
        self.write(".config/hyprdefine/languages", languages + "\n")
        self.write(".config/hyprdefine/declined", declined + "\n")

    def local_server(self, databases):
        """Pretend the user's dictd is running with these databases."""
        self.servers["localhost:2629"] = databases

    def env(self, **extra):
        for word, languages in self.wiktionary.items():
            self.web.routes[f"/definition/{word}"] = json.dumps(languages).encode()
        with open(self.dict_fixture, "w") as f:
            json.dump({"servers": self.servers, "matches": self.matches}, f)

        env = {
            "HOME": self.home,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "LANG": "C.UTF-8",
            "TERM": "xterm-256color",
            "HYPRDEFINE_TEST_CALLS": self.calls,
            "HYPRDEFINE_TEST_DICT": self.dict_fixture,
            "HYPRDEFINE_TEST_DICT_LOG": self.dict_log,
            "HYPRDEFINE_WIKTIONARY_URL": f"{self.web.url}/definition/",
            "HYPRDEFINE_READER_URL": f"{self.web.url}/reader",
            "HYPRDEFINE_FREEDICT_URL": f"{self.web.url}/freedict.json",
            "HYPRDEFINE_GCIDE": os.path.join(self.root, "gcide"),
            "HYPRDEFINE_NO_OFFER": "1",
        }
        env.update(extra)
        return env

    def run_hyprdefine(self, *args, check=True, **env):
        result = subprocess.run([HYPRDEFINE, *args], env=self.env(**env), capture_output=True,
                                text=True, timeout=120, stdin=subprocess.DEVNULL)
        if check and result.returncode != 0:
            self.fail(f"hyprdefine {' '.join(args)} exited {result.returncode}:\n"
                      f"{result.stdout}\n{result.stderr}")
        return result

    def recorded(self, command):
        with open(self.calls) as f:
            return [line.split(" ", 1)[1].strip() for line in f if line.startswith(command + " ")]

    def dict_queries(self):
        with open(self.dict_log) as f:
            return [line.strip() for line in f]

    def serve_reader_dict(self, code, entries):
        self.web.routes[f"/reader/{code}/dictorg-{code}-{code}-noetym.zip"] = reader_dict_zip(entries)

    def serve_freedict(self, *names, corrupt=()):
        """Publish FreeDict releases and a catalogue listing them. Names in
        corrupt get a checksum that doesn't match."""
        catalogue = []
        for name in names:
            release = freedict_release(name)
            path = f"/freedict/{name}.dictd.tar.xz"
            self.web.routes[path] = release
            checksum = hashlib.sha512(b"wrong" if name in corrupt else release).hexdigest()
            catalogue.append({"name": name, "releases": [
                {"platform": "dictd", "URL": self.web.url + path, "checksum": checksum, "date": "2025-01-01"},
                {"platform": "stardict", "URL": "unused", "checksum": "", "date": "2026-01-01"},
            ]})
        self.web.routes["/freedict.json"] = json.dumps(catalogue).encode()
