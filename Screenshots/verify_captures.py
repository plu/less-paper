#!/usr/bin/env python3
"""Check the captures match the Snapfile's matrix, and drop anything that does not belong.

    python3 Screenshots/verify_captures.py

capture_screenshots clears the captures before it runs and does not fail the lane when the build
beneath it fails, so an empty directory and a successful run look identical. It has also been seen
to leave a set for a device that is not in the Snapfile at all - which would be framed and uploaded
as a size App Store Connect was never asked for.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAPTURES = ROOT / "Screenshots" / "Captures"
SNAPFILE = ROOT / "fastlane" / "Snapfile"

SCREENS = 7

# "<device>-<NN>-<Screen>.png"
NAME = re.compile(r"^(?P<device>.+)-(?P<number>\d{2})-(?P<screen>.+)$")


def matrix():
    """The devices and languages the Snapfile actually asks for, so the two cannot drift."""
    text = SNAPFILE.read_text(encoding="utf-8")

    def block(name):
        match = re.search(rf"{name}\(\[(.*?)\]\)", text, re.DOTALL)
        if not match:
            raise SystemExit(f"error: no {name}([...]) in {SNAPFILE}")
        return re.findall(r'"([^"]+)"', match.group(1))

    return block("devices"), block("languages")


def main():
    devices, languages = matrix()
    expected = len(devices) * len(languages) * SCREENS

    strays = []
    counts = {}
    for image in sorted(CAPTURES.glob("*/*.png")):
        locale = image.parent.name
        matched = NAME.match(image.stem)
        device = matched.group("device") if matched else None

        if locale not in languages or device not in devices:
            strays.append(image)
            continue
        counts[(locale, device)] = counts.get((locale, device), 0) + 1

    # Not ours: the Snapfile is the matrix, and anything else would be framed and uploaded as a size
    # nobody asked for. Removed rather than tolerated, and said out loud rather than done quietly.
    for stray in strays:
        print(f"removing stray capture: {stray.relative_to(ROOT)}")
        stray.unlink()

    problems = []
    for locale in languages:
        for device in devices:
            found = counts.get((locale, device), 0)
            if found != SCREENS:
                problems.append(f"{locale} / {device}: expected {SCREENS} screens, found {found}")

    for locale, device in sorted(counts):
        print(f"{locale}  {device}: {counts[(locale, device)]}")

    if problems:
        print()
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        raise SystemExit(1)

    print(f"\n{expected} captures, matching the Snapfile.")


if __name__ == "__main__":
    main()
