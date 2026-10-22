"""The Python helpers in lib/hyprdefine, tested directly."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

from support import LIB, WebServer, b64_number, reader_dict_zip, wiktionary_entry


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), os.path.join(LIB, name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ReaderDictTest(unittest.TestCase):
    converter = load("reader-dict")

    def render(self, html):
        return self.converter.Renderer().render(html)

    def test_base64_numbers(self):
        for number in (0, 1, 63, 64, 4095, 123456):
            self.assertEqual(self.converter.b64_number(b64_number(number)), number)

    def test_numbered_senses(self):
        self.assertEqual(self.render("<ol><li>One.</li><li>Two.</li></ol>"),
                         ["        1. One.", "        2. Two."])

    def test_lettered_sub_senses(self):
        lines = self.render('<ol><li>Main.<ol style="list-style-type:lower-alpha"><li>Sub.</li></ol></li></ol>')
        self.assertEqual(lines, ["        1. Main.", "          a) Sub."])

    def test_long_senses_wrap_under_their_text(self):
        lines = self.render("<ol><li>" + "word " * 30 + "</li></ol>")
        self.assertTrue(all(len(line) <= 78 for line in lines))
        self.assertTrue(lines[1].startswith(" " * 11 + "word"))

    def test_drawings_are_skipped(self):
        self.assertEqual(self.render("<p>Text<svg><text>drawing</text></svg></p>"), ["        Text"])

    def test_entries_skip_database_metadata(self):
        with tempfile.NamedTemporaryFile(suffix=".zip") as archive:
            archive.write(reader_dict_zip({"casa": "<p>House</p>", "árbol": "<p>Tree</p>"}))
            archive.flush()
            self.assertEqual(list(self.converter.entries(archive.name)),
                             [("casa", "<p>House</p>"), ("árbol", "<p>Tree</p>")])

    def test_output_starts_with_two_header_lines_for_dictfmt(self):
        with tempfile.NamedTemporaryFile(suffix=".zip") as archive:
            archive.write(reader_dict_zip({"casa": "<p>House</p>"}))
            archive.flush()
            output = subprocess.run([sys.executable, "-I", os.path.join(LIB, "reader-dict.py"), archive.name],
                                    capture_output=True, text=True, check=True).stdout
        lines = output.splitlines()
        self.assertFalse(lines[0].startswith(" ") or lines[1].startswith(" "))
        self.assertEqual(lines[2:], ["casa", "        House"])


class WiktionaryTest(unittest.TestCase):
    wiktionary = load("wiktionary")

    def setUp(self):
        self.web = WebServer()
        self.addCleanup(self.web.close)
        self.output = tempfile.mkdtemp()

    def lookup(self, word, found):
        if found is not None:
            self.web.routes[f"/{word}"] = json.dumps(found).encode()
        env = dict(os.environ, HYPRDEFINE_WIKTIONARY_URL=self.web.url + "/")
        result = subprocess.run([sys.executable, "-I", os.path.join(LIB, "wiktionary.py"), word,
                                 os.path.join(LIB, "languages"), self.output], env=env)
        files = {}
        for code in sorted(os.listdir(self.output)):
            with open(os.path.join(self.output, code)) as f:
                files[code] = f.read()
        return result.returncode, files

    def test_one_file_per_supported_language(self):
        status, files = self.lookup("casa", {"es": wiktionary_entry("house"), "ast": wiktionary_entry("house")})
        self.assertEqual(status, 0)
        self.assertEqual(list(files), ["es"])
        self.assertEqual(files["es"], "From Wiktionary, in English [en.wiktionary.org]:\n\n"
                                      "  casa\n        Noun\n        1. house\n")

    def test_norwegian_variants_count_as_norwegian(self):
        _, files = self.lookup("hus", {"nb": wiktionary_entry("house"), "nn": wiktionary_entry("home")})
        self.assertEqual(list(files), ["no"])
        self.assertIn("house", files["no"])
        self.assertIn("home", files["no"])

    def test_html_and_nested_lists_are_stripped(self):
        _, files = self.lookup("casa", {"es": wiktionary_entry(
            'inflection of <a href="x">casar</a>:<ol><li>third-person</li></ol>', "&quot;quoted&quot;")})
        self.assertIn("1. inflection of casar:\n", files["es"])
        self.assertNotIn("third-person", files["es"])
        self.assertIn('2. "quoted"', files["es"])

    def test_languages_without_definitions_are_left_out(self):
        _, files = self.lookup("x", {"es": wiktionary_entry("")})
        self.assertEqual(files, {})

    def test_a_missing_word_fails_quietly(self):
        status, files = self.lookup("missing", None)  # the server answers 404
        self.assertEqual((status, files), (1, {}))


class FreeDictTest(unittest.TestCase):
    def test_prints_the_latest_dictd_release_of_each_named_dictionary(self):
        catalogue = [
            {"name": "eng-spa", "releases": [
                {"platform": "dictd", "URL": "old", "checksum": "a", "date": "2019-01-01"},
                {"platform": "dictd", "URL": "new", "checksum": "b", "date": "2025-01-01"},
                {"platform": "stardict", "URL": "other", "checksum": "c", "date": "2026-01-01"}]},
            {"name": "spa-eng", "releases": [{"platform": "slob", "URL": "x", "checksum": "d", "date": "2025-01-01"}]},
            {"name": "deu-eng", "releases": [{"platform": "dictd", "URL": "y", "checksum": "e", "date": "2025-01-01"}]},
            {"software": {}},
        ]
        with tempfile.NamedTemporaryFile("w", suffix=".json") as f:
            json.dump(catalogue, f)
            f.flush()
            output = subprocess.run([sys.executable, "-I", os.path.join(LIB, "freedict.py"), f.name,
                                     "eng-spa", "spa-eng", "fra-eng"], capture_output=True, text=True, check=True).stdout
        self.assertEqual(output, "eng-spa new b\n")


class LanguagesTest(unittest.TestCase):
    def test_the_catalogue_is_well_formed(self):
        with open(os.path.join(LIB, "languages")) as f:
            rows = [line.split(maxsplit=2) for line in f if line.strip() and not line.startswith("#")]
        codes = [row[0] for row in rows]
        self.assertEqual(codes[0], "en", "English comes first")
        self.assertEqual(codes[1:], sorted(codes[1:]))
        self.assertEqual(len(codes), len(set(codes)))
        for code, freedict, name in rows:
            self.assertRegex(code, "^[a-z]{2}$")
            self.assertRegex(freedict, "^[a-z]{3}$")
            self.assertTrue(name.strip())


if __name__ == "__main__":
    unittest.main()
