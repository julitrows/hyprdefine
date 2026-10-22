#!/usr/bin/env python3

# Convert one of reader.dict's DICT.org downloads into dictfmt -f input.
#
# The download stores each definition as a single line of HTML and its index
# isn't sorted the way dictd searches, so lookups miss and long entries come
# back cut off. Rendering the entries as wrapped plain text and letting dictfmt
# write a fresh index fixes both.
#
# Usage: reader-dict.py dictorg-fr-fr-noetym.zip | dictfmt -f --utf8 ... fr-fr

import gzip
import sys
import textwrap
import zipfile
from html.parser import HTMLParser

B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
INDENT = " " * 8
WIDTH = 78


def b64_number(text):
    number = 0
    for char in text:
        number = number * 64 + B64.index(char)
    return number


class Renderer(HTMLParser):
    """Render a definition's HTML as indented plain text with numbered senses."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.lines = []
        self.text = ""
        self.lists = []  # one [style, counter, numbered] per open <ol>
        self.skip = 0  # depth inside <svg>, whose contents are drawings

    def flush(self):
        text = " ".join(self.text.split())
        self.text = ""
        if not text:
            return

        depth = max(len(self.lists) - 1, 0)
        label = ""
        numbered = True
        if self.lists and self.lists[-1][1] > 0:
            style, counter, numbered = self.lists[-1]
            label = (f"{chr(96 + counter)})" if style == "alpha" else f"{counter}.") + " "
            self.lists[-1][2] = True

        # Only an item's first chunk of text carries its number; later chunks,
        # such as text after a line break or a nested list, line up under it.
        rest = INDENT + "  " * depth + " " * len(label)
        first = rest if numbered else INDENT + "  " * depth + label
        self.lines += textwrap.wrap(text, WIDTH, initial_indent=first, subsequent_indent=rest)

    def handle_starttag(self, tag, attrs):
        if tag == "svg":
            self.skip += 1
        elif tag == "ol":
            self.flush()
            style = dict(attrs).get("style") or ""
            self.lists.append(["alpha" if "alpha" in style else "number", 0, True])
        elif tag == "li":
            self.flush()
            if self.lists:
                self.lists[-1][1] += 1
                self.lists[-1][2] = False
        elif tag == "p":
            self.flush()

    def handle_endtag(self, tag):
        if tag == "svg":
            self.skip -= 1
        elif tag == "ol":
            self.flush()
            if self.lists:
                self.lists.pop()
        elif tag in ("li", "p"):
            self.flush()

    def handle_data(self, data):
        if not self.skip:
            self.text += data

    def render(self, html):
        self.feed(html.replace("\n", "<p>"))
        self.close()
        self.flush()
        return self.lines


def entries(archive):
    with zipfile.ZipFile(archive) as zf:
        names = zf.namelist()
        index = next(n for n in names if n.endswith(".index"))
        data = next(n for n in names if n.endswith(".dict.dz"))
        with zf.open(data) as raw:
            text = gzip.decompress(raw.read())
        for line in zf.read(index).decode("utf-8").splitlines():
            headword, offset, length = line.split("\t")[:3]
            if headword.startswith("00-database"):
                continue
            start = b64_number(offset)
            yield headword, text[start : start + b64_number(length)].decode("utf-8")


def main():
    out = sys.stdout
    # dictfmt -f takes the first two lines starting in column 0 as the
    # database's info, not as headwords, so give it two.
    out.write("Wiktionary, converted from reader.dict's download by hyprdefine.\n")
    out.write("https://www.reader-dict.com\n")
    for headword, html in entries(sys.argv[1]):
        lines = Renderer().render(html)
        if lines:
            out.write(headword + "\n" + "\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
