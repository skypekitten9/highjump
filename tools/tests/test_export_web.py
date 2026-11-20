import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import check  # noqa: E402
import export_web  # noqa: E402


class TemplatesUrlTest(unittest.TestCase):
    def test_points_at_the_pinned_release_archive(self):
        self.assertEqual(
            export_web.templates_url("4.7.2-stable"),
            "https://github.com/godotengine/godot/releases/download/4.7.2-stable/"
            "Godot_v4.7.2-stable_export_templates.tpz",
        )


class TemplateMemberTest(unittest.TestCase):
    def test_picks_the_single_threaded_release_template(self):
        names = [
            "templates/web_debug.zip",
            "templates/web_release.zip",
            "templates/web_nothreads_debug.zip",
            "templates/web_nothreads_release.zip",
            "templates/web_dlink_nothreads_release.zip",
        ]
        self.assertEqual(
            export_web.template_member(names), "templates/web_nothreads_release.zip"
        )

    def test_a_missing_template_fails(self):
        with self.assertRaises(check.CheckFailed):
            export_web.template_member(["templates/web_release.zip"])


if __name__ == "__main__":
    unittest.main()
