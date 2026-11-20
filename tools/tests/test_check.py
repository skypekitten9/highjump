import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import check  # noqa: E402


class GodotVersionMatchTest(unittest.TestCase):
    def test_steam_build_matches_its_pinned_stable_release(self):
        self.assertTrue(
            check.godot_version_matches("4.7.2.stable.steam.ed1daf0bf", "4.7.2-stable")
        )

    def test_newer_patch_release_is_drift(self):
        self.assertFalse(
            check.godot_version_matches("4.7.3.stable.steam.0a1b2c3d4", "4.7.2-stable")
        )

    def test_dot_zero_release_does_not_match_a_patch_release(self):
        self.assertFalse(
            check.godot_version_matches("4.7.1.stable.official.abc123", "4.7-stable")
        )

    def test_official_build_matches_dot_zero_release(self):
        self.assertTrue(
            check.godot_version_matches("4.7.stable.official.abc123", "4.7-stable")
        )


class StagedGdscriptFilesTest(unittest.TestCase):
    def test_selects_added_and_modified_gdscript_outside_addons(self):
        name_status = (
            "M\tplayer/player.gd\n"
            "A\tmovement/vault.gd\n"
            "M\tplayer/player.tscn\n"
            "M\taddons/gdUnit4/plugin.gd\n"
            "D\tmovement/old.gd\n"
        )
        self.assertEqual(
            check.staged_gdscript_files(name_status),
            ["player/player.gd", "movement/vault.gd"],
        )

    def test_renamed_file_is_checked_at_its_new_path(self):
        self.assertEqual(
            check.staged_gdscript_files("R095\tplayer/old_name.gd\tplayer/new_name.gd\n"),
            ["player/new_name.gd"],
        )


class GodotBinaryResolutionTest(unittest.TestCase):
    STEAM_PATH = r"D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

    def test_env_file_path_with_spaces_and_backslashes_is_read_verbatim(self):
        env_file = (
            "# Path to the Godot editor executable.\n"
            "\n"
            f"GODOT_BIN={self.STEAM_PATH}\n"
        )
        self.assertEqual(check.resolve_godot_bin({}, env_file), self.STEAM_PATH)

    def test_real_environment_variable_wins_over_env_file(self):
        self.assertEqual(
            check.resolve_godot_bin(
                {"GODOT_BIN": "/opt/godot/godot"}, f"GODOT_BIN={self.STEAM_PATH}\n"
            ),
            "/opt/godot/godot",
        )

    def test_falls_back_to_godot_on_path(self):
        self.assertEqual(check.resolve_godot_bin({}, None), "godot")

    def test_quoted_env_file_value_is_unquoted(self):
        self.assertEqual(
            check.resolve_godot_bin({}, f'GODOT_BIN="{self.STEAM_PATH}"\n'), self.STEAM_PATH
        )

    def test_commented_out_entry_is_ignored(self):
        self.assertEqual(check.resolve_godot_bin({}, "# GODOT_BIN=/old/godot\n"), "godot")


if __name__ == "__main__":
    unittest.main()
