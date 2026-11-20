import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import require_pr_skill as hook  # noqa: E402


class WritesPrBodyTest(unittest.TestCase):
    def test_create_writes_a_body(self):
        self.assertTrue(hook.writes_pr_body('gh pr create --draft --title "x" --body "y"'))

    def test_create_with_fill_writes_a_body(self):
        self.assertTrue(hook.writes_pr_body("git push && gh pr create --fill"))

    def test_edit_with_body_file_writes_a_body(self):
        self.assertTrue(hook.writes_pr_body('gh pr edit 18 --body-file "$TEMP/pr.md"'))

    def test_edit_with_short_body_flag_writes_a_body(self):
        self.assertTrue(hook.writes_pr_body('gh pr edit 18 -b "text"'))

    def test_edit_without_body_flag_is_allowed(self):
        self.assertFalse(hook.writes_pr_body("gh pr edit 18 --add-label bug"))

    def test_other_pr_commands_are_allowed(self):
        self.assertFalse(hook.writes_pr_body("gh pr ready 23 && gh pr view 23 --json body"))


class PrSkillLoadedTest(unittest.TestCase):
    def test_skill_tool_call_counts(self):
        line = '{"type":"tool_use","name":"Skill","input":{"skill":"mattpocock-skills:pr"}}'
        self.assertTrue(hook.pr_skill_loaded(line))

    def test_slash_command_counts(self):
        line = '"content":"<command-name>/mattpocock-skills:pr</command-name>"'
        self.assertTrue(hook.pr_skill_loaded(line))

    def test_other_skills_do_not_count(self):
        line = '{"input":{"skill":"mattpocock-skills:prototype"}}'
        self.assertFalse(hook.pr_skill_loaded(line))


if __name__ == "__main__":
    unittest.main()
