"""Run every check for this repo: Godot version, format, lint, tests.

Usage:
    python tools/check.py           check everything (what CI runs)
    python tools/check.py --fix     format GDScript in place, then check everything
    python tools/check.py --staged  check format and lint of staged GDScript (the git hook)
"""

from __future__ import annotations

import argparse
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from collections.abc import Mapping
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TOOLS_DIR = REPO / ".tools"

# Pinned per docs/adr/0003. Hashes come from the official GitHub release page.
FORMATTER_VERSION = "0.28.0"
FORMATTER_ASSETS: dict[tuple[str, str], tuple[str, str]] = {
    ("Windows", "x86_64"): (
        "windows-x86_64.exe.zip",
        "f4012ceb0ece52af7e0f617ceb267fee386512b51b0808f12743667b01ad7626",
    ),
    ("Windows", "aarch64"): (
        "windows-aarch64.exe.zip",
        "02858a0cee92616b1b23ecf1ca977e6c9443f70df2e3bd5c11634d33fd55db19",
    ),
    ("Linux", "x86_64"): (
        "linux-x86_64.zip",
        "c59a96c0de55f98568945eb60c91de6d20e994545cb36145425ec1558174de04",
    ),
    ("Linux", "aarch64"): (
        "linux-aarch64.zip",
        "8afb2ed4ef8f4855b3e614f91ffc348178bad8c1d6e9e8d6365722b500f2731c",
    ),
    ("Darwin", "x86_64"): (
        "macos-x86_64.zip",
        "2cc2afd702f3c1474b24723676de3c81ae59d5f17b0cf196333df70beac5aa84",
    ),
    ("Darwin", "aarch64"): (
        "macos-aarch64.zip",
        "2b7a6b701028a8664859ab65c4c8e234e73c6bb55daf4c4f2831dfc8265d244e",
    ),
}

# gdUnit4 exit codes (addons/gdUnit4/src/core/runners/GdUnitTestSessionRunner.gd).
GDUNIT_EXIT_MEANINGS = {
    100: "test failures",
    101: "test warnings, e.g. orphan nodes",
    103: "headless mode not supported",
    104: "Godot version not supported",
    105: "script errors detected",
}

EXCLUDED_DIRS = {"addons", ".godot", ".tools", ".git"}


# --- Pure logic (unit-tested in tools/tests) ----------------------------------


def godot_version_matches(reported: str, pinned: str) -> bool:
    """Compare `godot --version` output (e.g. "4.7.2.stable.steam.ed1daf0bf")
    with a release tag (e.g. "4.7.2-stable")."""
    number, _, status = pinned.strip().partition("-")
    return reported.strip().startswith(f"{number}.{status}.")


def staged_gdscript_files(name_status: str) -> list[str]:
    """Pick the GDScript files to format and lint from `git diff --cached --name-status`
    output, skipping deletions and vendored addons."""
    files: list[str] = []
    for line in name_status.splitlines():
        if not line.strip():
            continue
        status, *paths = line.split("\t")
        if status.startswith("D"):
            continue
        path = paths[-1]
        if path.endswith(".gd") and not path.startswith("addons/"):
            files.append(path)
    return files


def resolve_godot_bin(environ: Mapping[str, str], env_file: str | None) -> str:
    """Find the Godot executable: real environment, then `.env`, then `godot` on PATH."""
    if environ.get("GODOT_BIN"):
        return environ["GODOT_BIN"]
    for line in (env_file or "").splitlines():
        key, sep, value = line.strip().partition("=")
        if sep and key.strip() == "GODOT_BIN":
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            return value or "godot"
    return "godot"


# --- Running the checks -------------------------------------------------------


class CheckFailed(Exception):
    pass


def step(title: str) -> None:
    print(f"\n== {title}", flush=True)


def run(cmd: list[str], capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=REPO, text=True, capture_output=capture)


def godot_bin() -> str:
    env_path = REPO / ".env"
    env_file = env_path.read_text(encoding="utf-8") if env_path.exists() else None
    return resolve_godot_bin(os.environ, env_file)


def check_godot_version(godot: str) -> None:
    step("Godot version")
    pinned = (REPO / ".godot-version").read_text(encoding="utf-8").strip()
    try:
        output = run([godot, "--version"], capture=True).stdout.strip()
    except FileNotFoundError:
        raise CheckFailed(
            f"Godot not found at '{godot}'. Set GODOT_BIN in .env (see .env.example)."
        ) from None
    reported = output.splitlines()[-1] if output else ""
    if not godot_version_matches(reported, pinned):
        raise CheckFailed(
            f"Godot reports '{reported}' but .godot-version pins '{pinned}'. "
            "Use the pinned version, or bump .godot-version (see docs/adr/0002)."
        )
    print(f"{reported} matches {pinned}")


def formatter_bin() -> Path:
    """Return the pinned gdscript-formatter, downloading and verifying it on first use."""
    machine = platform.machine().lower()
    arch = {"amd64": "x86_64", "x86_64": "x86_64", "arm64": "aarch64", "aarch64": "aarch64"}
    key = (platform.system(), arch.get(machine, machine))
    if key not in FORMATTER_ASSETS:
        raise CheckFailed(f"No pinned gdscript-formatter build for {key}.")
    suffix, sha256 = FORMATTER_ASSETS[key]
    install_dir = TOOLS_DIR / f"gdscript-formatter-{FORMATTER_VERSION}"
    exe = install_dir / ("gdscript-formatter.exe" if key[0] == "Windows" else "gdscript-formatter")
    if exe.exists():
        return exe

    asset = f"gdscript-formatter-{FORMATTER_VERSION}-{suffix}"
    url = (
        "https://github.com/GDQuest/GDScript-formatter/releases/download/"
        f"{FORMATTER_VERSION}/{asset}"
    )
    print(f"Downloading {url}", flush=True)
    with urllib.request.urlopen(url) as response:
        data: bytes = response.read()
    actual = hashlib.sha256(data).hexdigest()
    if actual != sha256:
        raise CheckFailed(f"SHA-256 mismatch for {asset}: expected {sha256}, got {actual}.")
    install_dir.mkdir(parents=True, exist_ok=True)
    archive = install_dir / asset
    archive.write_bytes(data)
    with zipfile.ZipFile(archive) as zf:
        zf.extractall(install_dir)
    archive.unlink()
    extracted = [p for p in install_dir.rglob("*") if p.is_file()]
    if len(extracted) != 1:
        raise CheckFailed(f"Expected one file in {asset}, got {[p.name for p in extracted]}.")
    extracted[0].rename(exe)
    exe.chmod(0o755)
    return exe


def all_gdscript_files() -> list[str]:
    files: list[str] = []
    for path in sorted(REPO.rglob("*.gd")):
        rel = path.relative_to(REPO)
        if not EXCLUDED_DIRS.intersection(rel.parts):
            files.append(rel.as_posix())
    return files


def format_files(files: list[str], fix: bool) -> None:
    step("Format" + (" (fix)" if fix else " (check)"))
    if not files:
        print("No GDScript files.")
        return
    flags = ["--verify-structure"] if fix else ["--check"]
    if run([str(formatter_bin()), *flags, *files]).returncode != 0:
        if fix:
            raise CheckFailed("Formatting failed.")
        raise CheckFailed("Files need formatting: run `python tools/check.py --fix`.")


def lint_files(files: list[str]) -> None:
    step("Lint")
    if not files:
        print("No GDScript files.")
        return
    if run([str(formatter_bin()), "lint", *files]).returncode != 0:
        raise CheckFailed("Lint errors found.")


def run_tool_tests() -> None:
    step("Tool tests (Python)")
    if run([sys.executable, "-m", "unittest", "discover", "-s", "tools/tests"]).returncode != 0:
        raise CheckFailed("Tool tests failed.")


def run_game_tests(godot: str) -> None:
    step("Game tests (gdUnit4)")
    # Import first so the class_name cache exists on a fresh clone (CI).
    if run([godot, "--headless", "--path", ".", "--import"]).returncode != 0:
        raise CheckFailed("Godot import failed.")
    # Same invocation as addons/gdUnit4/runtest.sh. The remote-debug address is never
    # bound; it stops Godot's interactive debugger hanging CI on script errors.
    code = run(
        [
            godot,
            "--headless",
            "--path",
            ".",
            "-s",
            "-d",
            "--remote-debug",
            "tcp://127.0.0.1:0",
            "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
            "-a",
            "res://tests",
            "--ignoreHeadlessMode",
        ]
    ).returncode
    if code != 0:
        meaning = GDUNIT_EXIT_MEANINGS.get(code, "unknown error")
        raise CheckFailed(f"Game tests failed with exit code {code} ({meaning}).")


def remind_about_hook() -> None:
    if os.environ.get("CI"):
        return
    hooks_path = run(["git", "config", "--get", "core.hooksPath"], capture=True).stdout.strip()
    if hooks_path != ".githooks":
        print(
            "\nNote: the pre-commit hook is not enabled. "
            "Run `git config core.hooksPath .githooks` once to enable it."
        )


def check_staged() -> None:
    """Check formatting and lint of the *staged* content of GDScript files (the git hook).

    The staged blobs are copied into .tools/staged/ (inside the repo, so .editorconfig
    still applies) and checked there. Working-tree files are never touched, so partially
    staged files are checked exactly as they will be committed.
    """
    name_status = run(["git", "diff", "--cached", "--name-status"], capture=True).stdout
    files = staged_gdscript_files(name_status)
    if not files:
        return
    staging_dir = TOOLS_DIR / "staged"
    shutil.rmtree(staging_dir, ignore_errors=True)
    try:
        copies: list[str] = []
        for f in files:
            blob = subprocess.run(
                ["git", "show", f":{f}"], cwd=REPO, capture_output=True, check=True
            ).stdout
            copy = staging_dir / f
            copy.parent.mkdir(parents=True, exist_ok=True)
            copy.write_bytes(blob)
            copies.append(copy.relative_to(REPO).as_posix())
        try:
            format_files(copies, fix=False)
        except CheckFailed:
            raise CheckFailed(
                "Staged files need formatting. Run `python tools/check.py --fix`, "
                "re-stage, and commit again."
            ) from None
        lint_files(copies)
    finally:
        shutil.rmtree(staging_dir, ignore_errors=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--fix", action="store_true", help="format GDScript in place first")
    parser.add_argument(
        "--staged", action="store_true", help="only check staged GDScript, as it will be committed (git hook)"
    )
    args = parser.parse_args(argv)

    try:
        if args.staged:
            check_staged()
            return 0
        godot = godot_bin()
        check_godot_version(godot)
        files = all_gdscript_files()
        format_files(files, fix=args.fix)
        lint_files(files)
        run_tool_tests()
        run_game_tests(godot)
    except CheckFailed as error:
        print(f"\nFAILED: {error}", file=sys.stderr)
        return 1
    print("\nAll checks passed.")
    remind_about_hook()
    return 0


if __name__ == "__main__":
    sys.exit(main())
