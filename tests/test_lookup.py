"""One-shot lookups: which sources are asked, and what's shown."""

import re
import unittest

from support import Sandbox, entry, wiktionary_entry


def headings(output):
    """The language headings in a lookup, in order."""
    lines = output.splitlines()
    return [lines[i] for i in range(len(lines) - 1) if re.fullmatch("═+", lines[i + 1])]


class LookupTest(Sandbox):
    def setUp(self):
        super().setUp()
        self.servers["dict.org:2628"] = {
            "gcide": {"casa": entry("gcide", "casa", "A house."), "house": entry("gcide", "house", "A building.")},
            "wn": {"house": entry("wn", "house", "a dwelling")},
            "moby-thesaurus": {},
            "fd-spa-eng": {"casa": entry("fd-spa-eng", "casa", "house")},
        }
        self.wiktionary["casa"] = {
            "en": wiktionary_entry("A surname."),
            "es": wiktionary_entry("house"),
            "it": wiktionary_entry("house"),
            "pt": wiktionary_entry("house"),
            "ast": wiktionary_entry("house"),  # not a supported language
        }

    def test_with_nothing_installed_every_language_is_shown(self):
        output = self.run_hyprdefine("casa").stdout
        self.assertEqual(headings(output), ["English", "Español", "Italiano", "Português"])
        self.assertIn("A house.", output)
        self.assertNotIn("Also in", output)

    def test_an_installed_language_narrows_the_rest_to_also_in(self):
        self.install_state("en es")
        self.local_server({"es-es": {"casa": entry("es-es", "casa", "Edificio para habitar.")},
                           "eng-spa": {}, "spa-eng": {}})
        output = self.run_hyprdefine("casa").stdout
        self.assertEqual(headings(output), ["English", "Español"])
        self.assertIn("Edificio para habitar.", output)
        self.assertNotIn("From Wiktionary", output)
        self.assertTrue(output.rstrip().endswith("Also in: Italiano, Português"))

    def test_a_word_only_in_other_languages_shows_them(self):
        self.install_state("en es")
        self.local_server({"es-es": {}, "eng-spa": {}, "spa-eng": {}})
        self.wiktionary["haus"] = {"en": wiktionary_entry("A surname."), "de": wiktionary_entry("house, building")}
        output = self.run_hyprdefine("haus").stdout
        self.assertEqual(headings(output), [], "one language needs no heading")
        self.assertIn("house, building", output)
        self.assertNotIn("Also in", output)

    def test_english_ignores_wiktionary(self):
        self.wiktionary["smith"] = {"en": wiktionary_entry("A surname.")}
        output = self.run_hyprdefine("smith").stdout
        self.assertIn('No definitions found for "smith"', output)

    def test_one_language(self):
        output = self.run_hyprdefine("--it", "casa").stdout
        self.assertEqual(headings(output), [])
        self.assertIn("From Wiktionary, in English", output)
        self.assertNotIn("A house.", output)

    def test_an_installed_language_is_searched_locally_first(self):
        self.install_state("en es")
        self.local_server({"gcide": {"casa": entry("gcide", "casa", "Local GCIDE.")},
                           "es-es": {"casa": entry("es-es", "casa", "Edificio.")},
                           "eng-spa": {}})  # spa-eng is missing locally
        output = self.run_hyprdefine("casa").stdout
        queries = self.dict_queries()

        self.assertIn("Local GCIDE.", output)
        self.assertNotIn("dict.org:2628 gcide casa", queries, "a local match mustn't go to dict.org")
        self.assertNotIn("dict.org:2628 fd-eng-spa casa", queries, "a local miss mustn't either")
        self.assertIn("dict.org:2628 fd-spa-eng casa", queries, "a missing local database should")
        self.assertIn("house", output)

    def test_an_installed_language_finds_the_word_with_its_marks(self):
        self.install_state("en es")
        self.local_server({"es-es": {"tropelía": entry("es-es", "tropelía", "Atropello, abuso.")},
                           "eng-spa": {}, "spa-eng": {"tropelía": entry("spa-eng", "tropelía", "outrage")}})
        self.wiktionary["tropelia"] = {"pt": wiktionary_entry("outrage")}
        output = self.run_hyprdefine("tropelia").stdout
        self.assertIn("Atropello, abuso.", output)
        self.assertIn("outrage", output, "translations are searched for the marked word too")
        self.assertTrue(output.rstrip().endswith("Also in: Português"))

    def test_marks_are_matched_either_way_and_ignore_case(self):
        self.install_state("es")
        self.local_server({"es-es": {"cigüeña": entry("es-es", "cigüeña", "Ave zancuda.")}, "spa-eng": {}})
        self.assertIn("Ave zancuda.", self.run_hyprdefine("--es", "CIGÜENA").stdout)

    def test_an_exact_match_isnt_searched_again(self):
        self.install_state("es")
        self.local_server({"es-es": {"arbol": entry("es-es", "arbol", "Misspelling."),
                                     "árbol": entry("es-es", "árbol", "Planta.")}, "spa-eng": {}})
        output = self.run_hyprdefine("--es", "arbol").stdout
        self.assertNotIn("Planta.", output)
        self.assertFalse([q for q in self.dict_queries() if " match " in q])

    def test_other_marks_are_literal(self):
        self.install_state("es")
        self.local_server({"es-es": {"axb": entry("es-es", "axb", "Wrong.")}, "spa-eng": {}})
        self.assertNotIn("Wrong.", self.run_hyprdefine("--es", "a.b").stdout)

    def test_without_a_local_server_everything_goes_to_dict_org(self):
        self.install_state("en")
        output = self.run_hyprdefine("house").stdout
        self.assertIn("A building.", output)
        self.assertIn("a dwelling", output)

    def test_translations_join_every_installed_pair(self):
        self.install_state("en es fr")
        self.local_server({})
        self.run_hyprdefine("casa")
        databases = {line.split()[1] for line in self.dict_queries() if line.startswith("localhost")}
        for pair in ("eng-spa", "eng-fra", "spa-eng", "spa-fra", "fra-eng", "fra-spa"):
            self.assertIn(pair, databases)
        self.assertNotIn("fra-fra", databases)

    def test_uninstalled_languages_have_no_translations(self):
        self.run_hyprdefine("casa")
        self.assertFalse([q for q in self.dict_queries() if "fd-" in q])

    def test_a_miss_suggests_spellings(self):
        self.matches["huose"] = ["house", "hose"]
        output = self.run_hyprdefine("huose").stdout
        self.assertIn('No definitions found for "huose"', output)
        self.assertIn("Perhaps you mean:\nhouse\nhose", output)

    def test_a_multi_word_lookup_is_one_query(self):
        self.servers["dict.org:2628"]["gcide"]["ice cream"] = entry("gcide", "ice cream", "A frozen dessert.")
        self.assertIn("A frozen dessert.", self.run_hyprdefine("ice", "cream").stdout)

    def test_unknown_options_are_rejected(self):
        result = self.run_hyprdefine("--xx", "casa", check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("unknown option --xx", result.stderr)

    def test_help(self):
        self.assertIn("hyprdefine --setup", self.run_hyprdefine("--help").stdout)


if __name__ == "__main__":
    unittest.main()
