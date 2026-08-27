#!/usr/bin/env python3
"""Tile screenshots into one downscaled sheet, and print a Markdown table for the step summary.

    python3 Screenshots/contact_sheet.py --input fastlane/screenshots --output sheet.png

One image rather than 28, because a step summary has a size limit and 28 full-size PNGs would
blow through it long before anyone could look at them.
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

# ImageMagick here resolves no font by name - not Helvetica, not even a default - so a label needs
# a path to a real file. These ship with macOS; the first one present wins, and if none is the
# sheet is drawn without labels rather than not drawn at all.
FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/SFNS.ttf",
]

# "<device>-<NN>-<Screen>", with an optional _framed the renderer appends.
NAME = re.compile(r"^(?P<device>.+)-(?P<number>\d{2})-(?P<screen>.+?)(?:_framed)?$")


def font():
    return next((path for path in FONT_CANDIDATES if Path(path).exists()), None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--width", type=int, default=180)
    args = parser.parse_args()

    # Homebrew's, on the runner and locally. Not a mise tool: the only backends for it build from
    # source, which costs more per run than the sheet is worth.
    if not shutil.which("magick"):
        raise SystemExit("error: ImageMagick is not installed - `brew install imagemagick`")

    images = sorted(Path(args.input).glob("*/*.png"))
    if not images:
        raise SystemExit(f"error: no images under {args.input}")

    chosen = font()

    # -label is applied when an image is read, not after, so it goes before each path rather than
    # once at the end. Per image, because %f is the whole filename and overflows a 180px tile - the
    # row already says which locale and device, so the tile only has to say which screen.
    tiles = []
    groups = {}
    for image in images:
        matched = NAME.match(image.stem)
        device = matched.group("device") if matched else "unknown"
        screen = f"{matched.group('number')}-{matched.group('screen')}" if matched else image.stem
        groups.setdefault((image.parent.name, device), []).append(image)
        if chosen:
            tiles += ["-label", screen]
        tiles.append(str(image))

    subprocess.run(
        ["magick", "montage",
         *(["-font", chosen, "-pointsize", "11"] if chosen else []),
         *tiles,
         "-tile", "7x", "-geometry", f"{args.width}x+6+6",
         # 8-bit because ImageMagick promotes to 16 given a 16-bit input, which doubles the sheet
         # for no visible gain at thumbnail size.
         "-background", "white", "-depth", "8", args.output],
        check=True,
    )

    print("| Locale | Device | Screens |")
    print("|---|---|---|")
    for (locale, device), files in sorted(groups.items()):
        print(f"| {locale} | {device} | {len(files)} |")


if __name__ == "__main__":
    sys.exit(main())
