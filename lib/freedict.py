#!/usr/bin/env python3

# Print the dictd download of each named FreeDict dictionary that has one, as
# "<name> <url> <sha512>" lines, from FreeDict's catalogue
# (https://freedict.org/freedict-database.json).
#
# Usage: freedict.py <catalogue.json> <name>...   # names like eng-spa

import json
import sys


def main():
    with open(sys.argv[1], encoding="utf-8") as catalogue:
        entries = json.load(catalogue)
    wanted = set(sys.argv[2:])

    for entry in entries:
        name = entry.get("name")
        if name not in wanted:
            continue
        releases = [r for r in entry.get("releases", []) if r.get("platform") == "dictd"]
        if releases:
            latest = max(releases, key=lambda r: r.get("date", ""))
            print(name, latest["URL"], latest["checksum"])


if __name__ == "__main__":
    main()
