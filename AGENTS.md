# AGENTS.md

A first-person movement game built with Godot 4.7 (GDScript only). Domain language is in `GLOSSARY.md`; decisions are in `docs/adr/`.

## Working in this repo

- **Feedback loop:** `python tools/check.py` runs the Godot version check, format check, lint and the full test suite. `--fix` formats files in place. Run it before declaring work done.
- **Godot binary:** copy `.env.example` to `.env` and set `GODOT_BIN` to the Godot editor executable. A real `GODOT_BIN` environment variable overrides `.env`; with neither, `godot` on `PATH` is used.
- **Git hook:** run `git config core.hooksPath .githooks` once per clone to format and lint staged files on commit.
- **Layout:** files are grouped by feature (`res://player/`, `res://movement/...`), each scene beside its script. Tests live in `res://tests/`, mirroring the feature folders.
- **Standards:** follow `CODING_STANDARDS.md`.
- **Branches:** `main` is protected; work on a branch and open a PR. CI must pass.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues (skypekitten9/highjump) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
