# GDScript style

The standard is the official [GDScript style guide](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html) for Godot 4.7 (ADR 0014). This page lists only Rubbley's additions to it. `scripts/check.sh` enforces what can be checked mechanically.

## Additions

1. Names use [`GLOSSARY.md`](../../GLOSSARY.md) terms verbatim (`CelestialBody`, `celestial_body.gd`). A glossary _Avoid_ term never appears in a name.
2. Every `class_name` script and every public method has a `##` doc comment.
3. Every `@warning_ignore` has a comment on the same line saying why.
4. Gameplay randomness comes from an injected `RandomNumberGenerator` (ADR 0018), so tests can seed it.

## Warning exceptions

Every GDScript warning is an error. A warning left below Error goes here with a one-line reason. There are none yet.
