# Coding Standards

Rules for code in this repo that tooling does not already enforce. Formatting, lint style and static typing are enforced by `python tools/check.py` and the engine (see `docs/adr/`), so they are not repeated here.

## GDScript

- **Type everything.** Declare types on variables, parameters and return values. Use `:=` only when the type is obvious from the right-hand side (a constructor, a literal, a typed function call).
- **Signal up, call down.** A node calls methods on its children directly; children communicate with parents and siblings through signals. Never reach up the tree with `get_parent()` or absolute node paths.
- **Movement and physics run in `_physics_process`.** Never move bodies or read physics state in `_process`.
- **Expose feel values.** Values that tune how the game feels (speeds, forces, pole length, timings) are `@export` variables or live in a `Resource`, never magic numbers buried in logic.
