#!/usr/bin/env python3
"""Check the App Store listing text against Apple's field limits.

    python3 fastlane/metadata_lint.py

deliver only finds out what Apple rejects by trying to upload, and its own verify_only needs a
binary to hash. These limits are published and stable, so checking them here catches the whole
class of "too long" before anything is sent.
"""

import sys
from pathlib import Path

METADATA = Path(__file__).resolve().parent / "metadata"

# https://developer.apple.com/help/app-store-connect/reference/app-information
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional_text": 170,
    "description": 4000,
    "release_notes": 4000,
}

# Apple rejects a listing with no description, and a name is the one field with no default.
REQUIRED = ["name", "description"]


def locales():
    return sorted(p for p in METADATA.iterdir() if p.is_dir() and "-" in p.name)


def main():
    if not METADATA.is_dir():
        raise SystemExit("error: no fastlane/metadata - run `mise run metadata:download`")

    problems = []
    for locale in locales():
        for field, limit in LIMITS.items():
            path = locale / f"{field}.txt"
            if not path.exists():
                if field in REQUIRED:
                    problems.append(f"{locale.name}/{field}.txt is missing")
                continue

            # deliver writes a lone newline for an empty field, which is not the same as absent.
            text = path.read_text(encoding="utf-8").strip()
            if not text:
                if field in REQUIRED:
                    problems.append(f"{locale.name}/{field}.txt is empty")
                continue

            if len(text) > limit:
                problems.append(
                    f"{locale.name}/{field}.txt is {len(text)} characters, limit is {limit}"
                )

        # release_notes.txt is rendered from changelogs/<version>.txt at upload time and is not
        # committed, so checking only that file would check nothing on a pull request. Every
        # version's notes are held to the same limit instead.
        changelogs = sorted((locale / "changelogs").glob("*.txt"))
        for path in changelogs:
            text = path.read_text(encoding="utf-8").strip()
            if not text:
                problems.append(f"{locale.name}/changelogs/{path.name} is empty")
            elif len(text) > LIMITS["release_notes"]:
                problems.append(
                    f"{locale.name}/changelogs/{path.name} is {len(text)} characters, "
                    f"limit is {LIMITS['release_notes']}"
                )

        print(f"{locale.name}: checked {len(LIMITS)} fields, {len(changelogs)} changelogs")

    # Every locale carries every version. A changelog written in one language and not the other is
    # invisible until release day, when metadata:release-notes refuses the version - this turns
    # that into a red pull request instead.
    versions_by_locale = {
        locale.name: {p.stem for p in (locale / "changelogs").glob("*.txt")}
        for locale in locales()
    }
    every_version = set().union(*versions_by_locale.values()) if versions_by_locale else set()
    for name, versions in sorted(versions_by_locale.items()):
        for missing in sorted(every_version - versions):
            problems.append(f"{name}/changelogs/{missing}.txt is missing - every locale needs every version")

    if problems:
        print()
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        raise SystemExit(1)

    print("\nEvery field is within Apple's limits.")


if __name__ == "__main__":
    main()
