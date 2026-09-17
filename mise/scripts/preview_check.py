#!/usr/bin/env python3
"""Refuse a preview App Store Connect would refuse.

    python3 mise/scripts/preview_check.py fastlane/app_previews/en-US/01_IPHONE_67.mp4

deliver checks the resolution and nothing else, and App Store Connect only says no once the upload
has already happened. Every limit here is published and stable, so the whole class of rejection is
catchable on a laptop.
"""

import json
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

# https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications
SIZE = (886, 1920)
DURATION = (15.0, 30.0)
MAX_FPS = 30
MAX_LEVEL = 40
SAMPLE_RATES = {"44100", "48000"}
MIN_BITRATE = 192000

# There is no IPHONE_69 preview type: spaceship's enumeration stops at IPHONE_67 and maps it to
# 886x1920, which is the 6.9" size. deliver matches the type by substring, so a name without it
# uploads nothing and says nothing.
DEVICE_TYPE = "IPHONE_67"


def stream(probe, kind):
    for candidate in probe.get("streams", []):
        if candidate.get("codec_type") == kind:
            return candidate
    return None


def problems(probe, name):
    found = []

    video = stream(probe, "video")
    if not video:
        found.append("there is no video stream")
    else:
        size = (video.get("width"), video.get("height"))
        if size != SIZE:
            found.append(f"the resolution is {size[0]}x{size[1]}, and must be exactly 886x1920")

        # r_frame_rate is a rational ("30/1"), not a float.
        fps = float(Fraction(video.get("r_frame_rate", "0/1")))
        if fps > MAX_FPS:
            found.append(f"the frame rate is {fps:g}, and must be at most 30")

        if video.get("codec_name") != "h264":
            found.append(f"the video codec is {video.get('codec_name')}, and must be h264")
        if video.get("profile") != "High":
            found.append(f"the H.264 profile is {video.get('profile')}, and must be High")
        if (video.get("level") or 0) > MAX_LEVEL:
            found.append(f"the H.264 level is {video.get('level')}, and must be 4.0 or below")

    audio = stream(probe, "audio")
    if not audio:
        # The one that catches everybody: a simulator recording has no audio track at all, and a
        # preview without one is refused on upload.
        found.append("there is no audio stream, and App Store Connect requires one")
    else:
        if audio.get("channels") != 2:
            found.append(f"the audio has {audio.get('channels')} channels, and must be stereo")
        if str(audio.get("sample_rate")) not in SAMPLE_RATES:
            found.append(
                f"the audio sample rate is {audio.get('sample_rate')}, and must be 44100 or 48000"
            )
        if not audio.get("disposition", {}).get("default"):
            found.append("the audio track is not enabled, and every track must be")
        if audio.get("bit_rate"):
            bitrate = int(audio.get("bit_rate"))
            if bitrate < MIN_BITRATE:
                found.append(f"the audio bitrate is {bitrate}, and must be at least 192000")

    duration = float(probe.get("format", {}).get("duration", 0))
    if not DURATION[0] <= duration <= DURATION[1]:
        found.append(f"the duration is {duration:.1f}s, and must be between 15 and 30")

    if DEVICE_TYPE not in name.upper():
        found.append(f"the filename does not contain {DEVICE_TYPE}, so deliver would skip it")

    return found


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: preview_check.py <video>")

    path = Path(sys.argv[1])
    if not path.is_file():
        raise SystemExit(f"error: no such file: {path}")

    probe = json.loads(
        subprocess.run(
            [
                "ffprobe", "-v", "error",
                "-show_streams", "-show_format",
                "-of", "json", str(path),
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    )

    found = problems(probe, path.name)
    if found:
        print(f"{path.name} would be refused:", file=sys.stderr)
        for problem in found:
            print(f"  - {problem}", file=sys.stderr)
        raise SystemExit(1)

    print(f"{path.name} meets every App Store Connect requirement.")


if __name__ == "__main__":
    main()
