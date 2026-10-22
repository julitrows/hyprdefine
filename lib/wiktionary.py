#!/usr/bin/env python3

# Look a word up on English Wiktionary and write its English meanings, one
# file per supported language that has the word, formatted like dict's output.
#
# English Wiktionary's definition API lists every language a word exists in,
# with English glosses, in one request. Other Wiktionaries have no such API,
# which is why definitions in the word's own language come from reader.dict.
#
# Usage: wiktionary.py <word> <lib/languages> <output directory>

import html
import json
import os
import re
import sys
import textwrap
import urllib.parse
import urllib.request

API = "https://en.wiktionary.org/api/rest_v1/page/definition/"
# Wikimedia asks API clients to identify themselves.
USER_AGENT = "omarchy-dict (https://github.com/julitrows/omarchy-dict)"
INDENT = " " * 8
WIDTH = 78
# Wiktionary splits some languages that omarchy-dict treats as one.
ALIASES = {"nb": "no", "nn": "no"}


def text(fragment):
    """Strip tags from a Wiktionary HTML fragment. Nested lists are dropped,
    because the API also returns their items as senses of their own."""
    fragment = re.sub(r"<(ol|ul)\b.*?</\1>", "", fragment, flags=re.S)
    return " ".join(html.unescape(re.sub(r"<[^>]+>", "", fragment)).split())


def render(word, entries):
    lines = ["From Wiktionary, in English [en.wiktionary.org]:", "", f"  {word}"]
    for entry in entries:
        senses = [text(d["definition"]) for d in entry.get("definitions", [])]
        senses = [s for s in senses if s]
        if not senses:
            continue
        lines.append(f"{INDENT}{entry.get('partOfSpeech', '')}")
        for number, sense in enumerate(senses, 1):
            lead = f"{INDENT}{number}. "
            lines += textwrap.wrap(sense, WIDTH, initial_indent=lead,
                                   subsequent_indent=" " * len(lead))
    return "\n".join(lines) + "\n"


def main():
    word, languages, output = sys.argv[1:4]
    supported = set()
    with open(languages, encoding="utf-8") as catalog:
        for line in catalog:
            if line.strip() and not line.startswith("#"):
                supported.add(line.split()[0])

    request = urllib.request.Request(API + urllib.parse.quote(word, safe=""),
                                     headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            found = json.load(response)
    except Exception:
        # Not found (404), offline or timed out: there's nothing to write.
        sys.exit(1)

    by_code = {}
    for key, entries in found.items():
        code = ALIASES.get(key, key)
        if code in supported:
            by_code.setdefault(code, []).extend(entries)

    for code, entries in by_code.items():
        rendered = render(word, entries)
        if rendered.count("\n") > 3:
            with open(os.path.join(output, code), "w", encoding="utf-8") as out:
                out.write(rendered)


if __name__ == "__main__":
    main()
