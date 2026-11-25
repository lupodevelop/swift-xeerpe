import unittest

from render import parse_summary


class Summary(unittest.TestCase):
    def test_reads_frames_and_pixel_size(self):
        self.assertEqual(parse_summary("frames 120 1280 720"), {"frames": 120, "width": 1280, "height": 720})

    def test_rejects_other_output(self):
        for line in ("render failed at frame 3", "frames 120 1280", "frames a b c"):
            with self.assertRaises(ValueError):
                parse_summary(line)


if __name__ == "__main__":
    unittest.main()
