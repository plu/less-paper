#!/usr/bin/env python3
"""Remove blank lines between an attribute and the declaration it applies to.

Turns this:

    @Shared

    var correspondents: IdentifiedArrayOf<Correspondent>

into this:

    @Shared
    var correspondents: IdentifiedArrayOf<Correspondent>

Neither swiftformat nor swiftlint covers this. swiftformat's wrapAttributes only
decides whether an attribute sits on its own line — it already is here, so the rule
considers the code correct. swiftlint's `attributes` rule would move the attribute
onto the *same* line as the variable, which contradicts this codebase's style.

Usage:
    attribute_blank_lines.py [--check] [PATH ...]

    --check  report offending sites and exit non-zero instead of rewriting
"""

import argparse
import pathlib
import re
import sys

# A whole line that is nothing but one attribute, optionally with arguments that
# open and close on that same line. A multi-line attribute ends on a different
# line, so it is deliberately left alone.
ATTRIBUTE = re.compile(r"^\s*@[A-Za-z_][A-Za-z0-9_]*(\(.*\))?\s*$")

# The start of the declaration an attribute can apply to. Another attribute counts
# too, so a stack of them collapses in one pass.
DECLARATION = re.compile(
    r"^\s*(?:(?:public|internal|private|fileprivate|open|static|final|lazy|weak|unowned|override|nonisolated|indirect)\s+)*"
    r"(?:@|var|let|func|init|deinit|subscript|case|struct|class|enum|actor|extension|protocol|typealias|associatedtype)\b"
)

DEFAULT_PATHS = ["Modules", "Shared"]


def offending_lines(lines):
    """Yield the indices of blank lines sitting between an attribute and its declaration."""
    for index, line in enumerate(lines):
        if not ATTRIBUTE.match(line):
            continue

        next_index = index + 1
        while next_index < len(lines) and not lines[next_index].strip():
            next_index += 1

        if next_index == index + 1 or next_index >= len(lines):
            continue

        if DECLARATION.match(lines[next_index]):
            yield from range(index + 1, next_index)


def process(path, check):
    """Return the number of blank lines removed from (or found in) one file."""
    original = path.read_text()
    lines = original.split("\n")
    blanks = set(offending_lines(lines))

    if not blanks:
        return 0

    if check:
        for index in sorted(blanks):
            print(f"{path}:{index + 1}: blank line between an attribute and its declaration")
        return len(blanks)

    kept = [line for index, line in enumerate(lines) if index not in blanks]
    path.write_text("\n".join(kept))
    return len(blanks)


def swift_files(paths):
    for raw in paths:
        path = pathlib.Path(raw)
        if path.is_dir():
            yield from sorted(path.rglob("*.swift"))
        elif path.suffix == ".swift":
            yield path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report instead of rewriting")
    parser.add_argument("paths", nargs="*", default=DEFAULT_PATHS)
    arguments = parser.parse_args()

    total = 0
    files = 0
    for path in swift_files(arguments.paths or DEFAULT_PATHS):
        removed = process(path, arguments.check)
        if removed:
            total += removed
            files += 1

    if not total:
        return 0

    if arguments.check:
        print(f"\n{total} blank line(s) after attributes in {files} file(s). Run `mise format` to fix.")
        return 1

    print(f"Removed {total} blank line(s) after attributes in {files} file(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
