"""Checks the listing copy in `docs/store/listing.md` against the channels' limits.

A store form truncates or refuses silently enough that a description one
character over is a thing you discover by pasting it. The limits are the
TIGHTEST any channel imposes -- see the file's own header -- so copy that
passes here passes everywhere. This reads the fenced
blocks out of the listing file and fails if any is over.

Counted in CHARACTERS, not bytes, which is the whole reason this is a script
rather than `wc -c`. The Turkish copy is full of `ı`, `ş`, `ğ` and `ç`; each
is two bytes in UTF-8, so a byte count reports the Turkish short description
at 84 of an allowed 80 and rejects copy the console takes happily.

Both languages must be present and every field non-empty: a listing with an
English full description and no Turkish one publishes, and shows English to
Turkish users, which is worse than failing here.

    python3 tool/check_listing.py docs/store/listing.md
"""

from __future__ import annotations

import os
import re
import sys

# The tightest published limits across the channels, per language.
LIMITS = {"Title": 30, "Short description": 80, "Full description": 4000}

path = os.path.abspath(sys.argv[1] if len(sys.argv) == 2 else "docs/store/listing.md")
text = open(path, encoding="utf-8").read()

# `### <field> (N max)` followed by a fenced block. The Turkish headings are
# in Turkish, so match on the limit that follows rather than on the wording.
pattern = re.compile(
    r"^##\s+(?P<lang>.+?)$(?P<body>.*?)(?=^##\s|\Z)",
    re.MULTILINE | re.DOTALL,
)
field = re.compile(
    r"^###\s+(?P<name>.+?)\s+\((?P<max>\d+) max\)\s*$\s*```\s*$(?P<value>.*?)^```\s*$",
    re.MULTILINE | re.DOTALL,
)

languages = {}
for section in pattern.finditer(text):
    language = section.group("lang").strip()
    if language.startswith(("What ", "The console", "Assets")):
        continue
    found = {}
    for item in field.finditer(section.group("body")):
        found[item.group("name")] = (item.group("value").strip(), int(item.group("max")))
    if found:
        languages[language] = found

if not languages:
    raise SystemExit(f"{path}: no language sections with fenced fields found")

failures = []
for language, fields in sorted(languages.items()):
    print(f"{language}")
    for name, limit in LIMITS.items():
        match = next((k for k in fields if k.split(" (")[0] == name), None)
        # The Turkish headings are Turkish; fall back to position via the limit.
        if match is None:
            match = next((k for k, (_, m) in fields.items() if m == limit), None)
        if match is None:
            failures.append(f"{language}: no field with a {limit}-character limit")
            print(f"  {name:20s} MISSING")
            continue
        value, declared = fields[match]
        if declared != limit:
            failures.append(
                f"{language}/{match}: heading says {declared} max, the limit is {limit}"
            )
        count = len(value)
        state = "ok"
        if not value:
            failures.append(f"{language}/{match}: empty")
            state = "EMPTY"
        elif count > limit:
            failures.append(f"{language}/{match}: {count} characters, {count - limit} over {limit}")
            state = f"OVER BY {count - limit}"
        print(
            f"  {match:20s} {count:5d}/{limit}  {len(value.encode('utf-8')):5d} bytes  {state}"
        )

if len(languages) < 2:
    failures.append(
        f"only {len(languages)} language section; a listing needs one per locale"
    )

if failures:
    print()
    for line in failures:
        print(f"FAIL  {line}")
    raise SystemExit(1)

print(f"\n{len(languages)} languages, every field within the limits.")
