# GDScript only, with strict typing

All game code is GDScript: no C#, no GDExtension. GDScript keeps the toolchain to a single editor binary (no .NET SDK, no native builds), works on every export target, and is what Godot's docs and tooling assume. To recover most of the safety C# would give, the engine enforces typing: the untyped and unsafe-access warnings are set to Error in `project.godot`, while `inferred_declaration` stays off so `:=` remains allowed.

## Considered Options

- **C#**: stronger tooling and performance, but requires the .NET build of Godot and SDK, and has weaker web export support.
- **GDScript with optional typing**: lets code drift back into untyped `Variant` access, which defeats the point.
