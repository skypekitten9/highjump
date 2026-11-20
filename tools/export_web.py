"""Export the game for the web into build/web/ (what CI deploys to GitHub Pages).

Usage:
    python tools/export_web.py    export build/web/index.html with the "Web" preset

On first use, downloads the official single-threaded web export template for the Godot
version in .godot-version into .tools/web-template/, where export_presets.cfg points.
Only that template is fetched from the release's 1.3 GB template archive, using HTTP
range requests, and it is verified against a pinned SHA-256.

Serve the result with `python -m http.server -d build/web` and open http://localhost:8000.
"""

from __future__ import annotations

import hashlib
import io
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

import check

REPO = check.REPO
TEMPLATE_DIR = check.TOOLS_DIR / "web-template"
BUILD_DIR = REPO / "build" / "web"
PRESET = "Web"
TEMPLATE_NAME = "web_nothreads_release.zip"

# SHA-256 of TEMPLATE_NAME inside each release's export template archive. Bumping
# .godot-version (docs/adr/0002) needs a new entry: run this script, and on a missing
# entry it prints the hash of what it downloaded so you can check and pin it.
TEMPLATE_SHA256 = {
    "4.7.2-stable": "d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0",
}


# --- Pure logic (unit-tested in tools/tests) ----------------------------------


def templates_url(version: str) -> str:
    """URL of the official export template archive for a release tag like "4.7.2-stable"."""
    return (
        "https://github.com/godotengine/godot/releases/download/"
        f"{version}/Godot_v{version}_export_templates.tpz"
    )


def template_member(names: list[str]) -> str:
    """Pick the single-threaded web release template out of the archive's file names."""
    matches = [name for name in names if name.rsplit("/", 1)[-1] == TEMPLATE_NAME]
    if len(matches) != 1:
        raise check.CheckFailed(f"Expected one {TEMPLATE_NAME} in the archive, got {matches}.")
    return matches[0]


# --- Fetching the template ----------------------------------------------------


class HttpRangeFile(io.RawIOBase):
    """A read-only, seekable file over HTTP, so zipfile reads only the bytes it needs."""

    def __init__(self, url: str) -> None:
        super().__init__()
        self._url = url
        self._pos = 0
        request = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
        with urllib.request.urlopen(request) as response:
            content_range = response.headers.get("Content-Range", "")
            if response.status != 206 or "/" not in content_range:
                raise check.CheckFailed(f"{url} does not support range requests.")
            self._size = int(content_range.rsplit("/", 1)[1])

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self._pos

    def seek(self, offset: int, whence: int = io.SEEK_SET) -> int:
        base = {io.SEEK_SET: 0, io.SEEK_CUR: self._pos, io.SEEK_END: self._size}[whence]
        self._pos = base + offset
        return self._pos

    def readinto(self, buffer: memoryview) -> int:  # type: ignore[override]
        end = min(self._pos + len(buffer), self._size)
        if end <= self._pos:
            return 0
        request = urllib.request.Request(
            self._url, headers={"Range": f"bytes={self._pos}-{end - 1}"}
        )
        with urllib.request.urlopen(request) as response:
            data: bytes = response.read()
        buffer[: len(data)] = data
        self._pos += len(data)
        return len(data)


def ensure_template(version: str) -> None:
    """Download and verify the web template for `version`, unless it is already there."""
    template = TEMPLATE_DIR / TEMPLATE_NAME
    version_file = TEMPLATE_DIR / "VERSION"
    if template.exists() and version_file.exists():
        if version_file.read_text(encoding="utf-8").strip() == version:
            return

    url = templates_url(version)
    print(f"Downloading {TEMPLATE_NAME} from {url}", flush=True)
    remote = io.BufferedReader(HttpRangeFile(url), buffer_size=1 << 20)
    with zipfile.ZipFile(remote) as archive:  # type: ignore[arg-type]
        data = archive.read(template_member(archive.namelist()))

    actual = hashlib.sha256(data).hexdigest()
    expected = TEMPLATE_SHA256.get(version)
    if not expected:
        raise check.CheckFailed(
            f"No pinned SHA-256 for the {version} web template. The download hashes to "
            f"{actual}; add it to TEMPLATE_SHA256 in tools/export_web.py."
        )
    if actual != expected:
        raise check.CheckFailed(
            f"SHA-256 mismatch for {TEMPLATE_NAME}: expected {expected}, got {actual}."
        )
    shutil.rmtree(TEMPLATE_DIR, ignore_errors=True)
    TEMPLATE_DIR.mkdir(parents=True)
    template.write_bytes(data)
    version_file.write_text(version + "\n", encoding="utf-8")


# --- Exporting ----------------------------------------------------------------


def export(godot: str) -> None:
    check.step(f"Web export ({PRESET} preset)")
    shutil.rmtree(BUILD_DIR, ignore_errors=True)
    BUILD_DIR.mkdir(parents=True)
    # build/ sits inside the project; without this Godot imports the exported files as
    # project assets and packs them into the next export.
    (BUILD_DIR.parent / ".gdignore").touch()
    target = BUILD_DIR / "index.html"
    code = check.run(
        [godot, "--headless", "--path", ".", "--export-release", PRESET, str(target)]
    ).returncode
    # Godot can exit 0 after a failed export, so also check that it wrote the page.
    if code != 0 or not target.exists():
        raise check.CheckFailed(f"Web export failed (exit code {code}).")
    print(f"Exported to {BUILD_DIR.relative_to(REPO).as_posix()}/")


def main() -> int:
    try:
        godot = check.godot_bin()
        check.check_godot_version(godot)
        version = (REPO / ".godot-version").read_text(encoding="utf-8").strip()
        ensure_template(version)
        export(godot)
    except check.CheckFailed as error:
        print(f"\nFAILED: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
