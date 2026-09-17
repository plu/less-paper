#!/usr/bin/env python3
"""Tests for preview_window.py."""

import unittest

from preview_window import window

STARTED = 1_000_000.0


def log(start=1_000_002.5, end=1_000_028.5, extra=""):
    return (
        "Test Suite 'AppPreviewTests' started\n"
        f"PREVIEW_MARKER start {start}\n"
        "    t =     1.20s Tap \"Filter\"\n"
        f"{extra}"
        f"PREVIEW_MARKER end {end}\n"
        "Test Suite 'AppPreviewTests' passed\n"
    )


class WindowTests(unittest.TestCase):

    def test_offsets_are_measured_from_when_the_recorder_started(self):
        self.assertEqual(window(log(), STARTED), (2.5, 26.0))

    def test_a_missing_start_marker_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "start"):
            window("PREVIEW_MARKER end 1000028.5\n", STARTED)

    def test_a_missing_end_marker_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "end"):
            window("PREVIEW_MARKER start 1000002.5\n", STARTED)

    def test_an_empty_log_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "start"):
            window("", STARTED)

    def test_a_run_longer_than_thirty_seconds_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "31.0s"):
            window(log(end=1_000_033.5), STARTED)

    def test_a_run_shorter_than_fifteen_seconds_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "10.0s"):
            window(log(end=1_000_012.5), STARTED)

    def test_a_start_before_the_recorder_is_an_error(self):
        # The clocks are shared, so this means the recorder started late and the opening beat is
        # not in the file at all.
        with self.assertRaisesRegex(ValueError, "before the recording"):
            window(log(start=999_999.0, end=1_000_020.0), STARTED)

    def test_overrun_lines_are_ignored(self):
        self.assertEqual(
            window(log(extra="PREVIEW_OVERRUN pdf 0.8\n"), STARTED),
            (2.5, 26.0),
        )

    def test_when_a_test_retries_the_final_attempt_is_used(self):
        test_log = (
            "Test Suite 'AppPreviewTests' started\n"
            "PREVIEW_MARKER start 1000000.0\n"
            "    t =     1.20s Tap \"Filter\"\n"
            "PREVIEW_MARKER start 1000002.5\n"
            "    t =     1.20s Tap \"Filter\"\n"
            "PREVIEW_MARKER end 1000028.5\n"
            "Test Suite 'AppPreviewTests' passed\n"
        )
        self.assertEqual(window(test_log, STARTED), (2.5, 26.0))

    def test_out_of_order_markers_are_an_error(self):
        test_log = (
            "Test Suite 'AppPreviewTests' started\n"
            "PREVIEW_MARKER start 1000002.5\n"
            "    t =     1.20s Tap \"Filter\"\n"
            "PREVIEW_MARKER end 1000001.0\n"
            "PREVIEW_MARKER start 1000003.0\n"
            "Test Suite 'AppPreviewTests' passed\n"
        )
        with self.assertRaisesRegex(ValueError, "15s to 30s"):
            window(test_log, STARTED)


if __name__ == "__main__":
    unittest.main()
