"""Installing, removing and declining languages, against a local web server
standing in for reader.dict and FreeDict. dictfmt and dictzip run for real."""

import gzip
import os
import unittest

from support import Sandbox

SPANISH = {
    "casa": "<ol><li>Edificio para habitar.</li><li>Familia.</li></ol>",
    "ñandú": "<ol><li>Ave corredora sudamericana.</li></ol>",
}


class DictionariesTest(Sandbox):
    def setUp(self):
        super().setUp()
        self.serve_reader_dict("es", SPANISH)
        self.serve_reader_dict("fr", {"maison": "<ol><li>Bâtiment.</li></ol>"})
        self.serve_freedict("eng-spa", "spa-eng", "eng-fra", "fra-eng", "spa-fra", "fra-spa")
        # A stand-in for the dict-gcide package's files.
        for suffix in (".index", ".dict.dz"):
            open(os.path.join(self.root, "gcide" + suffix), "w").close()

    def dictionaries(self):
        directory = self.path(".local/share/hyprdefine/dictionaries")
        return sorted(os.listdir(directory)) if os.path.isdir(directory) else []

    def served(self):
        conf = self.read(".local/share/hyprdefine/dictd.conf")
        return [line.split()[1] for line in conf.splitlines()]

    def test_installing_builds_the_language_and_its_translations(self):
        result = self.run_hyprdefine("--install", "en", "es")
        self.assertIn("Installed English, Español.", result.stdout)
        self.assertEqual(self.read(".config/hyprdefine/languages").strip(), "en es")
        self.assertEqual(self.dictionaries(), [
            "eng-spa.dict.dz", "eng-spa.index", "es-es.dict.dz", "es-es.index",
            "spa-eng.dict.dz", "spa-eng.index"])
        self.assertEqual(self.served(), ["gcide", "eng-spa", "es-es", "spa-eng"])
        self.assertIn("--user restart hyprdefine.service", self.recorded("systemctl"))

    def test_a_built_dictionary_is_plain_text(self):
        self.run_hyprdefine("--install", "es")
        index = self.read(".local/share/hyprdefine/dictionaries/es-es.index")
        self.assertIn("casa\t", index)
        self.assertIn("ñandú\t", index)
        with gzip.open(self.path(".local/share/hyprdefine/dictionaries/es-es.dict.dz"), "rt") as data:
            text = data.read()
        self.assertIn("1. Edificio para habitar.", text)
        self.assertIn("2. Familia.", text)
        self.assertNotIn("<li>", text)

    def test_english_downloads_nothing_of_its_own(self):
        self.run_hyprdefine("--install", "en")
        self.assertEqual(self.dictionaries(), [])
        self.assertEqual(self.served(), ["gcide"])

    def test_adding_a_language_adds_its_pairs_with_every_other(self):
        self.run_hyprdefine("--install", "en", "es")
        self.run_hyprdefine("--install", "fr")
        self.assertEqual(self.read(".config/hyprdefine/languages").strip(), "en es fr")
        pairs = {name.split(".")[0] for name in self.dictionaries()}
        self.assertEqual(pairs, {"es-es", "fr-fr", "eng-spa", "spa-eng", "eng-fra", "fra-eng", "spa-fra", "fra-spa"})

    def test_removing_a_language_removes_its_files_and_pairs(self):
        self.run_hyprdefine("--install", "en", "es", "fr")
        self.assertIn("Removed Español.", self.run_hyprdefine("--remove", "es").stdout)
        self.assertEqual(self.read(".config/hyprdefine/languages").strip(), "en fr")
        pairs = {name.split(".")[0] for name in self.dictionaries()}
        self.assertEqual(pairs, {"fr-fr", "eng-fra", "fra-eng"})

    def test_removing_everything_stops_the_server(self):
        self.run_hyprdefine("--install", "es")
        self.run_hyprdefine("--remove", "es")
        self.assertEqual(self.dictionaries(), [])
        self.assertEqual(self.read(".local/share/hyprdefine/dictd.conf"), "")
        self.assertEqual(self.recorded("systemctl")[-1], "--user stop hyprdefine.service")

    def test_a_download_with_the_wrong_checksum_is_skipped(self):
        self.serve_freedict("eng-spa", "spa-eng", corrupt=("spa-eng",))
        result = self.run_hyprdefine("--install", "en", "es")
        self.assertIn("spa-eng download doesn't match its checksum", result.stderr)
        self.assertIn("eng-spa.index", self.dictionaries())
        self.assertNotIn("spa-eng.index", self.dictionaries())

    def test_a_pair_freedict_lacks_is_simply_missing(self):
        self.serve_freedict("eng-spa")
        self.run_hyprdefine("--install", "en", "es")
        self.assertNotIn("spa-eng.index", self.dictionaries())

    def test_update_rebuilds_from_the_latest_download(self):
        self.run_hyprdefine("--install", "es")
        self.serve_reader_dict("es", {"casa": "<ol><li>Vivienda.</li></ol>"})
        self.run_hyprdefine("--update")
        with gzip.open(self.path(".local/share/hyprdefine/dictionaries/es-es.dict.dz"), "rt") as data:
            self.assertIn("Vivienda.", data.read())

    def test_notify_reports_success(self):
        self.run_hyprdefine("--install", "--notify", "es")
        self.assertEqual(self.recorded("notify-send"), ["Dictionary Español installed for offline lookups."])

    def test_notify_reports_failure(self):
        result = self.run_hyprdefine("--install", "--notify", "de", check=False)  # not served
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.recorded("notify-send")[0].startswith("-u critical Dictionary Couldn't install Deutsch."))
        self.assertFalse(os.path.exists(self.path(".config/hyprdefine/languages")))

    def test_unknown_languages_are_rejected(self):
        result = self.run_hyprdefine("--install", "xx", check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn('Unknown language "xx"', result.stderr)

    def test_declining_keeps_catalogue_order_without_duplicates(self):
        self.run_hyprdefine("--decline", "it", "fr")
        self.run_hyprdefine("--decline", "de", "it")
        self.assertEqual(self.read(".config/hyprdefine/declined").strip(), "de fr it")


if __name__ == "__main__":
    unittest.main()
