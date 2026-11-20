# GDScript only, with strict typing

All game code is GDScript: no C#, no GDExtension. GDScript keeps the toolchain to a single editor binary (no .NET SDK, no native builds), works on every export target, and is what Godot's docs and tooling assume. To recover most of the safety C# would give, typing is enforced by the engine: `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access` and `unsafe_call_argument` are set to Error in `project.godot`. `inferred_declaration` stays off so `:=` remains allowed where the type is obvious. Addons are exempt via Godot's default `directory_rules`.

## Considered Options

- **C#**: stronger tooling and performance, but requires the .NET build of Godot and SDK, and has weaker web export support.
- **GDScript with optional typing**: lets code drift back into untyped `Variant` access, which defeats the point.
