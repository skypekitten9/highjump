# Pin the exact Godot patch version in CI; detect drift locally

The local editor is the Steam build on the `stable-4.7` branch, which auto-updates through 4.7.x patch releases. CI must not silently differ from it, so `.godot-version` pins the exact patch (e.g. `4.7.2-stable`), CI downloads that exact release, and `tools/check.py` fails when the local Godot version doesn't match the file. When Steam updates, bump `.godot-version` in the same PR.

## Consequences

CI runs gdUnit4 through `tools/check.py`, using the same Godot invocation as gdUnit4's `runtest` scripts plus `--headless`, rather than the official `gdUnit4-action`. The action refuses Godot versions missing from gdUnit4's compatibility table, which lags behind patch releases (at time of writing it listed 4.7.1 but not 4.7.2). Calling the scripts directly would mean a separate `.sh`/`.cmd` per platform; when upgrading gdUnit4, compare its `runtest.sh` with `run_game_tests` in `tools/check.py`.
