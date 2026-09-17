#!/usr/bin/env python3
"""Tests for preview_check.py.

Only the pure half is tested. Shelling out to ffprobe lives in main() and is exercised by running
the script for real.
"""

import unittest

from preview_check import problems

NAME = "01_IPHONE_67.mp4"


def probe(**overrides):
    """A conforming probe, with named fields swapped out per test."""
    video = {
        "codec_type": "video",
        "codec_name": "h264",
        "profile": "High",
        "level": 40,
        "width": 886,
        "height": 1920,
        "r_frame_rate": "30/1",
    }
    audio = {
        "codec_type": "audio",
        "codec_name": "aac",
        "channels": 2,
        "sample_rate": "44100",
        "disposition": {"default": 1},
        "bit_rate": "256000",
    }
    video.update(overrides.pop("video", {}))
    audio.update(overrides.pop("audio", {}))
    streams = [video] if overrides.pop("no_audio", False) else [video, audio]
    return {"streams": streams, "format": {"duration": overrides.pop("duration", "26.0")}}


class ProblemsTests(unittest.TestCase):

    def test_a_conforming_file_has_no_problems(self):
        self.assertEqual(problems(probe(), NAME), [])

    def test_one_pixel_too_wide_is_refused(self):
        self.assertIn("886x1920", problems(probe(video={"width": 887}), NAME)[0])

    def test_one_pixel_too_tall_is_refused(self):
        self.assertIn("886x1920", problems(probe(video={"height": 1921}), NAME)[0])

    def test_thirty_one_seconds_is_refused(self):
        self.assertIn("duration", problems(probe(duration="31.0"), NAME)[0])

    def test_fourteen_seconds_is_refused(self):
        self.assertIn("duration", problems(probe(duration="14.0"), NAME)[0])

    def test_fifteen_and_thirty_seconds_are_accepted(self):
        self.assertEqual(problems(probe(duration="15.0"), NAME), [])
        self.assertEqual(problems(probe(duration="30.0"), NAME), [])

    def test_sixty_fps_is_refused(self):
        self.assertIn("frame rate", problems(probe(video={"r_frame_rate": "60/1"}), NAME)[0])

    def test_level_41_is_refused(self):
        self.assertIn("level", problems(probe(video={"level": 41}), NAME)[0])

    def test_main_profile_is_refused(self):
        self.assertIn("profile", problems(probe(video={"profile": "Main"}), NAME)[0])

    def test_a_missing_audio_track_is_refused(self):
        self.assertIn("audio", problems(probe(no_audio=True), NAME)[0])

    def test_mono_audio_is_refused(self):
        self.assertIn("stereo", problems(probe(audio={"channels": 1}), NAME)[0])

    def test_a_disabled_audio_track_is_refused(self):
        self.assertIn("enabled", problems(probe(audio={"disposition": {"default": 0}}), NAME)[0])

    def test_an_odd_sample_rate_is_refused(self):
        self.assertIn("sample rate", problems(probe(audio={"sample_rate": "22050"}), NAME)[0])

    def test_a_name_without_the_device_type_is_refused(self):
        self.assertIn("IPHONE_67", problems(probe(), "01_preview.mp4")[0])

    def test_every_problem_is_reported_not_just_the_first(self):
        found = problems(probe(video={"width": 100}, duration="99.0", no_audio=True), "x.mp4")
        self.assertEqual(len(found), 4)

    def test_conforming_bitrate_is_accepted(self):
        self.assertEqual(problems(probe(), NAME), [])

    def test_low_bitrate_is_refused(self):
        self.assertIn("bitrate", problems(probe(audio={"bit_rate": "96000"}), NAME)[0])

    def test_missing_bitrate_is_accepted(self):
        self.assertEqual(problems(probe(audio={}), NAME), [])


if __name__ == "__main__":
    unittest.main()
