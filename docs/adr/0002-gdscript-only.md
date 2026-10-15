# GDScript only, no C#

All game code is GDScript. We need web exports for playtests, demos and CI ([ADR 0001](0001-launch-platforms.md)), and Godot 4.7 can't export C# projects to web. C# on Android and iOS is also still marked experimental. We'll reconsider C# only if upstream ships C# web export. If GDScript is too slow for hot loops such as N-body gravity, C# is not the fallback. Where that code goes instead is decided separately.

## Consequences

Agents need GDScript style standards and quality gates (static typing, linting, formatting) that CI enforces, because there's no compiler to catch these mistakes.
