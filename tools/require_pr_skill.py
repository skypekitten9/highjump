"""Claude Code PreToolUse hook: block PR bodies written without the `pr` skill.

Wired in `.claude/settings.json`. Reads the hook payload on stdin. When a shell
command writes a PR body (`gh pr create`, or `gh pr edit` with a body flag) and
the session transcript shows no load of the `pr` skill, exits 2 so Claude Code
blocks the call and shows the agent the message on stderr.
"""

import json
import re
import sys
from pathlib import Path

PR_CREATE = re.compile(r"\bgh\s+pr\s+create\b")
PR_EDIT = re.compile(r"\bgh\s+pr\s+edit\b")
BODY_FLAG = re.compile(r"(?:^|\s)(?:--body|--body-file|-b|-F)(?:[\s=]|$)")
SKILL_LOADED = re.compile(
    r'"skill"\s*:\s*"(?:mattpocock-skills:)?pr"'
    r"|<command-name>/(?:mattpocock-skills:)?pr</command-name>"
)

MESSAGE = (
    "Blocked: this command writes a PR body, but the `pr` skill has not been loaded "
    "in this session. Call the Skill tool with `mattpocock-skills:pr`, write the body "
    "to its template, then run the command again."
)


def writes_pr_body(command: str) -> bool:
    if PR_CREATE.search(command):
        return True
    return bool(PR_EDIT.search(command) and BODY_FLAG.search(command))


def pr_skill_loaded(transcript: str) -> bool:
    return bool(SKILL_LOADED.search(transcript))


def main() -> int:
    payload = json.load(sys.stdin)
    command = str(payload.get("tool_input", {}).get("command", ""))
    if not writes_pr_body(command):
        return 0
    transcript_path = payload.get("transcript_path")
    transcript = ""
    if transcript_path and Path(transcript_path).is_file():
        transcript = Path(transcript_path).read_text(encoding="utf-8", errors="replace")
    if pr_skill_loaded(transcript):
        return 0
    print(MESSAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
