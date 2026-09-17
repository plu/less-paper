#!/usr/bin/env python3
"""Find the choreography inside the recording.

    python3 mise/scripts/preview_window.py <xcodebuild-log> <recorder-start-epoch>

Prints "<start-offset> <duration>" for ffmpeg to trim by.

simctl records from the host while the choreography runs in the simulator, so the window between
them has to be found rather than assumed. The test prints two markers; the simulator shares the
host's clock, so subtracting the moment the recorder started gives exact offsets. Polling for the
app process and trimming a fixed lead-in instead would drift with runner load, and two seconds of
drift opens the video mid-transition.
"""

import re
import sys
from pathlib import Path

MARKER = re.compile(r"^PREVIEW_MARKER (start|end) (\d+(?:\.\d+)?)", re.MULTILINE)

DURATION = (15.0, 30.0)


def window(log, recorder_started):
    marks = {}
    for name, value in MARKER.findall(log):
        # First start, last end: a retried test would print more than one pair, and the outermost
        # bracket is the one that contains the whole journey.
        if name == "start":
            marks.setdefault(name, float(value))
        else:
            marks[name] = float(value)

    for name in ("start", "end"):
        if name not in marks:
            raise ValueError(
                f"the log has no PREVIEW_MARKER {name} line - the choreography did not "
                f"reach the {name} of its run"
            )

    offset = marks["start"] - recorder_started
    if offset < 0:
        raise ValueError(
            "the choreography started before the recording did, so its opening is not in the file"
        )

    duration = marks["end"] - marks["start"]
    if not DURATION[0] <= duration <= DURATION[1]:
        raise ValueError(
            f"the choreography ran for {duration:.1f}s, and App Store Connect takes 15s to 30s. "
            f"Retune the marks in AppPreviewTests rather than trimming to fit."
        )

    return offset, duration


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: preview_window.py <xcodebuild-log> <recorder-start-epoch>")

    try:
        offset, duration = window(
            Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"),
            float(sys.argv[2]),
        )
    except ValueError as error:
        raise SystemExit(f"error: {error}")

    print(f"{offset:.3f} {duration:.3f}")


if __name__ == "__main__":
    main()
