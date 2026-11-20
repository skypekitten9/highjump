# Use GDQuest's gdscript-formatter for formatting and linting

Formatting and linting both use GDQuest's `gdscript-formatter` (`gdscript-formatter` and `gdscript-formatter lint`), pinned to an exact version. `tools/check.py` downloads the pinned release binary into `.tools/`, so local runs, the git hook and CI all use the same build without needing pip, the pre-commit framework or a Rust toolchain.

## Considered Options

- **gdtoolkit (gdformat/gdlint)**: the long-standing default, but no commits or releases since Oct 2025 while community fixes go unmerged. Rejected: too integral a tool to depend on something unmaintained.

## Consequences

The formatter is pre-1.0, so its output can change between versions. Upgrades are deliberate: bump the pinned version and reformat the codebase in a single commit.
